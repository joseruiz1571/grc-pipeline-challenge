#!/usr/bin/env bash
# check-scc-entitlement.sh [ORG_ID] [EXPECTED_SERVICES...]
#
# Post-activation entitlement assertion for Security Command Center.
# Activating SCC is not the same as the scanners you expect actually running:
# sources get registered at activation regardless of entitlement, so a
# "successful" console activation can still leave a scanner DISABLED. This
# script converts that silent gap into a hard failure.
#
# Why this exists: this repo activated SCC Standard expecting Security Health
# Analytics (the misconfiguration scanner), then waited 40+ hours for a first
# scan that was never going to happen — Google's tier restructure removed SHA
# from *new* Standard-tier activations (only orgs migrated from Standard-legacy
# keep it). See https://cloud.google.com/security-command-center/docs/service-tiers
#
# Checks, each exits non-zero on failure:
#   1. Reachability - the org has an SCC instance (activation actually happened)
#   2. Tier         - the subscription tier is the one you think you bought
#   3. Entitlement  - every expected service is effectively ENABLED
# Captures the raw services state to evidence/scc-services.json either way --
# a failed check is exactly the evidence worth preserving.
#
# Why the tier check (added after a second incident): starting a "30-day Premium
# free trial" from the console left the subscription at STANDARD with every
# service state byte-identical to before. Service-level drift alone reported
# "SHA DISABLED", which is true but not actionable. Reading the tier turns that
# into "tier is STANDARD, expected PREMIUM" — the actual root cause, one level up.
#
# Exit code contract (fail closed — an error is never reported as a pass):
#   0 = tier matches and all expected services effectively ENABLED
#   1 = drift (state was read successfully; tier or a service is not as expected)
#   2 = reachability/permission error (no SCC instance, API error, bad credentials)
set -euo pipefail

ORG_ID="${1:-468955167232}"
shift || true
EXPECTED=("${@:-security-health-analytics}")

# The tier that grants the expected services. SHA requires PREMIUM; override for
# other expectations. QUOTA_PROJECT is required by the securitycenter REST API
# when authenticating with user ADC.
EXPECTED_TIER="${EXPECTED_TIER:-PREMIUM}"
QUOTA_PROJECT="${QUOTA_PROJECT:-gcloud-grc-pipeline}"

EVIDENCE_DIR="$(dirname "$0")/evidence"
mkdir -p "$EVIDENCE_DIR"
SERVICES_JSON="$EVIDENCE_DIR/scc-services.json"

fail() {
  echo "ENTITLEMENT DRIFT: $1" >&2
  exit 1
}

fail_unreachable() {
  echo "CHECK ERROR (not a drift verdict): $1" >&2
  exit 2
}

# 1. REACHABILITY
#    A never-enrolled org has no SCC instance and this call fails outright.
#    Errors here exit 2, distinct from a drift verdict — a permission error
#    must never masquerade as either "entitled" or "not entitled".
echo "[1/3] Reachability — querying SCC service state for org $ORG_ID"
if ! gcloud scc manage services list --organization="$ORG_ID" \
    --format=json > /tmp/scc-services-raw.json 2>/tmp/scc-entitlement-err.log; then
  fail_unreachable "SCC service state unreadable for org $ORG_ID: $(cat /tmp/scc-entitlement-err.log)"
fi
if ! jq -e 'length > 0' /tmp/scc-services-raw.json >/dev/null 2>&1; then
  fail_unreachable "service list came back empty or unparseable — refusing to render a drift verdict from it"
fi
# The API returns services in nondeterministic order. Sort by name so that a
# diff of this evidence file means the STATE changed, not that the JSON got
# shuffled — and so the hash of a bundle containing it is reproducible.
jq -S 'sort_by(.name)' /tmp/scc-services-raw.json > "$SERVICES_JSON"
echo "      SCC instance reachable, state captured to $SERVICES_JSON"

# 2. TIER
#    Service entitlement is downstream of the subscription tier. Reading the
#    tier directly turns "the scanner is off" into "you are on the wrong plan",
#    which is the difference between a symptom and a cause.
echo "[2/3] Tier — asserting subscription tier is $EXPECTED_TIER"
if ! TOKEN=$(gcloud auth print-access-token 2>/tmp/scc-token-err.log); then
  fail_unreachable "could not mint an access token: $(cat /tmp/scc-token-err.log)"
fi
SUB_JSON=$(curl -sS -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" \
  "https://securitycenter.googleapis.com/v1beta2/organizations/$ORG_ID/subscription" \
  2>/tmp/scc-sub-err.log) || fail_unreachable "subscription query failed: $(cat /tmp/scc-sub-err.log)"

ACTUAL_TIER=$(echo "$SUB_JSON" | jq -r '.tier // empty')
if [[ -z "$ACTUAL_TIER" ]]; then
  fail_unreachable "subscription response had no tier field — refusing to render a verdict from it: $(echo "$SUB_JSON" | head -c 300)"
fi
echo "$SUB_JSON" | jq -S . > "$EVIDENCE_DIR/scc-subscription.json"
if [[ "$ACTUAL_TIER" != "$EXPECTED_TIER" ]]; then
  fail "subscription tier is $ACTUAL_TIER, expected $EXPECTED_TIER — the services below cannot be entitled until the tier is right (state captured in $EVIDENCE_DIR/scc-subscription.json)"
fi
echo "      tier: $ACTUAL_TIER"

# 2. ENTITLEMENT
#    intendedEnablementState is what you asked for; effectiveEnablementState is
#    what the tier actually grants. INHERITED resolving to DISABLED is the
#    silent failure mode this check exists to catch.
echo "[3/3] Entitlement — asserting expected services are effectively ENABLED"
DRIFTED=0
for SVC in "${EXPECTED[@]}"; do
  # The CLI takes kebab-case slugs (security-health-analytics) but the API
  # returns SCREAMING_SNAKE resource names (.../SECURITY_HEALTH_ANALYTICS).
  # Normalize the expected slug to match the API form.
  SVC_API=$(echo "$SVC" | tr '[:lower:]-' '[:upper:]_')
  STATE=$(jq -r --arg svc "$SVC_API" \
    '.[] | select(.name | endswith("/" + $svc)) | .effectiveEnablementState // "ABSENT"' \
    "$SERVICES_JSON")
  STATE="${STATE:-ABSENT}"
  if [[ "$STATE" == "ENABLED" ]]; then
    echo "      $SVC: ENABLED"
  else
    echo "      $SVC: ${STATE} — expected ENABLED" >&2
    DRIFTED=1
  fi
done

if [[ "$DRIFTED" -ne 0 ]]; then
  fail "one or more expected services are not effectively enabled (state captured in $SERVICES_JSON)"
fi

echo
echo "ENTITLEMENT INTACT"
echo "  org:      $ORG_ID"
echo "  tier:     $ACTUAL_TIER"
echo "  services: ${EXPECTED[*]} all effectively ENABLED"

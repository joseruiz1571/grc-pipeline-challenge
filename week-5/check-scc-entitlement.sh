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
#   2. Entitlement  - every expected service is effectively ENABLED
# Captures the raw services state to evidence/scc-services.json either way --
# a failed check is exactly the evidence worth preserving.
set -euo pipefail

ORG_ID="${1:-468955167232}"
shift || true
EXPECTED=("${@:-security-health-analytics}")

EVIDENCE_DIR="$(dirname "$0")/evidence"
mkdir -p "$EVIDENCE_DIR"
SERVICES_JSON="$EVIDENCE_DIR/scc-services.json"

fail() {
  echo "ENTITLEMENT DRIFT: $1" >&2
  exit 1
}

# 1. REACHABILITY
#    A never-enrolled org has no SCC instance and this call fails outright.
echo "[1/2] Reachability — querying SCC service state for org $ORG_ID"
if ! gcloud scc manage services list --organization="$ORG_ID" \
    --format=json > "$SERVICES_JSON" 2>/tmp/scc-entitlement-err.log; then
  fail "no SCC instance reachable for org $ORG_ID: $(cat /tmp/scc-entitlement-err.log)"
fi
echo "      SCC instance reachable, state captured to $SERVICES_JSON"

# 2. ENTITLEMENT
#    intendedEnablementState is what you asked for; effectiveEnablementState is
#    what the tier actually grants. INHERITED resolving to DISABLED is the
#    silent failure mode this check exists to catch.
echo "[2/2] Entitlement — asserting expected services are effectively ENABLED"
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
echo "  services: ${EXPECTED[*]} all effectively ENABLED"

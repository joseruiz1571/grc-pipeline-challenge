#!/usr/bin/env bash
# verify-evidence.sh <bundle.tar.gz>
#
# Proves an evidence bundle is intact and authentic, without trusting whoever
# is running this script. Three checks, each exits non-zero on failure:
#   1. Integrity    - recomputed SHA-256 matches the .sha256 sidecar
#   2. Authenticity - cosign verify-blob against the .sig.bundle
#   3. Preservation - Object Lock retention still in the future (stretch, skipped if no vault)
# Prints CHAIN INTACT only when every check that ran, passed.
set -euo pipefail

BUNDLE="${1:?usage: verify-evidence.sh <bundle.tar.gz>}"
SIDECAR="${BUNDLE}.sha256"
SIGBUNDLE="${BUNDLE}.sig.bundle"

# Overridable so the same script verifies both CI-signed bundles (identity =
# the GitHub Actions workflow) and locally-signed bundles used for the tamper
# test (identity = whatever OIDC provider the local `cosign sign-blob` login used).
OIDC_ISSUER="${VERIFY_OIDC_ISSUER:-https://token.actions.githubusercontent.com}"
IDENTITY_REGEXP="${VERIFY_IDENTITY_REGEXP:-.*}"

fail() {
  echo "CHAIN BROKEN: $1" >&2
  exit 1
}

if [[ ! -f "$BUNDLE" ]]; then
  fail "bundle not found: $BUNDLE"
fi

# 1. INTEGRITY
#    Recompute the SHA-256 of the bundle and compare it to the .sha256 sidecar
#    that was written when the bundle was created. Mismatch means tampering.
echo "[1/3] Integrity — recomputing SHA-256 of $BUNDLE"
if [[ ! -f "$SIDECAR" ]]; then
  fail "sidecar not found: $SIDECAR"
fi

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_HASH=$(sha256sum "$BUNDLE" | awk '{print $1}')
else
  ACTUAL_HASH=$(shasum -a 256 "$BUNDLE" | awk '{print $1}')
fi
EXPECTED_HASH=$(awk '{print $1}' "$SIDECAR")

if [[ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]]; then
  fail "hash mismatch — expected $EXPECTED_HASH, got $ACTUAL_HASH"
fi
echo "      hash matches sidecar: $ACTUAL_HASH"

# 2. AUTHENTICITY (+ TIMELINESS via the transparency-log entry inside the bundle)
#    Run cosign verify-blob against the bundle using the .sig.bundle file.
echo "[2/3] Authenticity — verifying Cosign signature"
if [[ ! -f "$SIGBUNDLE" ]]; then
  fail "signature bundle not found: $SIGBUNDLE"
fi

if ! command -v cosign >/dev/null 2>&1; then
  fail "cosign not installed"
fi

if ! cosign verify-blob \
  --bundle "$SIGBUNDLE" \
  --certificate-oidc-issuer "$OIDC_ISSUER" \
  --certificate-identity-regexp "$IDENTITY_REGEXP" \
  "$BUNDLE" 2>/tmp/verify-evidence-cosign.log; then
  fail "cosign verify-blob failed: $(cat /tmp/verify-evidence-cosign.log)"
fi
echo "      signature verified against issuer: $OIDC_ISSUER"

# 3. PRESERVATION (stretch — only runs if a vault was configured)
#    If uploaded to an S3 Object Lock vault, confirm retention is still in the future.
PRESERVATION_STATUS="skipped (no vault configured)"
if [[ -n "${VAULT_BUCKET:-}" && -n "${VAULT_KEY:-}" ]]; then
  echo "[3/3] Preservation — checking Object Lock retention on s3://${VAULT_BUCKET}/${VAULT_KEY}"
  if ! command -v aws >/dev/null 2>&1; then
    fail "aws CLI not installed but VAULT_BUCKET is set"
  fi
  RETAIN_UNTIL=$(aws s3api get-object-retention \
    --bucket "$VAULT_BUCKET" --key "$VAULT_KEY" \
    --query 'Retention.RetainUntilDate' --output text)
  NOW_EPOCH=$(date -u +%s)
  RETAIN_EPOCH=$(date -u -d "$RETAIN_UNTIL" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$RETAIN_UNTIL" +%s)
  if [[ "$RETAIN_EPOCH" -le "$NOW_EPOCH" ]]; then
    fail "retention date $RETAIN_UNTIL is not in the future"
  fi
  PRESERVATION_STATUS="retained until $RETAIN_UNTIL"
else
  echo "[3/3] Preservation — $PRESERVATION_STATUS"
fi

echo
echo "CHAIN INTACT"
echo "  integrity:    hash match"
echo "  authenticity: cosign signature valid ($OIDC_ISSUER)"
echo "  preservation: $PRESERVATION_STATUS"

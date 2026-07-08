# Tamper test results

Run 2026-07-07 against the CI-signed artifact from workflow run
[28897443748](https://github.com/joseruiz1571/grc-pipeline-challenge/actions/runs/28897443748)
(PR #3, `week-4/signing`). The bundle was signed keyless in GitHub Actions;
verification ran locally with the identity pinned to the exact workflow:

```
VERIFY_IDENTITY_REGEXP='^https://github.com/joseruiz1571/grc-pipeline-challenge/\.github/workflows/grc-gate\.yml@.*$'
```

## Real bundle

```
$ ./verify-evidence.sh evidence.tar.gz
[1/3] Integrity — recomputing SHA-256 of evidence.tar.gz
      hash matches sidecar: 950b9296de9a3b900dcabd444db0b05b4ff43530d7de1abac9eb7f4dae6954cd
[2/3] Authenticity — verifying Cosign signature
      signature verified against issuer: https://token.actions.githubusercontent.com
[3/3] Preservation — skipped (no vault configured)

CHAIN INTACT
  integrity:    hash match
  authenticity: cosign signature valid (https://token.actions.githubusercontent.com)
  preservation: skipped (no vault configured)

exit code: 0
```

## Tampered bundle (one byte appended)

```
$ cp evidence.tar.gz tampered.tar.gz && printf 'X' >> tampered.tar.gz
$ ./verify-evidence.sh tampered.tar.gz
[1/3] Integrity — recomputing SHA-256 of tampered.tar.gz
CHAIN BROKEN: hash mismatch — expected 950b9296de9a3b900dcabd444db0b05b4ff43530d7de1abac9eb7f4dae6954cd, got 51d5e0c605aee3e8a4b1a5ec8262a0525a8b7a07a1972621660239e78491dab7

exit code: 1
```

262 bytes vs 263 bytes. One appended byte, caught immediately.

## Signature check fails independently on the same byte

Skipping the hash check does not save a tampered bundle — `cosign verify-blob`
rejects it on its own, because the signature was computed over the original bytes:

```
$ cosign verify-blob --bundle evidence.tar.gz.sig.bundle \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    tampered.tar.gz
Error: error verifying bundle: matching bundle to payload:
  bundle="950b9296...6954cd", payload="51d5e0c6...91dab7"
```

Integrity and authenticity fail independently on the same one-byte change.
Custody is math, not a promise.

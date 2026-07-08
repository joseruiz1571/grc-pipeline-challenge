# Week 4 starter: Evidence You Can Trust

Chain of custody means anyone can prove your evidence is authentic and untouched, without trusting you. You build two things: a signing step that runs in your pipeline, and a verify script that checks the result.

## The signing step (you add it to week 3's workflow)

After your gate produces `evidence/`, add a step that:

1. Bundles `evidence/` into a single `.tar.gz`.
2. Writes the bundle's SHA-256 to a `.sha256` sidecar file.
3. Signs the bundle with Cosign, keyless: `cosign sign-blob --yes --bundle evidence.sig.bundle <bundle>`.

Keyless signing means no private key. In GitHub Actions, Cosign uses the workflow's OIDC token, so the signature is tied to your pipeline run. The job needs `permissions: id-token: write` or the signing fails. The `--bundle` file packs the signature, the certificate, and the transparency-log entry into one file your verifier reads.

You can also sign locally to learn the flow: `cosign sign-blob` will open a browser for a one-time identity check. Still free, still keyless.

## The verify script (fill in verify-evidence.sh)

Three checks, each exits non-zero on failure:

1. **Integrity.** Recompute the SHA-256, compare to the sidecar.
2. **Authenticity.** `cosign verify-blob` against the `.sig.bundle`, pinning the OIDC issuer.
3. **Preservation** (stretch). If you used a vault, confirm the Object Lock retention is still in the future.

Print `CHAIN INTACT` only if all checks pass.

## The tamper test (this is the deliverable)

```bash
cp evidence.tar.gz /tmp/tampered.tar.gz
echo "junk" >> /tmp/tampered.tar.gz
./verify-evidence.sh /tmp/tampered.tar.gz   # must FAIL on integrity
./verify-evidence.sh evidence.tar.gz        # must say CHAIN INTACT
```

One changed byte breaks the chain. That failure is the whole point: custody is mathematical, not a promise.

## Cost

Free. Sigstore signing and verification cost nothing and need no cloud account. The only paid piece is the optional vault, which is pennies and gets torn down.

## Stretch: the immutable vault

For true preservation, upload the signed bundle to an S3 bucket with Object Lock and versioning on, so nobody can overwrite or delete it. Apply it, push one bundle, verify retention, then tear it down the same day. The brief covers the setup and teardown.

**Not built this round.** `verify-evidence.sh` skips the preservation check (prints "skipped — no vault configured") rather than faking a pass. `CHAIN INTACT` here means integrity and authenticity both verified — not that all four custody properties were tested.

## Chain of custody, mapped to artifacts

| Property | Question it answers | Artifact that proves it |
|----------|---------------------|--------------------------|
| **Authenticity** | Who produced this? | The Cosign signature and Fulcio certificate in `evidence.tar.gz.sig.bundle` — the certificate encodes the exact repo and workflow that signed it. Nobody, including someone with admin on the cloud account, can forge it, because the proof lives in Sigstore's transparency log, not in the repo's infrastructure. |
| **Integrity** | Has it changed since? | The SHA-256 in `evidence.tar.gz.sha256`. `verify-evidence.sh` recomputes the hash and compares — any changed byte, anywhere in the archive, produces a mismatch. |
| **Timeliness** | When was it produced? | The transparency-log entry embedded in the `.sig.bundle`. Sigstore's public log timestamps the signing event at inclusion; there's no way to backdate a bundle after the fact without a new log entry showing the real time. |
| **Preservation** | Can it still be retrieved, unaltered? | Not proven this round — this is the S3 Object Lock stretch above, deliberately left undone rather than simulated. |

## The tamper test

```bash
cp evidence.tar.gz /tmp/tampered.tar.gz
echo "junk" >> /tmp/tampered.tar.gz
cp evidence.tar.gz.sha256 evidence.tar.gz.sig.bundle /tmp/
./verify-evidence.sh /tmp/tampered.tar.gz   # CHAIN BROKEN on integrity
./verify-evidence.sh evidence.tar.gz        # CHAIN INTACT
```

One appended byte changes the hash. The signature was computed over the original bytes, so even if you skipped the hash check, `cosign verify-blob` would still reject the tampered copy — integrity and authenticity fail independently, on the same one-byte change. That double failure is the whole argument for chain of custody: it isn't a policy, it's math.

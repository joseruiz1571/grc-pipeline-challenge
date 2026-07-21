# Week 6 — Speak the Auditor's Language

Weeks 1-5 produced controls and signed evidence. Week 6 restates what the repo actually implements in OSCAL 1.2.1, the machine-readable format auditors and GRC platforms consume, using [compliance-trestle](https://github.com/oscal-compass/compliance-trestle) as the authoring and validation toolchain.

## What's here

| Artifact | Purpose |
|----------|---------|
| [component-definitions/grc-pipeline/](component-definitions/grc-pipeline/) | One implemented requirement per control, each naming the real Terraform resource or Rego policy and linking (`rel: evidence`) to a Cosign-signed bundle in this repo |
| [profiles/grc-pipeline-controls/](profiles/grc-pipeline-controls/) | Exactly the six controls the repo genuinely implements, selected from the NIST SP 800-53 rev5 catalog: AC-3, AU-2, AU-10, AU-12, CM-6, SC-28 |
| [evidence/traversal-proof.txt](evidence/traversal-proof.txt) | Proof the links resolve: AU-10's evidence href followed from the component definition to the bundle, `verify-evidence.sh` → CHAIN INTACT |
| [evidence/ci-signed/](evidence/ci-signed/) | The CI-signed conftest evidence bundle (GitHub Actions OIDC) the SC-28/AC-3/CM-6 claims link to |
| [vault/](vault/) | Evidence vault in Terraform: GCS bucket with retention policy (the GCS analog of S3 Object Lock), consumed by `verify-evidence.sh`'s preservation check via `VAULT_GCS_BUCKET`/`VAULT_KEY` |

## Reproduce

```bash
cd week-6
python3 -m venv .venv && .venv/bin/pip install compliance-trestle
.venv/bin/trestle validate -a
# VALID: component-definition.json
# VALID: profile.json
```

## The claims are smaller than the READMEs

The profile deliberately excludes controls the READMEs mention:

- **AU-3 / AU-6** — Week 1's access logging is implemented, but no signed bundle evidences it and nothing reviews the logs. AU-12 is still claimed, with its AU-3 content dependency named as asserted-not-evidenced in the component definition.
- **SI-4 / RA-5** — SCC Standard is activated, but Security Health Analytics is unentitled on new Standard-tier activations (see Week 5's tier-drift finding), so no scanner actually runs.
- **AU-9** — joins the profile only after the vault is applied and the preservation check passes against it.

The claims that stay are scoped, not maximal: AU-10 covers non-repudiation of evidence production (not of user actions), and CM-6 is mapped clause-by-clause with clause (c), deviation approval, admitted as unevidenced.

A note on what "valid" means: `trestle validate` checks OSCAL schema conformance — it does not dereference evidence hrefs or verify signatures. That is what [evidence/traversal-proof.txt](evidence/traversal-proof.txt) is for: it follows an href to the bundle and runs the full Cosign verification.

A control claim that cannot be traced to signed evidence is not a claim an auditor can use, so it does not appear in the OSCAL. That subtraction is the week's actual lesson.

# Case Study: A GRC Pipeline That Proves Its Own Claims

Six weeks, one repo: [grc-pipeline-challenge](https://github.com/joseruiz1571/grc-pipeline-challenge). The GRC Engineering Club challenge, implemented on GCP instead of the AWS it was written for. The through-line is a single idea: every compliance claim in this repo traces to a machine-verifiable artifact, and anything that cannot be traced is not claimed.

## What got built

**Week 1 — Compliant storage in Terraform.** A GCS bucket pair (primary + access logs) enforcing SC-28 (encryption at rest), AC-3 (uniform bucket-level access, public access prevention), CM-6 (four required labels), and access logging. Control attestations emitted as Terraform outputs, so proof is machine-readable from day one. [week-1/](week-1/)

**Week 2 — Policy-as-code.** The same three controls written as Rego for OPA, in AWS and GCP twin versions, with unit tests: `opa test` passes 6/6. The policy is now the spec, not the README. [week-2/policies/](week-2/policies/)

**Week 3 — The CI gate.** GitHub Actions runs conftest against the Terraform plan on every PR. Proven with a live pair: [PR #1 (green)](https://github.com/joseruiz1571/grc-pipeline-challenge/pull/1) passes all three policy namespaces and merges; [PR #2 (red)](https://github.com/joseruiz1571/grc-pipeline-challenge/pull/2) flips `public_access_prevention` off and is blocked by branch protection until the control is restored. The gate does not trust the author. [week-3/](week-3/)

**Week 4 — Evidence you can trust.** CI-produced evidence is Cosign keyless-signed (GitHub Actions OIDC identity, Rekor transparency log). `verify-evidence.sh` proves three things about any bundle: integrity (SHA-256 sidecar), authenticity (signature against a pinned identity), preservation (vault retention window). The tamper test shows both faces: CHAIN INTACT on the real bundle, CHAIN BROKEN on a modified byte. [week-4/](week-4/)

**Week 5 — Turn on the cameras.** Data Access audit logging (AU-2, AU-12, AU-10) and org policy constraints (CM-6) in Terraform, live-verified. Then the interesting failure: Security Command Center Standard was activated, sources registered, and zero findings ever arrived, because Google's tier restructure removed Security Health Analytics from new Standard-tier activations. The compliance tier drifted out from under the compliance pipeline. The response is `check-scc-entitlement.sh`, a post-activation gate that asserts every expected scanner is effectively ENABLED and exits non-zero on drift. The failing run is itself Cosign-signed evidence. [week-5/](week-5/)

**Week 6 — Speak the auditor's language.** The repo's claims, restated as OSCAL 1.2.1 and validated with compliance-trestle:

- A [component definition](week-6/component-definitions/grc-pipeline/component-definition.json) with one implemented requirement per control, each naming the actual Terraform resource or Rego policy and linking (`rel: evidence`) to a Cosign-signed bundle in this repo.
- A [profile](week-6/profiles/grc-pipeline-controls/profile.json) selecting exactly the six controls the repo genuinely implements against the NIST SP 800-53 rev5 catalog: AC-3, AU-2, AU-10, AU-12, CM-6, SC-28.
- `trestle validate`: VALID on both models.
- A [traversal proof](week-6/evidence/traversal-proof.txt): follow AU-10's evidence link from the component definition to the bundle, run `verify-evidence.sh`, get CHAIN INTACT.
- An [evidence vault](week-6/vault/) in Terraform: GCS bucket with a retention policy (the GCS analog of S3 Object Lock), wired into `verify-evidence.sh`'s preservation check.

## The honest part

The OSCAL profile claims fewer controls than the READMEs mention. That is deliberate:

- **AU-3 / AU-6 excluded.** Week 1's access logging is implemented, but no signed evidence bundle covers it, and nothing in the pipeline reviews the logs. A claim an auditor cannot trace to evidence is not a claim.
- **SI-4 / RA-5 excluded.** SCC Standard is activated, but Security Health Analytics is unentitled on new Standard-tier activations, so no scanner actually runs. Claiming continuous monitoring on the strength of an activation click would be exactly the kind of padding this pipeline exists to prevent.

The subtraction is the point. Compliance-as-code is not about generating more claims faster; it is about making every claim falsifiable, and then only keeping the ones that survive.

## What I would do next with more time

Close the monitoring gap for real. The SCC Premium pay-as-you-go activation is accepted by the console but has not propagated to the subscription API at either org or project scope, and the entitlement-drift gate correctly refuses to call that done. When the tier actually flips, the sequence is already built: the gate exits 0 on a verified tier change, Security Health Analytics runs its first scan, the findings get captured through the same canonicalized path, signed, and vaulted, and SI-4/RA-5 move from the excluded list into the OSCAL profile with evidence behind them. Beyond that: extend the Week 3 CI gate to cover audit-log and org-policy drift, not just storage controls, and produce signed log-review evidence so AU-3/AU-6 can be claimed instead of excluded.

## The one non-obvious thing that clicked

Entitlement has a hierarchy, and a check that asserts the wrong layer produces verdicts that are true but useless. Subscription tier grants service entitlement, service entitlement grants scanner execution, and the console UI confirmed actions at every layer while the backing state moved at none of them. Three times in one week the interface said done and the API said otherwise. The fix was never more monitoring; it was asserting the highest layer the pipeline depends on and reporting the topmost mismatch. The click is not the control. The activation is not the entitlement. The record is not the shelf.

| Check | Result | Where |
|-------|--------|-------|
| `terraform validate` | Success (weeks 1, 5, 6-vault) | each week's directory |
| `conftest` / `opa test` | CI gate green; 6/6 policy tests | [grc-gate.yml](.github/workflows/), [PR #1](https://github.com/joseruiz1571/grc-pipeline-challenge/pull/1) / [PR #2](https://github.com/joseruiz1571/grc-pipeline-challenge/pull/2) |
| `trestle validate` | VALID (component definition + profile) | [week-6/](week-6/) |
| `cosign verify` | CHAIN INTACT (CI-signed and locally-signed bundles) | [week-6/evidence/traversal-proof.txt](week-6/evidence/traversal-proof.txt) |
| vault upload | both signed bundles in `gs://grc-pipeline-dev-evidence-vault-d24bb9f0`, retention until 2026-10-19, preservation check passing live | [week-6/vault/](week-6/vault/), [traversal-proof.txt](week-6/evidence/traversal-proof.txt) |

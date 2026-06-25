# GRC Pipeline Challenge

Six weeks. One compliant cloud pipeline. Controls in code, not documents.

This is the [GRC Engineering Club](https://www.grcengclub.com/) pipeline challenge, implemented on GCP. Each week adds one layer: storage, policy, scanning, reporting, signing, deployment gate.

## Weeks

| Week | Topic | Status |
|------|-------|--------|
| [Week 1](week-1/) | Compliant Cloud Storage — 5 NIST 800-53 controls in Terraform | Complete |
| [Week 2](week-2/) | Policy-as-code — SC-28, AC-3, CM-6 as Rego (OPA), AWS + GCP twins | Complete |
| Week 3 | | |
| Week 4 | | |
| Week 5 | | |
| Week 6 | | |

Each week's directory contains the Terraform source and `evidence/plan.json` — the machine-readable artifact the next week reads.

## Platform

Implemented on GCP. The challenge was originally written for AWS. The controls are identical; the provider resources differ. Week 1 includes notes on where GCP and AWS diverge.

## Prerequisites

- Terraform 1.6+
- GCP project with Storage Admin permissions
- `gcloud` CLI: `gcloud auth application-default login`
- [OPA](https://www.openpolicyagent.org/) and [Conftest](https://www.conftest.dev/) (Week 2 onward): `brew install opa conftest`

# Week 3 — Build the Gate

Week 2 proved the policies work. Week 3 makes them mandatory. The three Rego namespaces from Week 2 are wired into a GitHub Actions workflow that runs on every pull request to main and blocks any merge that breaks a control. Nobody reviews the change for encryption. The gate does, in seconds.

## What the gate enforces

| Control | Namespace | What it checks |
|---------|-----------|----------------|
| **SC-28** — Encryption at Rest | `compliance.sc28_gcp` | No `google_storage_bucket` has an `encryption` block with an empty KMS key (broken CMEK). Default GMEK passes. |
| **AC-3** — Access Enforcement | `compliance.ac3_gcp` | Every `google_storage_bucket` sets `public_access_prevention = "enforced"` and `uniform_bucket_level_access = true`. |
| **CM-6** — Configuration Settings | `compliance.cm6_gcp` | Every taggable resource carries all four required labels: `project`, `environment`, `managed_by`, `compliance_scope`. |

## How the gate works

```
pull request opened
       ↓
actions/checkout@v4
       ↓
Install Conftest (pinned version)
       ↓
conftest test week-1/evidence/plan.json \
  --policy week-2/policies \
  --namespace compliance.ac3_gcp \
  --namespace compliance.cm6_gcp \
  --namespace compliance.sc28_gcp \
  --output json > evidence/conftest-results.json
       ↓
exit $GATE_EXIT  ← non-zero if any namespace reported a violation
       ↓
Upload evidence/ artifact (runs always — survives failure)
```

The plan checked by the gate is `week-1/evidence/plan.json` — committed to the repo, not generated in CI. This is the simple, free, no-secrets path. Week 4 signs the evidence so it cannot be quietly edited.

## What happens when a control breaks

Conftest exits non-zero. The `Run policy gate` step fails. The `grc-gate` check goes red. With branch protection enabled (Settings > Branches > require `grc-gate` to pass), the pull request cannot be merged until the violation is fixed. That is the entire value proposition: the gate is not a suggestion, it is infrastructure.

## The two-PR demonstration

Both PRs are in the repo's history.

**[PR #1 — green](https://github.com/joseruiz1571/grc-pipeline-challenge/pull/1):** compliant `plan.json`, all three namespaces pass, merged to main.

**[PR #2 — red](https://github.com/joseruiz1571/grc-pipeline-challenge/pull/2):** `public_access_prevention` flipped from `enforced` to `inherited` on both buckets. AC-3 reports two violations, `grc-gate` fails, merge is blocked by branch protection. The PR cannot be merged until the control is restored.

## Files

```
.github/
  workflows/
    grc-gate.yml        # the gate — runs on every PR to main
week-1/
  evidence/
    plan.json           # the plan the gate reads (committed, compliant)
week-2/
  policies/
    ac3_no_public_gcp.rego
    cm6_required_labels_gcp.rego
    sc28_encryption_gcp.rego
```

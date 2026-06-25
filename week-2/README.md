# Week 2 — Make the Rules Executable

Week 1 produced a *compliant* bucket. "Compliant" is a claim someone has to check, and people are slow, inconsistent, and expensive. This week the claim becomes code: Rego policies (Open Policy Agent) that read a Terraform plan and return a verdict on each control, the same way every time, in milliseconds.

## The three controls

| Control | What it enforces |
|---------|------------------|
| **SC-28** — Encryption at Rest | Every bucket has effective encryption at rest. |
| **AC-3** — Access Enforcement | Every bucket hard-blocks public access. |
| **CM-6** — Configuration Settings | Every taggable resource carries the four required compliance tags/labels. |

Each control ships in two flavors: **AWS** (`aws_s3_bucket`, tags) and a **GCP twin** (`google_storage_bucket`, labels). The control IDs are identical across both — that is the point. *A control is portable; a rule that hardcodes one cloud's resource type is not.*

## Run the unit tests

The AWS policies are pinned by a test suite (the `*_test.rego` files are the spec — do not edit them).

```bash
opa test policies/ -v
```

```
PASS: 6/6
```

Two tests per control: one compliant plan that must produce zero denials, one broken plan that must produce exactly one.

## Run the gate against a real Terraform plan

```bash
# in the terraform dir
terraform plan -out=tfplan
terraform show -json tfplan > plan.json

# GCP twins against the Week 1 plan (this build is GCP)
conftest test --policy policies --namespace compliance.sc28_gcp plan.json
conftest test --policy policies --namespace compliance.ac3_gcp  plan.json
conftest test --policy policies --namespace compliance.cm6_gcp  plan.json
```

All three pass against the compliant Week 1 plan. To prove the gate actually catches things, break a copy — flip `public_access_prevention` to `inherited` — and re-run AC-3:

```
FAIL - plan.json - compliance.ac3_gcp - AC-3: google_storage_bucket.primary does not enforce
  public access prevention (is "inherited"). Remediation: set public_access_prevention = "enforced".
```

`conftest` exits non-zero on any failure — that non-zero exit is what blocks a pull request next week.

## The one technique that trips everyone up: match by reference

At plan time the bucket's real name does not exist yet — its random suffix has not been generated. So you **cannot** match an encryption or public-access-block resource to its bucket by comparing names. You match by **reference**.

In `terraform show -json` output, two parts matter:

- `configuration.root_module.resources[]` — what you *declared*, including the static references between resources. An encryption resource records that its `bucket` argument references `"aws_s3_bucket.primary.id"`.
- `planned_values.root_module.resources[]` — the concrete *values* Terraform intends to set (the four PAB flags, the tag map).

So SC-28 and AC-3 work in two halves:

1. In `configuration`, collapse a reference like `aws_s3_bucket.primary.id` down to its resource **address** `aws_s3_bucket.primary` (first two dot-segments) and check whether the control resource points back at the bucket's address. No names, no suffixes — addresses are stable at plan time.
2. For AC-3, then read the four flag **values** from `planned_values` by the block's address.

CM-6 needs none of this: tags/labels are plain values in `planned_values`, so it reads them directly and recurses into `child_modules` via Rego's `walk()`.

### A note on SC-28 across clouds

SC-28 is the clearest illustration of why a control is not a rule. On AWS, encryption at rest is a *separate resource* you must declare and reference — so the AWS policy matches by reference. On GCP, Cloud Storage encrypts every object at rest by default with a Google-managed key (GMEK); there is no separate resource and you cannot turn it off. A naive "bucket exists" check would be a no-op gate, so the GCP twin instead targets the realistic failure mode: a half-configured customer-managed key (an `encryption` block declared with no KMS key name). Same control ID, same intent, two different shapes.

## Files

```
policies/
  sc28_encryption_aws.rego        sc28_encryption_aws_test.rego   (spec)
  ac3_no_public_aws.rego          ac3_no_public_aws_test.rego     (spec)
  cm6_required_tags_aws.rego      cm6_required_tags_aws_test.rego (spec)
  sc28_encryption_gcp.rego        ac3_no_public_gcp.rego
  cm6_required_labels_gcp.rego
```

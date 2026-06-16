# Week 1 GCP: Your First Compliant Resource

This Terraform module provisions a compliant Google Cloud Storage bucket that enforces
SC-28 (encryption at rest), AC-3 (public access enforcement), CM-6 (versioning and
tagging), and AU-3/AU-6 (access logging) — and emits machine-readable proof of each
control as Terraform outputs.

## Controls implemented

| Control | Requirement | GCS mechanism |
|---------|-------------|---------------|
| SC-28 | Encryption at rest | Google-managed AES-256 (GMEK, always on). Outputs `encryption_algorithm`. |
| AC-3 | Block all public access | `uniform_bucket_level_access = true` + `public_access_prevention = "enforced"` |
| CM-6 | Versioning | `versioning { enabled = true }` on the primary bucket |
| CM-6 | Required labels | `labels` block with `project`, `environment`, `managed_by`, `compliance_scope` |
| AU-3/AU-6 | Access logging | `logging { log_bucket = ... }` pointing primary to a dedicated log bucket |

**GCP vs AWS note on AC-3**: AWS exposes four separate public-access flags; GCP gives you
two complementary controls. `uniform_bucket_level_access` disables legacy per-object ACLs
entirely. `public_access_prevention = "enforced"` blocks public IAM grants at the resource
level. Together they cover the same surface the four AWS flags do.

**GCP vs AWS note on AU-3**: AWS S3 requires ownership controls and a `log-delivery-write`
ACL before logging works — sequence matters. GCS has no equivalent dance. Setting
`uniform_bucket_level_access = true` on the log bucket and pointing `logging {}` at it is
sufficient. The dependency is structural, not procedural.

**GCP vs AWS note on SC-28**: AWS requires an explicit `aws_s3_bucket_server_side_encryption_configuration`
resource. GCS encrypts every object with AES-256 by default (GMEK) with no configuration
required. The `encryption_algorithm` output attests to this in the plan JSON.

## Prerequisites

- GCP project with `roles/storage.admin` (or equivalent) on your account
- Terraform 1.6 or newer: `terraform version`
- gcloud CLI authenticated: `gcloud auth application-default login`
- gsutil available (ships with gcloud SDK)

## Run it

```bash
# 1. Set up credentials
gcloud auth application-default login

# 2. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set project_id to your GCP project

# 3. Initialize and plan
terraform init
terraform validate
terraform plan -out=tfplan

# 4. Capture the evidence artifact
mkdir -p evidence
terraform show -json tfplan > evidence/plan.json

# 5. Inspect the plan for your controls
# Look for: uniform_bucket_level_access, public_access_prevention, versioning,
#           logging, labels — all five controls should be visible in the JSON.

# 6. Optional: apply, verify, then destroy
terraform apply tfplan
./verify.sh
```

## Tear down

GCS will refuse to destroy a versioned bucket that still holds object versions.

```bash
# Empty the bucket first (including noncurrent versions)
gsutil -m rm -r "gs://$(terraform output -raw primary_bucket_name)"
gsutil -m rm -r "gs://$(terraform output -raw log_bucket_name)"

# Then destroy
terraform destroy
```

## Done when

- `terraform validate` passes
- `evidence/plan.json` shows `uniform_bucket_level_access`, `public_access_prevention = enforced`,
  `versioning.enabled = true`, four labels, and a `logging` block with a log bucket target
- `terraform output encryption_algorithm` returns `GOOGLE_MANAGED_AES256`
- (If applied) `./verify.sh` shows all controls passing

## Portfolio writeup

> This Terraform module enforces SC-28, AC-3, CM-6, and AU-3 on a Google Cloud Storage
> bucket and emits the proof as machine-readable JSON. Two GCS controls replace the four
> S3 public-access flags: uniform bucket-level access disables legacy ACLs; public access
> prevention enforces the hard block at the resource level. The evidence artifact is a
> Terraform plan JSON — no screenshots, no narrative, just the configuration the policy
> engine reads in Week 2.

## Files

- `main.tf` — provider, both buckets, all five controls
- `variables.tf` — input variables
- `outputs.tf` — bucket names, SC-28/AC-3/AU-3 attestation outputs
- `verify.sh` — post-apply control checks using gcloud and gsutil
- `terraform.tfvars.example` — copy to `terraform.tfvars` and edit
- `evidence/plan.json` — generated artifact (committed alongside code)

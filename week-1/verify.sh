#!/usr/bin/env bash
# Week 1 GCP verification. Run after `terraform apply`.
# Confirms: SC-28 (encryption), CM-6 (versioning + labels), AC-3 (public access), AU-3 (logging).
set -euo pipefail

BUCKET=$(terraform output -raw primary_bucket_name)
echo "Verifying bucket: gs://$BUCKET"
echo "=========================================="
echo

echo "SC-28 — encryption at rest:"
echo "  GCS encrypts all objects with AES-256 by default (GMEK)."
echo "  Terraform attestation output:"
echo "    encryption_algorithm = $(terraform output -raw encryption_algorithm)"
echo

echo "CM-6 — versioning:"
gsutil versioning get "gs://$BUCKET"
echo "  (expected: gs://$BUCKET: Enabled)"
echo

echo "AC-3 — public access prevention:"
echo -n "  publicAccessPrevention: "
gcloud storage buckets describe "gs://$BUCKET" \
  --format="value(iamConfiguration.publicAccessPrevention)"
echo "  (expected: enforced)"
echo

echo "AC-3 — uniform bucket-level access:"
echo -n "  uniformBucketLevelAccess: "
gcloud storage buckets describe "gs://$BUCKET" \
  --format="value(iamConfiguration.uniformBucketLevelAccess.enabled)"
echo "  (expected: True)"
echo

echo "AU-3 — access logging:"
gsutil logging get "gs://$BUCKET"
echo

echo "CM-6 — labels:"
gcloud storage buckets describe "gs://$BUCKET" --format="value(labels)"
echo "  (expected: compliance_scope=nist-800-53, environment=dev, managed_by=terraform, project=grc-challenge)"
echo

echo "=========================================="
echo "Pass when ALL of the following are true:"
echo "  encryption_algorithm         = GOOGLE_MANAGED_AES256"
echo "  versioning                   = Enabled"
echo "  publicAccessPrevention       = enforced"
echo "  uniformBucketLevelAccess     = True"
echo "  logging shows a log_bucket   = *-logs-*"
echo "  labels has all four required keys"

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.location
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  primary_name = "${var.project_name}-${var.environment}-data-${random_id.suffix.hex}"
  log_name     = "${var.project_name}-${var.environment}-logs-${random_id.suffix.hex}"

  # CM-6: four required labels on every resource
  common_labels = {
    project          = var.project_name
    environment      = var.environment
    managed_by       = "terraform"
    compliance_scope = "nist-800-53"
  }
}

# Log bucket — receives access logs from the primary bucket.
# Created first so the primary bucket's logging block can reference it.
resource "google_storage_bucket" "log" {
  name     = local.log_name
  location = var.location

  # AC-3: uniform IAM prevents per-object ACL grants that could expose data publicly
  uniform_bucket_level_access = true

  # AC-3: org-level hard block — no public access regardless of IAM policy
  public_access_prevention = "enforced"

  # CM-6: versioning makes log objects recoverable and provides an audit trail
  versioning {
    enabled = true
  }

  # SC-28: GCS encrypts all objects with AES-256 by default (Google-managed key, GMEK).
  # Omitting this block means GMEK is in effect. Add an encryption {} block with
  # a KMS key name here to upgrade to customer-managed key (CMEK).

  # CM-6 labels
  labels = local.common_labels
}

# Primary bucket — holds data. All five controls are implemented here.
resource "google_storage_bucket" "primary" {
  name     = local.primary_name
  location = var.location

  # AC-3: uniform IAM — disables per-object legacy ACLs entirely
  uniform_bucket_level_access = true

  # AC-3: hard enforcement of no public access at the resource level
  public_access_prevention = "enforced"

  # CM-6: versioning so prior object states are recoverable and auditable
  versioning {
    enabled = true
  }

  # AU-3/AU-6: ship access logs to the dedicated log bucket.
  # GCS does not require the ACL and ownership-control sequencing that S3 does —
  # uniform_bucket_level_access on the log bucket is sufficient for log delivery.
  logging {
    log_bucket        = google_storage_bucket.log.name
    log_object_prefix = "access-logs/"
  }

  # SC-28: see note on log bucket above (GMEK in effect)
  # CM-6 labels
  labels = local.common_labels
}

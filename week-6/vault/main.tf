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
  vault_name = "${var.project_name}-${var.environment}-evidence-vault-${random_id.suffix.hex}"

  # CM-6: four required labels on every resource (week-1 convention)
  common_labels = {
    project          = var.project_name
    environment      = var.environment
    managed_by       = "terraform"
    compliance_scope = "nist-800-53"
  }
}

# Evidence vault: write-once storage for signed evidence bundles.
# GCS has no per-object Object Lock; the equivalent preservation guarantee is a
# bucket retention policy — every object is undeletable and unmodifiable until
# timeCreated + retention_period. verify-evidence.sh's preservation check
# (VAULT_GCS_BUCKET + VAULT_KEY) asserts exactly this window.
resource "google_storage_bucket" "vault" {
  name     = local.vault_name
  location = var.location

  # AC-3: no public access, no legacy ACLs — same posture as week-1 buckets.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # AU-9 (protection of audit information): bundles cannot be deleted or
  # overwritten inside the retention window, even by the bucket owner,
  # unless the policy itself is first relaxed (and locking prevents even that).
  retention_policy {
    retention_period = var.retention_seconds
    # is_locked = true would make the policy irreversible. Deliberately left
    # unlocked for this challenge: locking is permanent and the org is personal.
  }

  versioning {
    enabled = true
  }

  labels = local.common_labels

  # Refuse to destroy the vault while it holds evidence.
  force_destroy = false
}

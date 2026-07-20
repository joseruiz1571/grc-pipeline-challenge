terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = var.project_id

  # ADC via `gcloud auth application-default login` doesn't attach a quota
  # project to org-policy API calls by default (falls back to the gcloud
  # CLI's own OAuth client project instead) unless the provider explicitly
  # overrides it here.
  user_project_override = true
  billing_project       = var.project_id
}

# AU-2 / AU-12: Data Access audit logs for Cloud Storage.
# Scoped to storage + iam only (not allServices) so the config reads as a
# deliberate decision, not a blanket enable that floods the log sink.
resource "google_project_iam_audit_config" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# AU-2 / AU-10: Data Access audit logs for IAM — who changed access, chain of
# custody for identity operations touching the resources Weeks 1-4 built.
resource "google_project_iam_audit_config" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
}

# CM-6: configuration guardrail, not an action-deny (that's IAM Deny Policy,
# out of scope here). Prevents long-lived service-account keys from being
# minted in this project going forward.
resource "google_org_policy_policy" "disable_sa_key_creation" {
  name   = "projects/${var.project_id}/policies/iam.disableServiceAccountKeyCreation"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# CM-6: configuration guardrail on the bucket surface Weeks 1-2 built —
# belt-and-suspenders alongside the per-bucket AC-3 setting from Week 1.
resource "google_org_policy_policy" "storage_public_access_prevention" {
  name   = "projects/${var.project_id}/policies/storage.publicAccessPrevention"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

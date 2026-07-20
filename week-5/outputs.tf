# AU-2 / AU-12 attestation.
output "storage_audit_log_types" {
  description = "AU-2/AU-12 attestation: Data Access log types enabled for Cloud Storage."
  value       = [for c in google_project_iam_audit_config.storage.audit_log_config : c.log_type]
}

# AU-2 / AU-10 attestation.
output "iam_audit_log_types" {
  description = "AU-2/AU-10 attestation: Data Access log types enabled for IAM."
  value       = [for c in google_project_iam_audit_config.iam.audit_log_config : c.log_type]
}

# CM-6 attestation.
output "sa_key_creation_disabled_policy" {
  description = "CM-6 attestation: org policy name enforcing iam.disableServiceAccountKeyCreation."
  value       = google_org_policy_policy.disable_sa_key_creation.name
}

# CM-6 attestation.
output "storage_public_access_prevention_policy" {
  description = "CM-6 attestation: org policy name enforcing storage.publicAccessPrevention."
  value       = google_org_policy_policy.storage_public_access_prevention.name
}

output "vault_bucket" {
  description = "Name of the evidence vault bucket — pass as VAULT_GCS_BUCKET to verify-evidence.sh."
  value       = google_storage_bucket.vault.name
}

output "retention_seconds" {
  description = "AU-9 attestation: retention window enforced on every object in the vault."
  value       = google_storage_bucket.vault.retention_policy[0].retention_period
}

output "public_access_prevention" {
  description = "AC-3 attestation: public access prevention on the vault."
  value       = google_storage_bucket.vault.public_access_prevention
}

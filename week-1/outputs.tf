output "primary_bucket_name" {
  description = "Primary bucket name."
  value       = google_storage_bucket.primary.name
}

output "primary_bucket_url" {
  description = "Primary bucket URL (gs://...)."
  value       = google_storage_bucket.primary.url
}

output "log_bucket_name" {
  description = "Log bucket name."
  value       = google_storage_bucket.log.name
}

# SC-28 attestation.
# GCS always encrypts objects with AES-256. When the encryption {} block is absent,
# Google-managed keys (GMEK) are in use. When a KMS key is configured,
# encryption[0].default_kms_key_name is set and this output reflects CMEK.
output "encryption_algorithm" {
  description = "SC-28 attestation: encryption mode on the primary bucket."
  value       = length(google_storage_bucket.primary.encryption) > 0 ? "CUSTOMER_MANAGED_KEY" : "GOOGLE_MANAGED_AES256"
}

# AC-3 attestation.
output "public_access_prevention" {
  description = "AC-3 attestation: public_access_prevention setting on the primary bucket."
  value       = google_storage_bucket.primary.public_access_prevention
}

# AU-3 attestation.
output "log_bucket_target" {
  description = "AU-3 attestation: bucket receiving access logs from the primary."
  value       = google_storage_bucket.primary.logging[0].log_bucket
}

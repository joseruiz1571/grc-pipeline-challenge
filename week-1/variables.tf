variable "project_id" {
  type        = string
  description = "GCP project ID to deploy into. Find it in the Cloud Console or via: gcloud config get-value project"
}

variable "location" {
  type        = string
  description = "GCS bucket location. Multi-regional (US, EU, ASIA) or regional (us-central1, us-east1, etc.)."
  default     = "US"
}

variable "project_name" {
  type        = string
  description = "Short project identifier. Becomes part of bucket names and the project label. Must be lowercase."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 3-21 lowercase alphanumerics or hyphens, starting with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment. Drives the environment label."
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

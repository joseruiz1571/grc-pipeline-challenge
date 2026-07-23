variable "project_id" {
  description = "GCP project that hosts the evidence vault."
  type        = string
}

variable "project_name" {
  description = "Short project name used in resource naming and labels."
  type        = string
  default     = "grc-pipeline"
}

variable "environment" {
  description = "Environment label (dev, prod, ...)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "GCS location for the vault bucket."
  type        = string
  default     = "US-CENTRAL1"
}

variable "retention_seconds" {
  description = "Bucket retention policy in seconds. Default 90 days — long enough to outlive the challenge grading window, short enough that a personal org is not stuck with undeletable objects for years."
  type        = number
  default     = 7776000
}

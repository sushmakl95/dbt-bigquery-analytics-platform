variable "gcp_project" {
  type        = string
  description = "GCP project ID"
}

variable "gcp_region" {
  type    = string
  default = "US"
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "dbt_service_account_email" {
  type        = string
  description = "Service account dbt runs as — gets DataOwner on all layers."
}

variable "analysts_group_email" {
  type        = string
  description = "GCP group that gets DataViewer on gold + audit datasets."
}

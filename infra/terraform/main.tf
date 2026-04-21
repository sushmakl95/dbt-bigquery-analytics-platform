terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.20"
    }
  }

  backend "gcs" {
    # Configure via `terraform init -backend-config=envs/dev.backend.hcl`
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

# -----------------------------------------------------------------------------
# BigQuery datasets — one per medallion layer
# -----------------------------------------------------------------------------
module "bronze_dataset" {
  source = "./modules/bigquery"

  dataset_id    = "bronze"
  friendly_name = "Bronze — raw vendor tables (Fivetran-landed)"
  description   = "1:1 mirror of source systems. Schema as delivered by Fivetran."
  location      = var.gcp_region
  default_table_expiration_ms = 7776000000  # 90 days

  access = [
    { role = "roles/bigquery.dataOwner",  user_by_email = var.dbt_service_account_email }
  ]

  labels = {
    layer       = "bronze"
    environment = var.environment
  }
}

module "silver_dataset" {
  source = "./modules/bigquery"

  dataset_id    = "silver"
  friendly_name = "Silver — cleansed + conformed intermediate models"
  description   = "Intermediate business-logic tables. Ephemeral or tables."
  location      = var.gcp_region

  access = [
    { role = "roles/bigquery.dataOwner",  user_by_email = var.dbt_service_account_email }
  ]

  labels = {
    layer       = "silver"
    environment = var.environment
  }
}

module "gold_dataset" {
  source = "./modules/bigquery"

  dataset_id    = "gold"
  friendly_name = "Gold — business-facing marts"
  description   = "BI + ML consumption tables. Partitioned + clustered."
  location      = var.gcp_region

  access = [
    { role = "roles/bigquery.dataOwner",  user_by_email = var.dbt_service_account_email },
    { role = "roles/bigquery.dataViewer", group_by_email = var.analysts_group_email }
  ]

  labels = {
    layer       = "gold"
    environment = var.environment
  }
}

module "snapshots_dataset" {
  source = "./modules/bigquery"

  dataset_id    = "snapshots"
  friendly_name = "Snapshots — SCD2 historical records"
  description   = "dbt snapshot target. Never deleted."
  location      = var.gcp_region

  access = [
    { role = "roles/bigquery.dataOwner", user_by_email = var.dbt_service_account_email }
  ]
}

module "audit_dataset" {
  source = "./modules/bigquery"

  dataset_id    = "audit"
  friendly_name = "Audit — dbt run metadata"
  description   = "Populated by dbt on-run-end hook."
  location      = var.gcp_region

  default_table_expiration_ms = 15552000000  # 180 days

  access = [
    { role = "roles/bigquery.dataOwner",  user_by_email = var.dbt_service_account_email },
    { role = "roles/bigquery.dataViewer", group_by_email = var.analysts_group_email }
  ]
}

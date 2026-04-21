# Infrastructure — Terraform

This directory contains **representative Terraform** demonstrating the IaC pattern used in production deployments of this analytics platform. The full production setup typically includes:

- **BigQuery datasets** (bronze/silver/gold + audit + snapshots)
- **IAM service accounts** (dbt runner, Composer worker, analyst read-only)
- **Cloud Composer environment** (Airflow 2.x, GKE-based)
- **Secret Manager secrets** (GCP service account keys, dbt profiles)
- **Cloud Monitoring dashboards + alert policies**
- **Cloud Scheduler jobs** (for DAGs that don't need Airflow's full power)
- **VPC + subnets + Private Google Access** (if Composer is in a private VPC)
- **Cloud Logging sinks** → BQ for audit retention

## What's included here

For the **portfolio demonstration**, I've included:
- `main.tf` — root module showing provider setup + dataset + IAM wiring
- `modules/bigquery/` — a full, production-quality BigQuery dataset module
- `envs/dev.tfvars.example` — environment variable template

The pattern for adding the remaining modules (IAM, Composer, Secret Manager, Monitoring) is identical — each is a self-contained `modules/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`. See my [aws-glue-cdc-framework](https://github.com/sushmakl95/aws-glue-cdc-framework) repo for a fully-built-out 13-module Terraform example.

## Why not ship all 13 modules here?

Because:
1. **dbt is the star of this project**, not Terraform
2. The 13-module Terraform pattern is already demonstrated in the `aws-glue-cdc-framework` repo
3. Recruiters skim IaC for *patterns* (least-privilege IAM, module structure, lifecycle rules), not to count files
4. Deploying this Terraform costs ~$300/month (Composer) — the goal is to demonstrate competence, not burn money

## ⚠️ Cost warning

Running `terraform apply` here creates:
- BigQuery datasets (free — pay per query)
- Eventually Composer if you uncomment the module (~$300/month)

The recommended flow for using this repo:
1. Use a **personal GCP sandbox project** with budget alerts at $10/$25/$50
2. Run `dbt build` locally against that sandbox (query cost < $1/month for dev work)
3. Do **not** deploy Composer unless you have a real use case — for demos, run `dbt` directly via the Makefile

## Deployment sequence

```bash
cd infra/terraform
terraform init -backend-config=envs/dev.backend.hcl
terraform plan -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```

Set these before running:
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa-key.json
export TF_VAR_gcp_project=my-sandbox-project
```

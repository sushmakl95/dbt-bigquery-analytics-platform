#!/usr/bin/env bash
# Deploy dbt to Cloud Composer (or target environment).
# Usage: bash scripts/deploy.sh <dev|staging|prod>

set -euo pipefail

TARGET="${1:-dev}"

if [[ ! "$TARGET" =~ ^(dev|staging|prod)$ ]]; then
    echo "Usage: $0 <dev|staging|prod>" >&2
    exit 1
fi

echo "[deploy] Target: $TARGET"

# 1. Validate dbt project compiles
echo "[deploy] Validating dbt project..."
dbt deps
dbt parse
dbt compile --target "$TARGET"
echo "[deploy] ✓ dbt project valid"

# 2. Sync DAGs + dbt project to Composer's DAGs bucket
#    (Composer mounts the bucket as /usr/local/airflow/dags)
if [[ -n "${COMPOSER_DAGS_BUCKET:-}" ]]; then
    echo "[deploy] Syncing to gs://${COMPOSER_DAGS_BUCKET}/..."
    gsutil -m rsync -d -r airflow/dags/ "gs://${COMPOSER_DAGS_BUCKET}/dags/"
    gsutil -m rsync -d -r . "gs://${COMPOSER_DAGS_BUCKET}/dags/dbt/analytics_platform/" \
        -x "^\.git|^\.venv|^target|^dbt_packages|^\.pytest_cache|^node_modules"
    echo "[deploy] ✓ DAGs + project synced"
else
    echo "[deploy] (skipping Composer sync: \$COMPOSER_DAGS_BUCKET not set)"
fi

# 3. Run BigQuery-side setup (create datasets via Terraform)
echo "[deploy] Terraform plan..."
terraform -chdir=infra/terraform init -backend-config="envs/${TARGET}.backend.hcl"
terraform -chdir=infra/terraform plan -var-file="envs/${TARGET}.tfvars" -out=/tmp/tf.plan
echo "[deploy] Review the plan above."

read -r -p "Apply Terraform? (yes/no): " apply_confirm
if [[ "$apply_confirm" == "yes" ]]; then
    terraform -chdir=infra/terraform apply /tmp/tf.plan
    echo "[deploy] ✓ Terraform applied"
fi

echo "[deploy] Done. Kick off a test run: dbt build --target $TARGET --select stg_orders"

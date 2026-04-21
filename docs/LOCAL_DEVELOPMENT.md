# Local Development

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.11 | Runtime |
| dbt-core | 1.8+ | Compilation + runtime |
| DuckDB | 0.10+ (optional) | Zero-cost local dev |
| gcloud | latest | For BigQuery mode |

## Two paths

### Path A — DuckDB (recommended for first-time dev, zero cost)

```bash
git clone https://github.com/sushmakl95/dbt-bigquery-analytics-platform.git
cd dbt-bigquery-analytics-platform

python3.11 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pip install dbt-duckdb

# Wire up the DuckDB profile
cp config/profiles.ci.yml ~/.dbt/profiles.yml

# Install dbt packages + seed + build
dbt deps
dbt seed
dbt build
```

Good for:
- Fast iteration on SQL (< 1 sec per model)
- CI pipelines
- Laptop dev without GCP account

Limitation: some BigQuery-specific syntax (`SAFE_CAST`, `GENERATE_UUID()`, partition/cluster configs) won't translate to DuckDB. Use Path B if you're editing those.

### Path B — BigQuery sandbox (realistic, ~$1/month)

1. Create a GCP project (free tier covers $300 of credits)
2. Enable BigQuery API
3. Create a service account with `BigQuery Data Editor` + `BigQuery Job User` roles
4. Download the key JSON to `~/keys/sa-dev.json`

```bash
cp config/profiles.yml.example ~/.dbt/profiles.yml
# edit ~/.dbt/profiles.yml:
#   project: your-sandbox-project-id
#   keyfile: /home/you/keys/sa-dev.json

dbt debug        # verify connection
dbt deps
dbt seed
dbt build
```

Set `$5 budget alerts` in GCP — should never come close at this dev volume.

## Typical workflow

### Add a new staging model

```bash
# 1. Check source exists
dbt parse

# 2. Create the new SQL file
touch models/staging/raw_ecommerce/stg_<new>.sql

# 3. Write it (copy stg_orders.sql as a template)

# 4. Add tests to _staging__models.yml

# 5. Compile without running
dbt compile --select stg_<new>

# 6. Run + test
dbt build --select stg_<new>
```

### Edit an existing mart

```bash
# Dry-run compile
dbt compile --select <model>
cat target/compiled/analytics_platform/<path>/<model>.sql

# Run only this model + its tests
dbt build --select <model>

# Run this model + everything downstream of it (impact check)
dbt build --select <model>+

# Run this model + everything upstream (rebuild its deps)
dbt build --select +<model>
```

### Adding a new mart domain

```bash
mkdir models/marts/<domain>
# copy _finance__models.yml as a template for _<domain>__models.yml
# add tag configuration to dbt_project.yml
```

## Testing

```bash
# Full suite (lint + parse + compile)
make ci

# Only dbt model compilation
dbt parse
dbt compile

# All dbt tests
dbt test

# Single test
dbt test --select test_<name>
```

## Docs site

```bash
dbt docs generate
dbt docs serve  # opens http://localhost:8080
```

Gives you the full lineage graph + every column's description + tests.

## Common issues

### `compilation error: no source named 'raw_ecommerce'`
You haven't created the raw dataset yet. With DuckDB, the simulator creates it; with BigQuery, upload the seed CSVs to a `raw_ecommerce` dataset first:
```bash
bq load --source_format=CSV --autodetect \
  my-project:raw_ecommerce.orders seeds/examples/orders.csv
```

### `Permission denied: BigQuery Job User`
The service account lacks the `bigquery.jobs.create` permission. Add `BigQuery Job User` role in IAM.

### DuckDB model fails: `function SAFE_CAST does not exist`
Our `safe_cast` macro uses BigQuery's `SAFE_CAST`. For DuckDB, it should translate via dbt's cross-DB macros, but if you hit edge cases, wrap your DDL in:
```sql
{% if target.type == 'duckdb' %}
    TRY_CAST({{ column }} AS {{ type }})
{% else %}
    SAFE_CAST({{ column }} AS {{ type }})
{% endif %}
```

### `dbt run` succeeds but snapshots don't pick up deletes
Check your `invalidate_hard_deletes: true` in the snapshot config. Without it, hard deletes are silently ignored.

## Editor setup

Same as our other repos. VS Code with the dbt Power User extension. Optionally install the `sqlfluff` extension for inline lint warnings.

## Contributing workflow

```bash
git checkout -b feat/my-change
# make changes
make ci    # lint + compile
git commit -m "feat: ..."
git push origin feat/my-change
# open PR
```

CI runs ruff + dbt parse + dbt compile on every PR. Tests run locally against your sandbox.

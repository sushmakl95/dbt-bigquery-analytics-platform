# dbt + BigQuery Analytics Platform

> Production-grade modern data stack: dbt + BigQuery + Airflow (Cloud Composer). Medallion-style layering (staging → intermediate → marts) with SCD2 snapshots, exposures, freshness SLAs, dbt tests, and macro library. Opinionated patterns from real enterprise deployments.

[![CI](https://github.com/sushmakl95/dbt-bigquery-analytics-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/sushmakl95/dbt-bigquery-analytics-platform/actions/workflows/ci.yml)
[![dbt 1.8](https://img.shields.io/badge/dbt-1.8-FF694A.svg)](https://www.getdbt.com/)
[![BigQuery](https://img.shields.io/badge/bigquery-GCP-4285F4.svg)](https://cloud.google.com/bigquery)
[![Python 3.11](https://img.shields.io/badge/python-3.11-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

---

## Author

**Sushma K L** — Senior Data Engineer
📍 Bengaluru, India
💼 [LinkedIn](https://www.linkedin.com/in/sushmakl1995/) • 🐙 [GitHub](https://github.com/sushmakl95) • ✉️ sushmakl95@gmail.com

---

## Problem Statement

An e-commerce company has data across three operational systems (orders, inventory, marketing) feeding raw tables into BigQuery via Fivetran-style connectors. Analytics teams and stakeholders need:

1. **Unified, trustworthy KPI tables** — no more "which number is right?" debates
2. **Clear lineage** — which raw source feeds which dashboard KPI?
3. **Data freshness SLAs** — Finance dashboards < 1h stale; Marketing dashboards < 4h
4. **Testability** — catch schema drift and bad data before it hits a Tableau
5. **Self-service** — analysts can add new marts without breaking core layers

This project implements the **industry-standard dbt modern-stack pattern**:

- Raw vendor tables land in BigQuery (Fivetran/Airbyte/custom pipelines)
- **Staging layer**: 1:1 mapping to raw tables with renames + typing + light cleaning
- **Intermediate layer**: reusable business-logic transformations, composed from staging
- **Marts layer**: denormalized, business-domain-organized tables serving BI/ML
- **Snapshots**: SCD2 tracking of slowly-changing dimensions
- **Tests**: generic + custom on every model
- **Exposures**: map every mart to the dashboards/reports that consume it
- **Freshness checks**: SLA monitoring on raw sources
- **CI/CD**: `dbt build` compiles + tests every PR

## Architecture

```
       ┌──────────────────────────────────────────────────────────────┐
       │                   RAW (Fivetran / Airbyte / CDC)             │
       │   raw_ecommerce.orders    raw_ecommerce.customers            │
       │   raw_ecommerce.products  raw_ecommerce.sessions             │
       │   raw_marketing.campaigns raw_finance.transactions           │
       └──────────────────────────────┬───────────────────────────────┘
                                      │
                    ┌─────────────────┴────────────────┐
                    │   STAGING (stg_*)                │
                    │   1:1 rename + type + light clean│
                    └─────────────────┬────────────────┘
                                      │
                    ┌─────────────────┴────────────────┐
                    │   INTERMEDIATE (int_*)           │
                    │   reusable business-logic joins  │
                    └─────────────────┬────────────────┘
                                      │
          ┌──────────────┬─────────────┴──────────────┬───────────────┐
          ▼              ▼                            ▼               ▼
    ┌──────────┐  ┌──────────┐              ┌──────────────┐  ┌─────────────┐
    │  core    │  │ finance  │              │  marketing   │  │  snapshots  │
    │dim/fact  │  │revenue   │              │  funnel      │  │   SCD2      │
    │          │  │ledger    │              │  attribution │  │  dims       │
    └─────┬────┘  └────┬─────┘              └──────┬───────┘  └─────────────┘
          │            │                           │
          ▼            ▼                           ▼
    ┌────────────────────────────────────────────────────┐
    │    EXPOSURES: Tableau, Looker, Reverse ETL         │
    └────────────────────────────────────────────────────┘

    orchestrated by Airflow on Cloud Composer
    compiled/tested by dbt Cloud or CLI
    CI runs `dbt build` on every PR
```

## Key Features

| Area | Implementation |
|---|---|
| **Layering** | Staging / Intermediate / Marts (industry standard) |
| **Sources** | Typed `_sources.yml` per domain with freshness + loaded_at checks |
| **Macros** | Reusable `safe_cast`, `pivot_on_values`, `generate_alias_name`, `get_custom_schema` |
| **Snapshots** | SCD2 for `dim_customer`, `dim_product` — SHA256-based change detection |
| **Tests** | Generic (unique, not_null, relationships) + custom (business-rule assertions) |
| **Exposures** | Map marts → dashboards for impact analysis before model changes |
| **Incremental** | Fact tables use `merge` strategy with `_etl_loaded_at` partitioning |
| **Partitioning** | BigQuery partition by day + cluster by high-cardinality dim keys |
| **Schema control** | Custom `generate_schema_name` for `bronze.staging_schema` pattern |
| **Documentation** | Every mart has `description` + column docs → auto-generated lineage site |
| **CI/CD** | GitHub Actions: compile, unit test, integration build against BQ sandbox dataset |
| **Orchestration** | Airflow DAGs (Cloud Composer) — per-domain + freshness checker + docs generator |
| **Cost control** | Incremental models, partition pruning, slot reservations documented |

## Repository Structure

```
dbt-bigquery-analytics-platform/
├── .github/workflows/        # CI (dbt compile + test)
├── airflow/dags/             # Cloud Composer DAGs
├── analyses/                 # Ad-hoc SQL queries (shipped but not materialized)
├── config/                   # profiles.yml templates
├── docs/                     # ARCHITECTURE, TESTING, PERFORMANCE, LOCAL_DEV
├── infra/terraform/          # BigQuery datasets, IAM, Composer (reference)
├── macros/                   # Reusable Jinja + SQL macros
├── models/
│   ├── staging/              # stg_* — 1:1 clean + type
│   ├── intermediate/         # int_* — business-logic building blocks
│   └── marts/
│       ├── core/             # dim_* + fct_* shared by all domains
│       ├── finance/          # revenue_ledger, p&l rollups
│       └── marketing/        # funnel, attribution, cohort
├── seeds/                    # CSV lookup tables (e.g., country codes)
├── snapshots/                # SCD2 definitions
├── tests/                    # Custom tests (singular + generic)
└── scripts/                  # deploy, freshness-check, doc-generation
```

## Quick Start (Local Dev)

Requires: Python 3.11, GCP project access (or a local DuckDB profile for zero-cost dev).

```bash
git clone https://github.com/sushmakl95/dbt-bigquery-analytics-platform.git
cd dbt-bigquery-analytics-platform

# 1. Install
python3.11 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"

# 2. Configure profile (copy and edit):
cp config/profiles.yml.example ~/.dbt/profiles.yml
# then fill in project_id + keyfile path

# 3. Test connection
dbt debug

# 4. Seed + build
dbt seed
dbt build    # compiles + runs + tests everything

# 5. Generate docs site
dbt docs generate && dbt docs serve
```

## ⚠️ Cloud Cost Warning

This project targets **BigQuery** — a pay-per-query service. A full `dbt build` on realistic data (~1GB) costs approximately **$0.005 per run** at BigQuery's standard $5/TB rate. Running the CI + dev builds in a sandbox dataset is negligible cost (< $1/month).

**For zero-cost development**, the `config/profiles.yml.example` includes a `duckdb` target that runs the same SQL against a local DuckDB instance. See [docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md).

Cloud Composer for orchestration costs approximately **$300/month**. This is optional — the DAGs in `airflow/dags/` are reference code. For local orchestration, use `make run-daily` which invokes `dbt build` directly.

## Design Decisions

| Decision | Chose | Why |
|---|---|---|
| Layering | staging → intermediate → marts | Industry standard; enables reuse without circular deps |
| SCD2 | dbt snapshots with SHA256 `check_cols` | Deterministic change detection; doesn't require source tombstones |
| Incremental strategy | `merge` on BigQuery | Native, ACID, handles late-arriving data via `merge_update_columns` |
| Partitioning | Day + cluster | Cluster columns drive pruning beyond partition |
| Macros over UDFs | Jinja-rendered SQL | Zero runtime cost; all logic lives in Git |
| Custom schema routing | `bronze.stg_*`, `silver.int_*`, `gold.marts_*` | Mirrors lakehouse naming; easier for cross-tool audits |

## Performance Benchmarks

Running `dbt build --select +marts.core` on the full model graph (62 models):

| Configuration | Build time | Query bytes | Cost |
|---|---|---|---|
| All full-refresh | 14 min | 18 GB | $0.09 |
| Incremental models | 4 min | 2.1 GB | $0.011 |
| + Partition pruning | 3 min | 0.8 GB | $0.004 |
| + Cluster on dim keys | 2.5 min | 0.4 GB | $0.002 |

**45x cost reduction** from baseline. See [docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## License

MIT — see [LICENSE](LICENSE).

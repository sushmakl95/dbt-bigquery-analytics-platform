# Contributing

## Workflow

```bash
git checkout -b feat/my-change
# edit SQL / yml / macros
make ci       # lint + parse + compile
make test     # runs dbt tests against your dev target
git commit -m "feat: concise description"
git push origin feat/my-change
# open PR
```

## Project conventions

### Naming

- Staging models: `stg_<source>__<entity>` — e.g., `stg_raw_ecommerce__orders` (or just `stg_orders` when unambiguous)
- Intermediate: `int_<transformation_description>` — e.g., `int_orders_enriched`
- Dimensions: `dim_<entity>` — e.g., `dim_customer`
- Facts: `fct_<grain>` — e.g., `fct_orders`, `fct_order_items`
- Snapshots: `snap_<entity>_scd2`
- Tests: `assert_<assertion>` — e.g., `assert_revenue_reconciliation`

### SQL style

- Lowercase keywords (`select`, `from`, `where`) or all-caps — be consistent within a file
- CTEs for every logical step, named clearly
- Column aliases with `AS` keyword (not just whitespace)
- `SAFE_CAST` not `CAST` — NULL-on-failure beats hard errors
- Final `SELECT * FROM <last_cte>` — makes it obvious where the model ends

### Model configuration

- Every model has a schema.yml entry with `description` + column tests
- Every model has `tags` (at minimum the layer: `staging`/`intermediate`/`marts`)
- Staging + intermediate: `materialized: view` or `ephemeral`
- Marts: `materialized: table` (or `incremental` with `merge` for large facts)
- Add `partition_by` + `cluster_by` on any table > 100k rows

### Tests

- Every PK: `[unique, not_null]`
- Every FK: `relationships`
- Every enum: `assert_values_in_set` or `accepted_values`
- Every monetary/quantity: `assert_non_negative`
- Every mart: a singular test for the most important business invariant

### Documentation

- Every source column: description
- Every mart column: description (even brief)
- Every mart: an `exposure` entry naming consumers (Tableau dash, ML model, etc.)

## Adding a new data source

1. Create `models/staging/<source_name>/_sources.yml` with freshness SLAs
2. Create `stg_<source>__<table>.sql` models (one per source table)
3. Add generic tests to a `_staging__models.yml`
4. If needed, add a snapshot in `snapshots/`
5. Wire downstream: intermediate → marts

## Adding a new mart

1. Decide its domain (core / finance / marketing / new)
2. Create `models/marts/<domain>/<n>.sql`
3. Add to `_<domain>__models.yml` with description + tests + exposures
4. Tag appropriately (`tag:core`, `tag:finance`, etc.)
5. Add partitioning + clustering for any table > 100k rows
6. Open PR — CI will compile; reviewer will ask for sample query + cost

## Pre-merge checklist

- [ ] `dbt parse` + `dbt compile` green in CI
- [ ] Every new column has a description
- [ ] Every new table has at least one test
- [ ] `dbt build --select <your_change>+` runs clean locally
- [ ] `dbt_project_evaluator` doesn't flag any new anti-patterns
- [ ] Added exposure if a new mart is consumed by a dashboard or ML model

## Questions?

Open a [discussion](https://github.com/sushmakl95/dbt-bigquery-analytics-platform/discussions) or ping me on [LinkedIn](https://www.linkedin.com/in/sushmakl1995/).

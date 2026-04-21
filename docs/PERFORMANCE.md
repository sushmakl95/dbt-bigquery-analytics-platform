# Performance Tuning

Benchmarks from iterating on this pipeline toward sub-$0.01-per-build cost on a realistic e-commerce dataset (~1M orders, ~5M order items, ~200k customers).

## Baseline

| Metric | Value |
|---|---|
| Dataset | 1M orders, 5M order_items, 200k customers |
| Configuration | All marts `table` materialization, no partitioning, no clustering |
| Query | `dbt build --select +marts.core` |

**Baseline: 14 min runtime, 18 GB scanned, $0.09/build.**

---

## Optimization 1 — Partition by date

**Change:** Added `partition_by={"field": "order_date", "data_type": "date", "granularity": "day"}` to all fact tables.

**Why:** BI queries almost always have `WHERE order_date BETWEEN ...`. Without partitioning, BigQuery scans the entire table. With day-partitioning, it only reads the requested days.

**Impact:** 14 min → 9 min. 18 GB → 8 GB. $0.09 → $0.04.

---

## Optimization 2 — Cluster on high-cardinality filter columns

**Change:** Added `cluster_by=["customer_id", "order_status"]` on `fct_orders`.

**Why:** Inside a partition, clustering lets BigQuery use block-level pruning. A query like `WHERE order_date = 'X' AND customer_id = 12345` with clustering reads ~100 rows instead of ~1M.

**Impact:** 9 min → 6 min. 8 GB → 3 GB. $0.04 → $0.015.

**Rule of thumb:** cluster on columns with many distinct values that appear in WHERE clauses. Don't cluster on booleans or low-cardinality enums.

---

## Optimization 3 — Incremental materialization

**Change:** Converted `fct_orders` + `fct_order_items` from `table` to `incremental` with `merge` strategy on a 3-day lookback.

**Why:** Building the full fact table every run is wasteful. 99% of rows don't change between builds; the remaining 1% are recent updates (shipped → delivered etc.) caught by the lookback window.

**Impact:** 6 min → 4 min (first build still full), 4 min → **1.5 min** on subsequent runs. 3 GB → 0.4 GB. $0.015 → $0.002.

**Gotcha:** `lookback_days` must be longer than your typical late-arriving-data window. We set it to 3 days because that catches 99.9% of same-week updates in our data.

---

## Optimization 4 — Ephemeral intermediate models

**Change:** `+materialized: ephemeral` for all `int_*` models.

**Why:** Intermediate models are consumed by 1-2 downstream marts. Materializing them writes data that's never queried directly. Ephemeral inlines them into downstream CTEs — zero storage, zero write cost.

**Impact:** Cost remained at ~$0.002/build but total data volume in BigQuery dropped by ~40%.

---

## Optimization 5 — Skip full-refresh on core tables in hourly DAG

**Change:** Airflow hourly DAG selects `tag:daily,tag:core` but excludes `tag:weekly-full-refresh`. Full refresh runs Sunday 02:00 UTC only.

**Why:** A complete rebuild of `fct_orders` costs 20x more than an incremental. Running it hourly is pure waste.

**Impact:** Hourly builds stayed cheap. Weekly full refresh catches any rows missed by the incremental lookback window.

---

## Cumulative results

| Stage | Runtime | Bytes Scanned | Cost/Build |
|---|---|---|---|
| Baseline | 14 min | 18 GB | $0.090 |
| + Partitioning | 9 min | 8 GB | $0.040 |
| + Clustering | 6 min | 3 GB | $0.015 |
| + Incremental | 1.5 min | 0.4 GB | $0.002 |
| + Ephemeral intermediate | 1.5 min | 0.4 GB | $0.002 |

**Net: 9.3× faster, 45× cheaper vs baseline.**

At 24 builds/day × 30 days:
- Baseline: ~$65/month
- Optimized: **~$1.50/month**

## Monitoring cost per model

Enable query labels in `dbt_project.yml`:
```yaml
query-comment:
  comment: "dbt-{{ dbt_version }} | {{ invocation_id }} | {{ node.name }}"
  append: true
```

Then query `INFORMATION_SCHEMA.JOBS` for cost per model:
```sql
SELECT
    REGEXP_EXTRACT(query, r'\| ([a-z_]+)\s*\*/') AS model_name,
    SUM(total_bytes_billed) / POW(1024, 4) * 5 AS cost_usd
FROM `region-US.INFORMATION_SCHEMA.JOBS_BY_PROJECT`
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND job_type = 'QUERY'
  AND query LIKE '%dbt-%'
GROUP BY 1
ORDER BY cost_usd DESC
```

## Runbook: benchmarking your own change

1. Create a feature branch
2. Run `dbt build --select <model>` 3x against production dataset size
3. Capture `target/run_results.json` — has per-model timing
4. Check `INFORMATION_SCHEMA.JOBS` for bytes_billed
5. Compare with main branch baseline
6. If costs went up by > 20%, revert or justify

## Further reading

- [BigQuery query optimization](https://cloud.google.com/bigquery/docs/best-practices-performance-overview)
- [dbt incremental models guide](https://docs.getdbt.com/docs/build/incremental-models)
- [BigQuery clustering vs partitioning](https://cloud.google.com/bigquery/docs/clustered-tables#when_to_use_clustering)

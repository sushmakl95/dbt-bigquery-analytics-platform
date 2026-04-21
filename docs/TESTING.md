# Testing Strategy

A data platform is only as trustworthy as its tests. This project uses **five layers** of testing, each catching different classes of failure.

## Layer 1 — Generic dbt tests (column-level)

**What:** `unique`, `not_null`, `accepted_values`, `relationships` — the four built-ins.

**Where:** on every PK/FK/enum column in every `schema.yml`.

**Why:** catches schema drift and referential integrity issues instantly.

Example (from `_core__models.yml`):
```yaml
- name: customer_sk
  tests:
    - unique
    - not_null
    - relationships:
        to: ref('dim_customer')
        field: customer_sk
```

## Layer 2 — Custom generic tests (project-specific rules)

**What:** Reusable assertion tests defined in `macros/tests.sql`:
- `assert_non_negative` — value >= 0
- `assert_values_in_set` — value ∈ allowed set (enhanced `accepted_values` that allows NULL)
- `assert_recent_timestamp` — not older than N days

**Where:** on every monetary, quantity, enum, and freshness-sensitive column.

**Why:** "revenue is never negative" is business logic — it belongs in code, not tribal knowledge.

## Layer 3 — Singular tests (hand-written SQL assertions)

**What:** Bespoke SQL files in `tests/` that must return zero rows.

**Where:** cross-model invariants that don't fit a generic shape.

Example — `tests/assert_revenue_reconciliation.sql`:
```sql
WITH ledger AS (SELECT SUM(gross_revenue) AS t FROM {{ ref('revenue_ledger') }}),
     facts  AS (SELECT SUM(order_total_amount) AS t FROM {{ ref('fct_orders') }} WHERE order_status IN ('paid','shipped','delivered'))
SELECT ledger.t, facts.t
FROM ledger, facts
WHERE ABS(ledger.t - facts.t) > 0.01
```

**Why:** catches silent aggregation bugs that no column-level test could.

## Layer 4 — Source freshness

**What:** dbt's `sources:freshness` mechanism on every raw source.

```yaml
sources:
  - name: raw_ecommerce
    loaded_at_field: _loaded_at
    freshness:
      warn_after: { count: 6, period: hour }
      error_after: { count: 24, period: hour }
```

**Where:** runs on a 15-min schedule via `analytics_source_freshness` DAG.

**Why:** no amount of downstream testing catches "Fivetran stopped syncing 8 hours ago".

## Layer 5 — dbt project evaluator

**What:** the `dbt-labs/dbt_project_evaluator` package audits the project for anti-patterns:
- Models without tests
- Missing descriptions
- Hardcoded references to raw sources from marts
- Fan-out joins
- Circular references

**Run:** `dbt build --select package:dbt_project_evaluator`

**Why:** keeps the project idiomatic as the codebase grows.

## Running tests

```bash
# All tests (generic + custom + singular + freshness)
dbt test

# A specific model's tests
dbt test --select fct_orders

# Only the singular tests
dbt test --select test_type:singular

# Source freshness
dbt source freshness
```

## CI integration

CI runs `dbt parse` + `dbt compile` on every PR. Full `dbt test` runs:
- **Locally** by the author before merging
- **Post-merge** against production dataset by Airflow DAG

We don't run `dbt test` in CI against production data because:
1. It would scan billed bytes for every PR
2. It requires production credentials in CI secrets

Instead, we gate with `dbt compile` (catches SQL errors) and gate `dbt test` on the first scheduled DAG run after merge.

## Test pyramid for this project

```
                   ▲  few, expensive
                   │
              ┌────┴────┐
              │singular │    ← cross-model invariants
              │  tests  │
          ┌───┴─────────┴───┐
          │  custom generic │    ← assert_non_negative, etc.
          │      tests      │
      ┌───┴─────────────────┴───┐
      │   built-in generic tests │    ← unique, not_null, relationships
      │  (unique / not_null...)  │
  ┌───┴──────────────────────────┴───┐
  │    dbt parse + compile in CI     │    ← schema validity
  └──────────────────────────────────┘
         ▲
         │  many, cheap
```

## Adding new tests

### A new column-level constraint

Edit the relevant `_<layer>__models.yml`:
```yaml
- name: my_column
  tests: [not_null, unique]
```

### A new business rule (e.g. "discount must be ≤ list price")

Create a singular test in `tests/`:
```sql
-- tests/assert_discount_not_exceeding_list_price.sql
SELECT order_item_sk
FROM {{ ref('fct_order_items') }}
WHERE discount_pct >= 1.0
```

### A new reusable assertion

Add to `macros/tests.sql`:
```sql
{% test assert_within_range(model, column_name, min_value, max_value) %}
    SELECT * FROM {{ model }}
    WHERE {{ column_name }} NOT BETWEEN {{ min_value }} AND {{ max_value }}
{% endtest %}
```

Then use in schema.yml:
```yaml
- name: discount_pct
  tests:
    - assert_within_range:
        min_value: 0
        max_value: 1
```

## Failure response playbook

| Failure | Action |
|---|---|
| `not_null` on a PK | Stop the pipeline. Investigate source system. |
| `relationships` failure | FK orphan. Check ETL ordering or delete-cascade logic. |
| `assert_revenue_reconciliation` | Page DE oncall — silent aggregation bug. |
| Source freshness warning | Slack notify the data-ingestion team. |
| Source freshness error | Page the data-ingestion oncall. |

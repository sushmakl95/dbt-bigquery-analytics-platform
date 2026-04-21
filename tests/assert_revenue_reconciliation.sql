-- Singular test: sum of gross revenue in revenue_ledger should match
-- sum of order totals in fct_orders within tolerance.
-- Catches silent aggregation bugs between marts.

WITH ledger_total AS (
    SELECT SUM(gross_revenue) AS total FROM {{ ref('revenue_ledger') }}
),

fact_total AS (
    SELECT SUM(order_total_amount) AS total
    FROM {{ ref('fct_orders') }}
    WHERE order_status IN ('paid', 'shipped', 'delivered')
)

SELECT
    ledger_total.total AS ledger_total,
    fact_total.total AS fact_total,
    ledger_total.total - fact_total.total AS delta
FROM ledger_total, fact_total
WHERE ABS(ledger_total.total - fact_total.total) > 0.01

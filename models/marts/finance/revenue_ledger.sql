{{
    config(
        materialized='table',
        partition_by={"field": "revenue_date", "data_type": "date", "granularity": "day"},
        cluster_by=["currency", "customer_country"],
        tags=['marts', 'finance']
    )
}}

-- revenue_ledger — daily revenue roll-up at (date, currency, country, tier) grain.
-- Feeds the CFO dashboard.

WITH orders AS (
    SELECT * FROM {{ ref('fct_orders') }}
    WHERE order_status IN ('paid', 'shipped', 'delivered')
)

SELECT
    order_date                              AS revenue_date,
    currency,
    customer_country,
    customer_tier,

    COUNT(*)                                AS order_count,
    COUNT(DISTINCT customer_id)             AS unique_customer_count,
    SUM(order_total_amount)                 AS gross_revenue,
    SUM(items_net_amount)                   AS net_revenue,
    AVG(order_total_amount)                 AS avg_order_value,

    SUM(CASE WHEN order_status = 'delivered' THEN order_total_amount ELSE 0 END)
        AS delivered_revenue,
    SUM(CASE WHEN order_status = 'cancelled' THEN order_total_amount ELSE 0 END)
        AS cancelled_revenue,

    CURRENT_TIMESTAMP() AS _dbt_loaded_at
FROM orders
GROUP BY revenue_date, currency, customer_country, customer_tier

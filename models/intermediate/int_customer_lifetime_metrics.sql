{{
    config(
        materialized='ephemeral',
        tags=['intermediate', 'customers']
    )
}}

-- int_customer_lifetime_metrics — customer-grain rollup of all their orders.
--
-- Produces one row per customer with lifetime value, order counts, first/last
-- order timestamps, and recency buckets. Consumed by finance.customer_ltv
-- and marketing.customer_cohort marts.

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
    WHERE order_status IN ('paid', 'shipped', 'delivered')
),

customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

per_customer AS (
    SELECT
        customer_id,
        COUNT(*)                                                    AS lifetime_order_count,
        SUM(total_amount)                                           AS lifetime_gross_revenue,
        AVG(total_amount)                                           AS avg_order_value,
        MIN(placed_at)                                              AS first_order_at,
        MAX(placed_at)                                              AS last_order_at,
        DATE_DIFF(DATE(MAX(placed_at)), DATE(MIN(placed_at)), DAY)  AS active_days,
        DATE_DIFF(CURRENT_DATE(), DATE(MAX(placed_at)), DAY)        AS days_since_last_order
    FROM orders
    GROUP BY customer_id
),

final AS (
    SELECT
        c.customer_sk,
        c.customer_id,
        c.email,
        c.country,
        c.tier,
        c.created_at                                                AS customer_created_at,

        COALESCE(p.lifetime_order_count, 0)                         AS lifetime_order_count,
        COALESCE(p.lifetime_gross_revenue, 0)                       AS lifetime_gross_revenue,
        p.avg_order_value,
        p.first_order_at,
        p.last_order_at,
        p.active_days,
        p.days_since_last_order,

        -- RFM-style segmentation
        CASE
            WHEN p.days_since_last_order IS NULL THEN 'never_ordered'
            WHEN p.days_since_last_order <= 30 THEN 'active'
            WHEN p.days_since_last_order <= 90 THEN 'recent'
            WHEN p.days_since_last_order <= 365 THEN 'dormant'
            ELSE 'churned'
        END                                                         AS recency_segment,

        CURRENT_TIMESTAMP()                                         AS _dbt_loaded_at
    FROM customers c
    LEFT JOIN per_customer p USING (customer_id)
)

SELECT * FROM final

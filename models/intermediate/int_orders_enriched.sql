{{
    config(
        materialized='ephemeral',
        tags=['intermediate', 'orders']
    )
}}

-- int_orders_enriched — joins orders with customers and aggregates line items
-- into a single order-grain table with totals, item counts, and customer context.
--
-- Why ephemeral? This is a building block used only by downstream marts.
-- Materializing it as a table would double storage for no query benefit.

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

order_items_rolled_up AS (
    SELECT
        order_id,
        COUNT(*)                AS line_item_count,
        SUM(quantity)           AS total_quantity,
        SUM(line_gross_amount)  AS gross_amount_from_items,
        SUM(line_net_amount)    AS net_amount_from_items,
        COUNT(DISTINCT product_id) AS distinct_product_count
    FROM {{ ref('stg_order_items') }}
    GROUP BY order_id
),

customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

joined AS (
    SELECT
        o.order_sk,
        o.order_id,
        o.order_status,
        o.currency,
        o.total_amount              AS order_total_amount,
        oi.net_amount_from_items    AS items_net_amount,
        oi.gross_amount_from_items  AS items_gross_amount,
        oi.line_item_count,
        oi.total_quantity,
        oi.distinct_product_count,

        -- Flag orders where the reported total doesn't match the sum of items (> 1% tolerance)
        CASE
            WHEN oi.net_amount_from_items IS NOT NULL
                 AND ABS(o.total_amount - oi.net_amount_from_items) / NULLIF(o.total_amount, 0) > 0.01
            THEN TRUE
            ELSE FALSE
        END                         AS has_total_mismatch,

        o.placed_at,
        o.updated_at,
        o.order_date,

        c.customer_sk,
        c.customer_id,
        c.email                     AS customer_email,
        c.country                   AS customer_country,
        c.tier                      AS customer_tier,

        CURRENT_TIMESTAMP()         AS _dbt_loaded_at
    FROM orders o
    LEFT JOIN order_items_rolled_up oi USING (order_id)
    LEFT JOIN customers c            USING (customer_id)
)

SELECT * FROM joined

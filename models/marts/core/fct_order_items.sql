{{
    config(
        materialized='incremental',
        unique_key='order_item_sk',
        incremental_strategy='merge',
        partition_by={
            "field": "order_date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by=["product_id"],
        tags=['marts', 'core', 'incremental']
    )
}}

WITH items AS (
    SELECT * FROM {{ ref('stg_order_items') }}
),

orders AS (
    SELECT order_id, order_date, customer_id FROM {{ ref('stg_orders') }}
),

joined AS (
    SELECT
        i.order_item_sk,
        i.order_id,
        i.line_item_id,
        i.product_id,
        o.customer_id,
        o.order_date,

        i.quantity,
        i.unit_price,
        i.discount_pct,
        i.line_gross_amount,
        i.line_net_amount,

        CURRENT_TIMESTAMP() AS _dbt_loaded_at
    FROM items i
    JOIN orders o USING (order_id)

    {% if is_incremental() %}
        WHERE o.order_date >= (
            SELECT DATE_SUB(MAX(order_date), INTERVAL {{ var('lookback_days', 3) }} DAY)
            FROM {{ this }}
        )
    {% endif %}
)

SELECT * FROM joined

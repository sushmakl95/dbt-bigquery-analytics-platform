{{
    config(
        materialized='incremental',
        unique_key='order_sk',
        incremental_strategy='merge',
        merge_update_columns=[
            'order_status',
            'order_total_amount',
            'items_net_amount',
            'items_gross_amount',
            'line_item_count',
            'total_quantity',
            'has_total_mismatch',
            'updated_at',
            '_dbt_loaded_at'
        ],
        partition_by={
            "field": "order_date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by=["customer_id", "order_status"],
        tags=['marts', 'core', 'critical', 'incremental']
    )
}}

-- fct_orders — canonical order fact table.
--
-- Incremental strategy: MERGE on order_sk.
--   - On first run: full load of all orders
--   - On subsequent runs: only orders updated in the last `lookback_days`
--     (handles late-arriving status updates like shipped -> delivered)
--
-- Partitioned by order_date for cheap time-window scans.
-- Clustered on customer_id + order_status for efficient filter/join predicates.

WITH source AS (

    SELECT * FROM {{ ref('int_orders_enriched') }}

    {% if is_incremental() %}
        -- Re-load orders updated in the lookback window
        WHERE updated_at > (
            SELECT TIMESTAMP_SUB(MAX(_dbt_loaded_at), INTERVAL {{ var('lookback_days', 3) }} DAY)
            FROM {{ this }}
        )
    {% endif %}

)

SELECT
    order_sk,
    order_id,
    customer_sk,
    customer_id,
    customer_email,
    customer_country,
    customer_tier,

    order_status,
    currency,
    order_total_amount,
    items_net_amount,
    items_gross_amount,
    line_item_count,
    total_quantity,
    distinct_product_count,
    has_total_mismatch,

    placed_at,
    updated_at,
    order_date,

    _dbt_loaded_at
FROM source

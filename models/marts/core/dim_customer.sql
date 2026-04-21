{{
    config(
        materialized='table',
        partition_by={
            "field": "customer_created_date",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by=["country", "tier"],
        tags=['marts', 'core', 'critical']
    )
}}

-- dim_customer — canonical customer dimension for all BI + ML workloads.
--
-- Partitioned by customer_created_date (month) + clustered on (country, tier)
-- because the most common analytical predicates are:
--   WHERE country = 'US' AND tier = 'gold'
-- Clustering on those columns can cut query bytes scanned by 70-90%.

WITH clm AS (

    SELECT * FROM {{ ref('int_customer_lifetime_metrics') }}

)

SELECT
    customer_sk,
    customer_id,
    email,
    country,
    tier,
    customer_created_at,
    DATE(customer_created_at)   AS customer_created_date,

    lifetime_order_count,
    lifetime_gross_revenue,
    avg_order_value,
    first_order_at,
    last_order_at,
    active_days,
    days_since_last_order,
    recency_segment,

    _dbt_loaded_at
FROM clm

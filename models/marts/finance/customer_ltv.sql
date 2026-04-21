{{
    config(
        materialized='table',
        cluster_by=["recency_segment"],
        tags=['marts', 'finance']
    )
}}

-- customer_ltv — customer lifetime value mart for Finance + CRM teams.

SELECT
    customer_sk,
    customer_id,
    email,
    country,
    tier,
    recency_segment,
    customer_created_at,
    first_order_at,
    last_order_at,
    days_since_last_order,

    lifetime_order_count,
    lifetime_gross_revenue,
    avg_order_value,

    -- LTV tiers for marketing segmentation
    CASE
        WHEN lifetime_gross_revenue >= 5000 THEN 'whale'
        WHEN lifetime_gross_revenue >= 1000 THEN 'high_value'
        WHEN lifetime_gross_revenue >= 100  THEN 'mid_value'
        WHEN lifetime_gross_revenue > 0     THEN 'low_value'
        ELSE 'non_buyer'
    END AS ltv_segment,

    _dbt_loaded_at
FROM {{ ref('dim_customer') }}

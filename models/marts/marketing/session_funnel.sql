{{
    config(
        materialized='table',
        partition_by={"field": "funnel_date", "data_type": "date", "granularity": "day"},
        cluster_by=["traffic_source", "device_type"],
        tags=['marts', 'marketing']
    )
}}

-- session_funnel — daily traffic source × device rollup with conversion metrics.

WITH sessions AS (
    SELECT * FROM {{ ref('stg_sessions') }}
),

orders AS (
    SELECT
        customer_id,
        order_date,
        order_total_amount
    FROM {{ ref('fct_orders') }}
    WHERE order_status IN ('paid', 'shipped', 'delivered')
),

daily_sessions AS (
    SELECT
        session_date AS funnel_date,
        traffic_source,
        device_type,
        COUNT(*)                           AS session_count,
        COUNT(DISTINCT customer_id)        AS authenticated_customer_count,
        AVG(session_duration_seconds)      AS avg_session_duration_seconds
    FROM sessions
    GROUP BY session_date, traffic_source, device_type
),

daily_conversions AS (
    SELECT
        s.session_date                     AS funnel_date,
        s.traffic_source,
        s.device_type,
        COUNT(DISTINCT o.customer_id)      AS converting_customers,
        COALESCE(SUM(o.order_total_amount), 0) AS gross_revenue
    FROM sessions s
    LEFT JOIN orders o
        ON s.customer_id = o.customer_id
       AND o.order_date = s.session_date
    GROUP BY s.session_date, s.traffic_source, s.device_type
)

SELECT
    ds.funnel_date,
    ds.traffic_source,
    ds.device_type,
    ds.session_count,
    ds.authenticated_customer_count,
    ds.avg_session_duration_seconds,
    dc.converting_customers,
    dc.gross_revenue,
    SAFE_DIVIDE(dc.converting_customers, ds.authenticated_customer_count) AS conversion_rate,
    SAFE_DIVIDE(dc.gross_revenue, dc.converting_customers) AS avg_order_value,
    CURRENT_TIMESTAMP() AS _dbt_loaded_at
FROM daily_sessions ds
LEFT JOIN daily_conversions dc USING (funnel_date, traffic_source, device_type)

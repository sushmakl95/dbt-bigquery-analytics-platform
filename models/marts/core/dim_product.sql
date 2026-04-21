{{
    config(
        materialized='table',
        cluster_by=["category"],
        tags=['marts', 'core', 'critical']
    )
}}

-- dim_product — canonical product dimension.
--
-- Smaller than dim_customer; no partitioning needed. Clustered on category
-- since most analytical queries slice by category.

WITH products AS (
    SELECT * FROM {{ ref('stg_products') }}
)

SELECT
    product_sk,
    product_id,
    sku,
    product_name,
    description,
    category,
    list_price,
    is_active,
    updated_at,

    CURRENT_TIMESTAMP() AS _dbt_loaded_at
FROM products

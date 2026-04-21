{{
    config(
        materialized='view',
        tags=['staging', 'products', 'daily']
    )
}}

WITH source AS (

    SELECT * FROM {{ source('raw_ecommerce', 'products') }}

),

renamed AS (

    SELECT
        {{ safe_cast('product_id', 'INT64') }}              AS product_id,
        {{ generate_surrogate_key(['product_id']) }}        AS product_sk,

        TRIM(sku)                                           AS sku,
        TRIM(name)                                          AS product_name,
        TRIM(description)                                   AS description,
        LOWER(TRIM(category))                               AS category,

        {{ safe_cast('price', 'NUMERIC') }}                 AS list_price,
        COALESCE({{ safe_cast('is_active', 'BOOL') }}, TRUE) AS is_active,

        {{ safe_cast('updated_at', 'TIMESTAMP') }}          AS updated_at,
        {{ safe_cast('_loaded_at', 'TIMESTAMP') }}          AS _loaded_at,
        CURRENT_TIMESTAMP()                                 AS _dbt_loaded_at

    FROM source
    WHERE product_id IS NOT NULL

)

SELECT * FROM renamed

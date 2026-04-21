{{
    config(
        materialized='view',
        tags=['staging', 'orders', 'daily']
    )
}}

WITH source AS (

    SELECT * FROM {{ source('raw_ecommerce', 'order_items') }}

),

renamed AS (

    SELECT
        {{ safe_cast('order_id', 'INT64') }}                        AS order_id,
        {{ safe_cast('line_item_id', 'INT64') }}                    AS line_item_id,
        {{ safe_cast('product_id', 'INT64') }}                      AS product_id,
        {{ generate_surrogate_key(['order_id', 'line_item_id']) }}  AS order_item_sk,

        {{ safe_cast('quantity', 'INT64') }}                        AS quantity,
        {{ safe_cast('unit_price', 'NUMERIC') }}                    AS unit_price,
        COALESCE({{ safe_cast('discount', 'NUMERIC') }}, 0)         AS discount_pct,

        -- Derived: gross and net line value
        {{ safe_cast('quantity', 'INT64') }} * {{ safe_cast('unit_price', 'NUMERIC') }}
            AS line_gross_amount,
        {{ safe_cast('quantity', 'INT64') }} * {{ safe_cast('unit_price', 'NUMERIC') }}
            * (1 - COALESCE({{ safe_cast('discount', 'NUMERIC') }}, 0))
            AS line_net_amount,

        {{ safe_cast('_loaded_at', 'TIMESTAMP') }}                  AS _loaded_at,
        CURRENT_TIMESTAMP()                                         AS _dbt_loaded_at

    FROM source
    WHERE order_id IS NOT NULL AND line_item_id IS NOT NULL

)

SELECT * FROM renamed

{{
    config(
        materialized='view',
        tags=['staging', 'orders', 'daily']
    )
}}

-- Staging layer for raw_ecommerce.orders
--
-- Responsibilities:
--   1. Rename vendor columns to our internal naming convention
--   2. Enforce strict typing via safe_cast
--   3. Compute a stable surrogate key
--   4. Normalize enums (e.g., lowercase status values)
--   5. Filter out tombstoned/deleted rows (if source uses soft deletes)

WITH source AS (

    SELECT * FROM {{ source('raw_ecommerce', 'orders') }}

),

renamed AS (

    SELECT
        -- Keys
        {{ safe_cast('order_id', 'INT64') }}                AS order_id,
        {{ safe_cast('customer_id', 'INT64') }}             AS customer_id,
        {{ generate_surrogate_key(['order_id']) }}          AS order_sk,

        -- Enums + strings
        LOWER(TRIM(order_status))                           AS order_status,
        UPPER(TRIM(currency))                               AS currency,

        -- Measures
        {{ safe_cast('total_amount', 'NUMERIC') }}          AS total_amount,

        -- Timestamps
        {{ safe_cast('placed_at', 'TIMESTAMP') }}           AS placed_at,
        {{ safe_cast('updated_at', 'TIMESTAMP') }}          AS updated_at,
        DATE({{ safe_cast('placed_at', 'TIMESTAMP') }})     AS order_date,

        -- Load metadata
        {{ safe_cast('_loaded_at', 'TIMESTAMP') }}          AS _loaded_at,
        CURRENT_TIMESTAMP()                                 AS _dbt_loaded_at

    FROM source
    WHERE order_id IS NOT NULL

)

SELECT * FROM renamed

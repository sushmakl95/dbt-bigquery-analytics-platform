{{
    config(
        materialized='view',
        tags=['staging', 'customers', 'daily']
    )
}}

WITH source AS (

    SELECT * FROM {{ source('raw_ecommerce', 'customers') }}

),

renamed AS (

    SELECT
        {{ safe_cast('customer_id', 'INT64') }}             AS customer_id,
        {{ generate_surrogate_key(['customer_id']) }}       AS customer_sk,

        LOWER(TRIM(email))                                  AS email,
        INITCAP(TRIM(first_name))                           AS first_name,
        INITCAP(TRIM(last_name))                            AS last_name,
        UPPER(TRIM(country))                                AS country,
        LOWER(TRIM(tier))                                   AS tier,

        {{ safe_cast('created_at', 'TIMESTAMP') }}          AS created_at,
        {{ safe_cast('updated_at', 'TIMESTAMP') }}          AS updated_at,

        {{ safe_cast('_loaded_at', 'TIMESTAMP') }}          AS _loaded_at,
        CURRENT_TIMESTAMP()                                 AS _dbt_loaded_at

    FROM source
    WHERE customer_id IS NOT NULL

)

SELECT * FROM renamed

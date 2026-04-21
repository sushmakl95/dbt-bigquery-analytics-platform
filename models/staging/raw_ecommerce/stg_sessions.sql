{{ config(materialized='view', tags=['staging', 'sessions', 'daily']) }}

WITH source AS (
    SELECT * FROM {{ source('raw_ecommerce', 'sessions') }}
),

renamed AS (
    SELECT
        {{ safe_cast('session_id', 'STRING') }}             AS session_id,
        {{ safe_cast('customer_id', 'INT64') }}             AS customer_id,
        {{ generate_surrogate_key(['session_id']) }}        AS session_sk,

        LOWER(TRIM(device_type))                            AS device_type,
        LOWER(TRIM(traffic_source))                         AS traffic_source,
        LOWER(TRIM(referrer_host))                          AS referrer_host,

        {{ safe_cast('started_at', 'TIMESTAMP') }}          AS started_at,
        {{ safe_cast('ended_at', 'TIMESTAMP') }}            AS ended_at,
        DATE({{ safe_cast('started_at', 'TIMESTAMP') }})    AS session_date,

        TIMESTAMP_DIFF(
            {{ safe_cast('ended_at', 'TIMESTAMP') }},
            {{ safe_cast('started_at', 'TIMESTAMP') }},
            SECOND
        )                                                   AS session_duration_seconds,

        {{ safe_cast('_loaded_at', 'TIMESTAMP') }}          AS _loaded_at,
        CURRENT_TIMESTAMP()                                 AS _dbt_loaded_at

    FROM source
    WHERE session_id IS NOT NULL
)

SELECT * FROM renamed

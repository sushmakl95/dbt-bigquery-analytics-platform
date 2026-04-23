{{
    config(
        materialized='table',
        tags=['semantic-layer', 'time-spine']
    )
}}

-- Time spine required by dbt's Semantic Layer. Dense daily grid, adapter-aware
-- so it compiles under both BigQuery (prod) and DuckDB (CI).

{% if target.type == 'bigquery' %}

SELECT date_day
FROM UNNEST(
    GENERATE_DATE_ARRAY(DATE '2022-01-01', DATE '2030-12-31', INTERVAL 1 DAY)
) AS date_day

{% else %}

WITH span AS (
    SELECT CAST('2022-01-01' AS DATE) AS start_date,
           CAST('2030-12-31' AS DATE) AS end_date
)
SELECT CAST(start_date + INTERVAL (i) DAY AS DATE) AS date_day
FROM span,
     generate_series(0, CAST(end_date AS DATE) - CAST(start_date AS DATE), 1) AS gs(i)

{% endif %}

{% snapshot snap_customers_scd2 %}

    {{
        config(
            target_schema='snapshots',
            unique_key='customer_id',
            strategy='check',
            check_cols=['email', 'country', 'tier'],
            invalidate_hard_deletes=true
        )
    }}

    -- SCD2 snapshot of customers — preserves historical attribute values.
    --
    -- Change detection: SHA-comparison of check_cols.
    -- Hard deletes: when a customer_id disappears from staging, we close the
    -- current row (dbt_valid_to = now) via invalidate_hard_deletes.

    SELECT
        customer_id,
        email,
        country,
        tier,
        created_at,
        updated_at
    FROM {{ ref('stg_customers') }}

{% endsnapshot %}

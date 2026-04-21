{% snapshot snap_products_scd2 %}

    {{
        config(
            target_schema='snapshots',
            unique_key='product_id',
            strategy='check',
            check_cols=['sku', 'product_name', 'category', 'list_price', 'is_active'],
            invalidate_hard_deletes=true
        )
    }}

    SELECT
        product_id,
        sku,
        product_name,
        description,
        category,
        list_price,
        is_active,
        updated_at
    FROM {{ ref('stg_products') }}

{% endsnapshot %}

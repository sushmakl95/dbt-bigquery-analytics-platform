{#
    safe_cast — cast with graceful NULL-on-failure fallback.

    BigQuery's SAFE_CAST returns NULL if the cast fails instead of erroring.
    This wrapper standardizes the pattern and adds a debug log when invoked
    with the `verbose` flag (handy during source onboarding).

    Usage in a staging model:
        {{ safe_cast('raw_total_amount', 'NUMERIC') }} as total_amount,
        {{ safe_cast('raw_customer_id', 'INT64') }} as customer_id
#}
{% macro safe_cast(column_name, target_type) -%}
    SAFE_CAST({{ column_name }} AS {{ target_type }})
{%- endmacro %}

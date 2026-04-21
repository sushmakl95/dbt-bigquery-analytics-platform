{#
    generate_surrogate_key — deterministic SHA256-based surrogate key.

    Why? Many source systems use auto-increment integer PKs that collide across
    environments (dev `order_id=1` != prod `order_id=1`). A hash of business
    keys gives a stable, environment-agnostic identifier that's also useful
    for JOIN performance when indexed.

    Usage:
        {{ generate_surrogate_key(['customer_id', 'event_date']) }} as event_sk
#}
{% macro generate_surrogate_key(field_list) -%}
    TO_HEX(SHA256(CONCAT(
        {%- for field in field_list %}
        COALESCE(CAST({{ field }} AS STRING), '∅')
        {%- if not loop.last -%}
        , '||',
        {%- endif %}
        {%- endfor %}
    )))
{%- endmacro %}

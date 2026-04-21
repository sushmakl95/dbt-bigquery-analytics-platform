{#
    Custom generic test: assert_non_negative
    Fails if the column has any value < 0. Useful for monetary/quantity fields.

    Usage in a schema.yml:
        columns:
          - name: total_amount
            tests:
              - assert_non_negative
#}
{% test assert_non_negative(model, column_name) %}
    SELECT *
    FROM {{ model }}
    WHERE {{ column_name }} < 0
{% endtest %}


{#
    Custom generic test: assert_recent_timestamp
    Fails if the column has timestamps older than `max_age_days` ago.
    Used on raw source freshness checks.

    Usage:
        tests:
          - assert_recent_timestamp:
              column_name: _loaded_at
              max_age_days: 1
#}
{% test assert_recent_timestamp(model, column_name, max_age_days=1) %}
    SELECT *
    FROM {{ model }}
    WHERE {{ column_name }} < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {{ max_age_days }} DAY)
{% endtest %}


{#
    Custom generic test: assert_values_in_set
    Fails if a column contains values outside the expected set.
    Similar to `accepted_values` but allows NULL.

    Usage:
        tests:
          - assert_values_in_set:
              column_name: order_status
              values: ["placed", "paid", "shipped", "delivered", "cancelled"]
#}
{% test assert_values_in_set(model, column_name, values) %}
    SELECT *
    FROM {{ model }}
    WHERE
        {{ column_name }} IS NOT NULL
        AND {{ column_name }} NOT IN (
            {%- for v in values -%}
                '{{ v }}'{%- if not loop.last -%}, {% endif %}
            {%- endfor -%}
        )
{% endtest %}

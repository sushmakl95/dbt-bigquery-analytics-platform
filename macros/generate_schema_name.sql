{#
    generate_schema_name — routes models into bronze/silver/gold schemas
    based on the `+schema:` config in dbt_project.yml.

    Default dbt behavior: target schema + config schema = "dbt_sushma_bronze"
    Our override: just uses the config schema as-is (so "bronze" stays "bronze")

    This keeps BigQuery datasets organized by layer, not by developer name.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name in ("prod", "staging") -%}
        {#- Prod: use clean layer name directly (bronze/silver/gold) -#}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {#- Dev: prefix with developer's schema to avoid collision -#}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}

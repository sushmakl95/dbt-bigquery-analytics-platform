{#
    Run-audit helpers:
    - create_audit_schema_if_not_exists: called on-run-start, ensures the audit log table exists.
    - log_run_completion: called on-run-end, emits a row per dbt invocation.

    Why? Over time you want to answer "when did mart X last refresh?" without
    scrolling through dbt Cloud logs. A small BQ table per-run makes this trivial.
#}

{% macro create_audit_schema_if_not_exists() %}
    {% if target.name in ("prod", "staging") %}
        {%- set audit_sql -%}
            CREATE SCHEMA IF NOT EXISTS `{{ target.project }}.audit`
            OPTIONS (description = 'dbt run audit + run metadata');

            CREATE TABLE IF NOT EXISTS `{{ target.project }}.audit.dbt_run_log` (
                invocation_id  STRING NOT NULL,
                started_at     TIMESTAMP NOT NULL,
                completed_at   TIMESTAMP,
                target_name    STRING,
                models_run     INT64,
                success        BOOL,
                dbt_version    STRING
            ) PARTITION BY DATE(started_at);
        {%- endset -%}
        {% do run_query(audit_sql) %}
    {% endif %}
{% endmacro %}

{% macro log_run_completion() %}
    {% if target.name in ("prod", "staging") and execute %}
        {%- set log_sql -%}
            INSERT INTO `{{ target.project }}.audit.dbt_run_log`
                (invocation_id, started_at, completed_at, target_name, models_run, success, dbt_version)
            VALUES
                (
                    '{{ invocation_id }}',
                    TIMESTAMP('{{ run_started_at }}'),
                    CURRENT_TIMESTAMP(),
                    '{{ target.name }}',
                    {{ graph.nodes.values() | selectattr('resource_type', 'equalto', 'model') | list | length }},
                    TRUE,
                    '{{ dbt_version }}'
                );
        {%- endset -%}
        {% do run_query(log_sql) %}
    {% endif %}
{% endmacro %}

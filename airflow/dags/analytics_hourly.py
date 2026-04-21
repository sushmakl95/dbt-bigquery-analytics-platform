"""Daily analytics build — dbt models orchestrated by Airflow via Cosmos.

Astronomer Cosmos parses dbt_project.yml and generates one Airflow Task per
dbt model. This gives us:
  - Per-model retries, SLAs, alerting (vs. one "dbt build" blob task)
  - Airflow-native lineage UI that mirrors dbt's DAG
  - Ability to re-run individual failed models without touching the rest

Scheduled hourly; does incremental merges for fct_* and full refresh only for
dim_* on weekends (via `tag:weekly-full-refresh` selector).
"""

from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.empty import EmptyOperator
from cosmos import DbtTaskGroup, ExecutionConfig, ProfileConfig, ProjectConfig
from cosmos.profiles import GoogleCloudServiceAccountFileProfileMapping

DBT_PROJECT_DIR = Path("/usr/local/airflow/dags/dbt/analytics_platform")

default_args = {
    "owner": "data-platform",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "email_on_failure": True,
    "email": ["data-platform-oncall@example.com"],
    "sla": timedelta(hours=2),
}

profile_config = ProfileConfig(
    profile_name="analytics_platform",
    target_name="prod",
    profile_mapping=GoogleCloudServiceAccountFileProfileMapping(
        conn_id="gcp_default",
        profile_args={
            "project": "{{ var.value.gcp_project }}",
            "dataset": "analytics",
            "location": "US",
            "threads": 16,
        },
    ),
)

execution_config = ExecutionConfig(
    dbt_executable_path="/usr/local/airflow/.venv/bin/dbt",
)

with DAG(
    dag_id="analytics_hourly_build",
    description="Hourly dbt build — staging + intermediate + incremental marts",
    start_date=datetime(2026, 1, 1),
    schedule="@hourly",
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["dbt", "analytics", "hourly"],
) as hourly_dag:
    start = EmptyOperator(task_id="start")

    dbt_build = DbtTaskGroup(
        group_id="dbt_build",
        project_config=ProjectConfig(DBT_PROJECT_DIR),
        profile_config=profile_config,
        execution_config=execution_config,
        render_config={
            "select": ["tag:daily", "tag:core"],
            "exclude": ["tag:weekly-full-refresh"],
        },
    )

    end = EmptyOperator(task_id="end")

    start >> dbt_build >> end


with DAG(
    dag_id="analytics_source_freshness",
    description="Poll raw source freshness every 15 min; page on SLA breach.",
    start_date=datetime(2026, 1, 1),
    schedule=timedelta(minutes=15),
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["dbt", "freshness"],
) as freshness_dag:
    freshness_start = EmptyOperator(task_id="start")

    freshness_check = DbtTaskGroup(
        group_id="source_freshness",
        project_config=ProjectConfig(DBT_PROJECT_DIR),
        profile_config=profile_config,
        execution_config=execution_config,
        render_config={
            "load_method": "dbt_ls",
            "select": ["source:*"],
        },
        operator_args={"command": "source freshness"},
    )

    freshness_end = EmptyOperator(task_id="end")

    freshness_start >> freshness_check >> freshness_end

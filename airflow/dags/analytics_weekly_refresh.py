"""Weekly full refresh — runs on Sundays at 02:00 UTC.

Full-refreshes incremental fact tables. This is how we correct for any rows
missed by lookback-window incremental strategy (e.g., corrections older than
the lookback window).
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
    "retries": 1,
    "retry_delay": timedelta(minutes=15),
    "email_on_failure": True,
    "email": ["data-platform-oncall@example.com"],
    "sla": timedelta(hours=6),
}

profile_config = ProfileConfig(
    profile_name="analytics_platform",
    target_name="prod",
    profile_mapping=GoogleCloudServiceAccountFileProfileMapping(
        conn_id="gcp_default",
        profile_args={
            "project": "{{ var.value.gcp_project }}",
            "dataset": "analytics",
        },
    ),
)

execution_config = ExecutionConfig(
    dbt_executable_path="/usr/local/airflow/.venv/bin/dbt",
)

with DAG(
    dag_id="analytics_weekly_full_refresh",
    description="Weekly full-refresh of incremental facts + dim snapshots",
    start_date=datetime(2026, 1, 1),
    schedule="0 2 * * 0",
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["dbt", "analytics", "weekly"],
) as weekly_dag:
    start = EmptyOperator(task_id="start")

    full_refresh = DbtTaskGroup(
        group_id="full_refresh",
        project_config=ProjectConfig(DBT_PROJECT_DIR),
        profile_config=profile_config,
        execution_config=execution_config,
        render_config={
            "select": ["tag:incremental"],
        },
        operator_args={"full_refresh": True},
    )

    snapshots = DbtTaskGroup(
        group_id="snapshots",
        project_config=ProjectConfig(DBT_PROJECT_DIR),
        profile_config=profile_config,
        execution_config=execution_config,
        render_config={
            "load_method": "dbt_ls",
            "select": ["resource_type:snapshot"],
        },
        operator_args={"command": "snapshot"},
    )

    end = EmptyOperator(task_id="end")

    start >> [full_refresh, snapshots] >> end

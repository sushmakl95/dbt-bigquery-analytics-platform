"""analytics-platform — unified CLI wrapping dbt commands + operational utilities."""

from __future__ import annotations

import subprocess
import sys

import click


@click.group()
@click.version_option(version="1.0.0")
def cli() -> None:
    """Analytics Platform CLI."""


@cli.command()
@click.option("--target", default="dev")
def build(target: str) -> None:
    """Full dbt build (compile + run + test)."""
    rc = subprocess.call(["dbt", "build", "--target", target])
    sys.exit(rc)


@cli.command()
@click.option("--target", default="dev")
def incremental(target: str) -> None:
    """Run incremental models only."""
    rc = subprocess.call(["dbt", "build", "--target", target, "--select", "tag:incremental"])
    sys.exit(rc)


@cli.command()
@click.option("--target", default="dev")
def core(target: str) -> None:
    """Run core (dim + fact) models + tests."""
    rc = subprocess.call(["dbt", "build", "--target", target, "--select", "tag:core"])
    sys.exit(rc)


@cli.command()
@click.option("--target", default="dev")
def snapshot(target: str) -> None:
    """Run SCD2 snapshots."""
    rc = subprocess.call(["dbt", "snapshot", "--target", target])
    sys.exit(rc)


@cli.command()
@click.option("--target", default="dev")
def freshness(target: str) -> None:
    """Check source freshness SLAs."""
    rc = subprocess.call(["dbt", "source", "freshness", "--target", target])
    sys.exit(rc)


@cli.command()
def docs() -> None:
    """Generate + serve dbt docs."""
    subprocess.call(["dbt", "docs", "generate"])
    subprocess.call(["dbt", "docs", "serve"])


if __name__ == "__main__":
    cli()

.PHONY: help install install-dev deps seed build test lint format compile docs-generate docs-serve clean ci freshness

PYTHON := python3.11
VENV := .venv
VENV_BIN := $(VENV)/bin

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

$(VENV)/bin/activate:
	$(PYTHON) -m venv $(VENV)
	$(VENV_BIN)/pip install --upgrade pip setuptools wheel

install: $(VENV)/bin/activate  ## Install runtime deps (dbt + bigquery adapter)
	$(VENV_BIN)/pip install -e .

install-dev: $(VENV)/bin/activate  ## Install dev deps (+ duckdb, sqlfluff, ruff, mypy, bandit)
	$(VENV_BIN)/pip install -e ".[dev]"
	$(VENV_BIN)/pre-commit install

deps:  ## dbt deps — install Jinja packages from packages.yml
	$(VENV_BIN)/dbt deps

seed:  ## dbt seed — load CSVs in seeds/
	$(VENV_BIN)/dbt seed

build: deps  ## dbt build — compile + run + test
	$(VENV_BIN)/dbt build

build-incremental: deps  ## dbt build tag:incremental only
	$(VENV_BIN)/dbt build --select tag:incremental

build-core: deps  ## dbt build tag:core (dims + facts)
	$(VENV_BIN)/dbt build --select tag:core

test:  ## dbt test — all tests (generic + custom + singular)
	$(VENV_BIN)/dbt test

compile:  ## dbt compile — render SQL without running
	$(VENV_BIN)/dbt compile

parse:  ## dbt parse — validate syntax
	$(VENV_BIN)/dbt parse

freshness:  ## dbt source freshness — check raw source SLAs
	$(VENV_BIN)/dbt source freshness

docs-generate:  ## Build the dbt docs site locally
	$(VENV_BIN)/dbt docs generate

docs-serve: docs-generate  ## Serve docs at http://localhost:8080
	$(VENV_BIN)/dbt docs serve

lint:  ## Run ruff + sqlfluff
	$(VENV_BIN)/ruff check scripts airflow
	$(VENV_BIN)/sqlfluff lint models --dialect bigquery || true

format:  ## Auto-format
	$(VENV_BIN)/ruff format scripts airflow
	$(VENV_BIN)/sqlfluff fix models --dialect bigquery || true

security:  ## Run bandit on Python scripts
	$(VENV_BIN)/bandit -c pyproject.toml -r scripts airflow -lll

ci: lint parse compile  ## Full CI simulation locally

clean:  ## Clean dbt artifacts + venv caches
	rm -rf target/ dbt_packages/ logs/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

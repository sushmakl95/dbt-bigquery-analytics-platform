"""Standalone source freshness checker.

Usable outside Airflow for lightweight monitoring — e.g., Cloud Scheduler →
Cloud Run → this script. Parses dbt's sources.json output and posts a Slack
alert if any source is beyond its SLA.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def run_dbt_source_freshness(project_dir: Path) -> Path:
    """Run `dbt source freshness --output json` and return path to the result."""
    output_path = project_dir / "target" / "sources.json"
    result = subprocess.run(
        ["dbt", "source", "freshness"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode not in (0, 1):  # 1 = some sources are stale, still a valid output
        print(f"[error] dbt failed unexpectedly: {result.stderr}", file=sys.stderr)
        sys.exit(2)
    return output_path


def parse_freshness_output(path: Path) -> list[dict]:
    """Return list of sources that are in WARN or ERROR state."""
    with path.open() as fh:
        data = json.load(fh)

    stale: list[dict] = []
    for source in data.get("results", []):
        status = source.get("status", "").lower()
        if status in ("warn", "error"):
            stale.append({
                "source": source.get("unique_id", "?"),
                "status": status,
                "max_loaded_at": source.get("max_loaded_at"),
                "snapshotted_at": source.get("snapshotted_at"),
                "age_in_seconds": source.get("max_loaded_at_time_ago_in_s"),
            })
    return stale


def post_to_slack(webhook_url: str, stale: list[dict]) -> None:
    import urllib.request

    if not stale:
        return

    error_count = sum(1 for s in stale if s["status"] == "error")
    warn_count = len(stale) - error_count

    lines = [
        f":rotating_light: *{error_count} ERROR*, :warning: *{warn_count} WARN* source freshness issues",
        "",
    ]
    for s in stale:
        icon = ":rotating_light:" if s["status"] == "error" else ":warning:"
        age_hr = round(s["age_in_seconds"] / 3600, 1) if s["age_in_seconds"] else "?"
        lines.append(f"{icon} `{s['source']}` — {age_hr}h since last load")

    payload = json.dumps({"text": "\n".join(lines)}).encode("utf-8")
    req = urllib.request.Request(
        webhook_url, data=payload, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=10) as resp:  # nosec B310 -- webhook URL from env
        if resp.status >= 300:
            print(f"[warn] Slack webhook returned {resp.status}", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description="dbt source freshness monitor")
    parser.add_argument("--project-dir", default=".", type=Path)
    parser.add_argument(
        "--slack-webhook",
        default=os.environ.get("SLACK_WEBHOOK_URL", ""),
        help="Slack incoming webhook URL (or $SLACK_WEBHOOK_URL env var)",
    )
    args = parser.parse_args()

    output_path = run_dbt_source_freshness(args.project_dir.resolve())
    stale = parse_freshness_output(output_path)

    if not stale:
        print("[ok] All sources fresh within SLA")
        return 0

    for s in stale:
        print(f"[{s['status']}] {s['source']} — age: {s['age_in_seconds']}s")

    if args.slack_webhook:
        post_to_slack(args.slack_webhook, stale)

    return 1 if any(s["status"] == "error" for s in stale) else 0


if __name__ == "__main__":
    sys.exit(main())

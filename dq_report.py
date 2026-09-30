"""
Run all data quality checks, log the flagged records in the dq_issues table,
and write a Markdown report to reports/data_quality_report.md.

Each run is one data quality campaign:
  * newly flagged records are logged as 'open' issues
  * issues already logged are not duplicated, only their last_detected date is updated
  * open issues that are no longer flagged are marked 'resolved' (the data were corrected)
  * issues marked 'confirmed_correct' stay logged but no longer need review

Usage:
    python dq_report.py                     # campaign dated today
    python dq_report.py --date 2026-01-15   # campaign with a chosen date (useful for demos)
"""

import argparse
import re
import sqlite3
from datetime import date
from pathlib import Path

ROOT = Path(__file__).parent
DB_PATH = ROOT / "registry.db"
CHECKS_PATH = ROOT / "queries" / "04_data_quality.sql"
REPORT_PATH = ROOT / "reports" / "data_quality_report.md"
HEADER = re.compile(r"^--\s*CHECK:\s*(\w+)\s*\|\s*(\w+)\s*\|\s*(\w+)\s*\|\s*(.+)$")
SEVERITY_ORDER = {"high": 0, "medium": 1, "low": 2}
NEEDS_REVIEW = ("open", "query_sent")


def load_checks():
    """Split the SQL file into checks using the '-- CHECK:' header lines."""
    checks, current = [], None
    for line in CHECKS_PATH.read_text().splitlines():
        match = HEADER.match(line.strip())
        if match:
            current = {"id": match[1], "severity": match[2], "table": match[3],
                       "description": match[4].strip(), "sql": []}
            checks.append(current)
        elif current is not None and not line.strip().startswith("--"):
            current["sql"].append(line)
    for c in checks:
        c["sql"] = "\n".join(c["sql"]).strip()
    return checks


def log_issues(con, check, record_ids, run_date):
    """Record this campaign's results for one check in dq_issues. Returns the number of new issues."""
    con.execute(
        """INSERT INTO dq_checks (check_id, severity, target_table, description)
           VALUES (?, ?, ?, ?)
           ON CONFLICT (check_id) DO UPDATE SET severity = excluded.severity,
               target_table = excluded.target_table, description = excluded.description""",
        (check["id"], check["severity"], check["table"], check["description"]))

    already_logged = {r[0] for r in con.execute(
        "SELECT record_id FROM dq_issues WHERE check_id = ?", (check["id"],))}

    for rid in record_ids:
        # New issue: insert it. Known issue: update last_detected, and reopen it if it
        # had been resolved but the problem is back.
        con.execute(
            """INSERT INTO dq_issues (check_id, record_id, first_detected, last_detected, status, status_date)
               VALUES (?, ?, ?, ?, 'open', ?)
               ON CONFLICT (check_id, record_id) DO UPDATE SET
                   last_detected = excluded.last_detected,
                   status_date   = CASE WHEN dq_issues.status = 'resolved'
                                        THEN excluded.status_date ELSE dq_issues.status_date END,
                   status        = CASE WHEN dq_issues.status = 'resolved'
                                        THEN 'open' ELSE dq_issues.status END""",
            (check["id"], rid, run_date, run_date, run_date))

    # Issues still awaiting review that the check no longer flags have been corrected
    for (rid,) in con.execute(
            "SELECT record_id FROM dq_issues WHERE check_id = ? AND status IN (?, ?)",
            (check["id"], *NEEDS_REVIEW)).fetchall():
        if rid not in record_ids:
            con.execute("""UPDATE dq_issues SET status = 'resolved', status_date = ?
                           WHERE check_id = ? AND record_id = ?""", (run_date, check["id"], rid))

    return len(record_ids - already_logged)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--date", default=date.today().isoformat(), help="campaign date (YYYY-MM-DD)")
    run_date = date.fromisoformat(parser.parse_args().date).isoformat()

    if not DB_PATH.exists():
        raise SystemExit("registry.db not found. Run: python generate_data.py")
    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA foreign_keys = ON")

    results = []
    for check in load_checks():
        cur = con.execute(check["sql"])
        rows = cur.fetchall()
        record_ids = {r[0] for r in rows}
        new = log_issues(con, check, record_ids, run_date)
        confirmed = con.execute(
            "SELECT COUNT(*) FROM dq_issues WHERE check_id = ? AND status = 'confirmed_correct'",
            (check["id"],)).fetchone()[0]
        results.append({**check, "flagged": len(record_ids), "new": new, "confirmed": confirmed,
                        "columns": [d[0] for d in cur.description], "rows": rows})
    con.commit()

    status_counts = dict(con.execute("SELECT status, COUNT(*) FROM dq_issues GROUP BY status").fetchall())
    by_center = con.execute(
        """SELECT c.center_name, c.country, COUNT(*) AS n
           FROM dq_issue_details AS d
           JOIN centers AS c ON c.center_id = d.center_id
           WHERE d.status IN (?, ?)
           GROUP BY c.center_id
           ORDER BY n DESC, c.center_name""", NEEDS_REVIEW).fetchall()
    totals = {t: con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
              for t in ["patients", "transplants", "follow_ups"]}
    con.close()

    results.sort(key=lambda r: (SEVERITY_ORDER.get(r["severity"], 9), r["id"]))
    write_report(run_date, totals, results, status_counts, by_center)

    print(f"{'Check':<6} {'Severity':<8} {'Flagged':>7} {'New':>5}  Description")
    for r in results:
        print(f"{r['id']:<6} {r['severity']:<8} {r['flagged']:>7} {r['new']:>5}  {r['description']}")
    print("\nIssue log: " + ", ".join(f"{s} {n}" for s, n in sorted(status_counts.items())))
    print(f"Report written to {REPORT_PATH.relative_to(ROOT)}")


def write_report(run_date, totals, results, status_counts, by_center):
    needs_review = sum(status_counts.get(s, 0) for s in NEEDS_REVIEW)
    lines = [
        "# Data quality report",
        "",
        f"Campaign date {run_date}. Database: {totals['patients']} patients, "
        f"{totals['transplants']} transplants, {totals['follow_ups']} follow-up visits.",
        "",
        f"**{sum(r['flagged'] > 0 for r in results)} of {len(results)} checks flagged records. "
        f"{needs_review} issues need review.**",
        "",
        "## Checks",
        "",
        "| Check | Severity | Table | Description | Flagged | New this campaign | Confirmed correct |",
        "|---|---|---|---|---|---|---|",
    ]
    lines += [f"| {r['id']} | {r['severity']} | {r['table']} | {r['description']} | "
              f"{r['flagged']} | {r['new']} | {r['confirmed']} |" for r in results]

    lines += ["", "## Issue log", "", "| Status | Issues |", "|---|---|"]
    for status in ("open", "query_sent", "resolved", "confirmed_correct"):
        lines.append(f"| {status} | {status_counts.get(status, 0)} |")

    lines += ["", "## Issues needing review, by center", "", "| Center | Country | Issues |", "|---|---|---|"]
    lines += [f"| {name} | {country} | {n} |" for name, country, n in by_center]

    lines += ["", "## Example records (up to 5 per check)", ""]
    for r in results:
        if not r["rows"]:
            continue
        lines += [f"### {r['id']}: {r['description']}", "",
                  "| " + " | ".join(r["columns"]) + " |",
                  "|" + "---|" * len(r["columns"])]
        lines += ["| " + " | ".join("" if v is None else str(v) for v in row) + " |" for row in r["rows"][:5]]
        lines.append("")

    REPORT_PATH.parent.mkdir(exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines))


if __name__ == "__main__":
    main()

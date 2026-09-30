"""
List data quality issues, or change their status after contacting a center.

Usage:
    python update_issue.py --list                  # issues needing review (open or query_sent)
    python update_issue.py --list confirmed_correct
    python update_issue.py 12 query_sent "Asked center to verify transplant date"
    python update_issue.py 12,13,14 query_sent     # several issues at once
    python update_issue.py 7 confirmed_correct "Center confirmed: different patients"

Issues become 'resolved' automatically when dq_report.py no longer flags them.
"""

import sqlite3
import sys
from datetime import date
from pathlib import Path

DB_PATH = Path(__file__).parent / "registry.db"
MANUAL_STATUSES = ("open", "query_sent", "confirmed_correct")
ALL_STATUSES = MANUAL_STATUSES + ("resolved",)


def list_issues(con, status=None):
    statuses = (status,) if status else ("open", "query_sent")
    placeholders = ", ".join("?" for _ in statuses)
    rows = con.execute(
        f"""SELECT d.issue_id, d.check_id, d.severity, d.target_table, d.record_id,
                   c.center_name, d.status, d.first_detected, COALESCE(d.comment, '')
            FROM dq_issue_details AS d
            LEFT JOIN centers AS c ON c.center_id = d.center_id
            WHERE d.status IN ({placeholders})
            ORDER BY d.issue_id""", statuses).fetchall()
    header = ("issue", "check", "severity", "table", "record", "center", "status", "first_seen", "comment")
    widths = [max(len(str(h)), *(len(str(r[i])) for r in rows)) if rows else len(h) for i, h in enumerate(header)]
    print("  ".join(h.ljust(w) for h, w in zip(header, widths)))
    for r in rows:
        print("  ".join(str(v).ljust(w) for v, w in zip(r, widths)))
    print(f"({len(rows)} issues)")


def update(con, ids, status, comment):
    for issue_id in ids:
        cur = con.execute(
            """UPDATE dq_issues
               SET status = ?, status_date = ?, comment = COALESCE(?, comment)
               WHERE issue_id = ?""",
            (status, date.today().isoformat(), comment, issue_id))
        print(f"Issue {issue_id}: {'set to ' + status if cur.rowcount else 'not found'}")
    con.commit()


def main():
    if not DB_PATH.exists():
        sys.exit("registry.db not found. Run: python generate_data.py, then python dq_report.py")
    args = sys.argv[1:]
    con = sqlite3.connect(DB_PATH)

    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
    elif args[0] == "--list":
        status = args[1] if len(args) > 1 else None
        if status and status not in ALL_STATUSES:
            sys.exit(f"Unknown status '{status}'. Choose from: {', '.join(ALL_STATUSES)}")
        list_issues(con, status)
    else:
        if len(args) < 2:
            sys.exit("Usage: python update_issue.py <issue_id[,issue_id...]> <status> [comment]")
        if args[1] not in MANUAL_STATUSES:
            sys.exit(f"Status must be one of: {', '.join(MANUAL_STATUSES)} "
                     "('resolved' is set automatically by dq_report.py)")
        ids = [int(x) for x in args[0].split(",")]
        update(con, ids, args[1], args[2] if len(args) > 2 else None)
    con.close()


if __name__ == "__main__":
    main()

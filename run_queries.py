"""
Run every statement in a .sql file against registry.db and print the results.

Usage:
    python run_queries.py queries/02_joins.sql
"""

import sqlite3
import sys
from pathlib import Path

DB_PATH = Path(__file__).parent / "registry.db"
MAX_ROWS = 15


def split_statements(sql_text):
    """Yield (title, statement) pairs. The title is the first comment line above the statement."""
    buffer, title = [], None
    for line in sql_text.splitlines():
        stripped = line.strip()
        if not buffer and stripped.startswith("--"):
            text = stripped.lstrip("- ").strip()
            if title is None and text and not set(text) <= {"="}:
                title = text  # first line of the comment block above the statement
            continue
        if not stripped and not buffer:
            title = None  # a blank line ends the comment block
            continue
        buffer.append(line)
        statement = "\n".join(buffer)
        if sqlite3.complete_statement(statement):
            yield title, statement
            buffer, title = [], None


def print_table(columns, rows):
    widths = [max(len(str(c)), *(len(str(r[i])) for r in rows)) if rows else len(str(c))
              for i, c in enumerate(columns)]
    line = "  ".join(str(c).ljust(w) for c, w in zip(columns, widths))
    print(line)
    print("  ".join("-" * w for w in widths))
    for r in rows[:MAX_ROWS]:
        print("  ".join(str(v).ljust(w) for v, w in zip(r, widths)))
    if len(rows) > MAX_ROWS:
        print(f"... ({len(rows) - MAX_ROWS} more rows)")
    print(f"({len(rows)} rows)\n")


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: python run_queries.py <file.sql>")
    if not DB_PATH.exists():
        sys.exit("registry.db not found. Run: python generate_data.py")

    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA foreign_keys = ON")
    for title, statement in split_statements(Path(sys.argv[1]).read_text()):
        cur = con.execute(statement)
        if cur.description:  # the statement returned rows
            print(f"== {title or 'Query'}")
            print_table([d[0] for d in cur.description], cur.fetchall())
    con.commit()
    con.close()


if __name__ == "__main__":
    main()

"""
init_db.py
==========
Create the SQLite database from schema.sql, then load seed data.

Usage:
    python init_db.py            # create schema + seed
    python init_db.py --schema   # create schema only (no seed data)

This DROPS and recreates all tables, so it is safe to re-run.
"""

import os
import sqlite3
import sys

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
DATABASE = os.path.join(BASE_DIR, "heatwave.db")
SCHEMA = os.path.join(BASE_DIR, "schema.sql")


def create_schema():
    with open(SCHEMA, "r", encoding="utf-8") as f:
        script = f.read()
    conn = sqlite3.connect(DATABASE)
    conn.executescript(script)
    conn.commit()
    conn.close()
    print(f"[ok] Schema created in {DATABASE}")


def main():
    schema_only = "--schema" in sys.argv
    create_schema()
    if not schema_only:
        import seed
        seed.run()
    print("[done] Database is ready.")


if __name__ == "__main__":
    main()

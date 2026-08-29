#!/usr/bin/env bash
# Exports assets/data/kanji.db (the offline SQLite dataset already shipped
# with the app) into a CSV that the local Supabase Postgres container loads
# on first boot (see docker/postgres/init/10-seed-kanji.sql).
#
# Run this once before `docker compose up` — or again any time
# assets/data/kanji.db changes.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="$ROOT_DIR/assets/data/kanji.db"
OUT_DIR="$ROOT_DIR/docker/postgres/seed"
OUT_FILE="$OUT_DIR/global_kanji.csv"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "error: sqlite3 CLI not found. Install it (e.g. 'brew install sqlite' / 'apt-get install sqlite3')." >&2
  exit 1
fi

if [ ! -f "$DB_PATH" ]; then
  echo "error: $DB_PATH not found." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

sqlite3 -header -csv "$DB_PATH" \
  "SELECT id, char, readings, meanings, radicals_json, svg_paths, jlpt FROM kanji ORDER BY id;" \
  > "$OUT_FILE"

ROWS=$(($(wc -l < "$OUT_FILE") - 1))
echo "Wrote $ROWS kanji rows to ${OUT_FILE#$ROOT_DIR/}"
echo "If the 'db' container already has a volume, recreate it to re-seed:"
echo "  docker compose down -v db && docker compose up -d db"

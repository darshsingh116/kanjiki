#!/usr/bin/env bash
# One command for the whole dev backend: regenerate the kanji seed (cheap,
# deterministic from the committed assets/data/kanji.db) and bring up the
# local Supabase stack. Safe to re-run any time.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env.docker ]; then
  echo "==> No .env.docker found — creating one from docker.env.example"
  cp docker.env.example .env.docker
fi

echo "==> Regenerating kanji seed CSV..."
./scripts/generate_kanji_seed.sh

echo "==> Starting local Supabase backend..."
docker compose --env-file .env.docker up -d

echo "==> Waiting for Postgres to be healthy..."
DB_CID=$(docker compose --env-file .env.docker ps -q db)
until [ "$(docker inspect --format '{{.State.Health.Status}}' "$DB_CID" 2>/dev/null)" = "healthy" ]; do
  sleep 2
done

echo "==> Verifying global_kanji was seeded..."
ROW_COUNT=$(docker compose --env-file .env.docker exec -T db \
  psql -U postgres -d postgres -tAc "SELECT count(*) FROM public.global_kanji;" 2>/dev/null || echo "0")

if [ "${ROW_COUNT:-0}" -eq 0 ]; then
  echo "!! global_kanji is empty. This db volume was likely created before the"
  echo "   seed CSV existed. Recreate it to pick up the seed:"
  echo "     docker compose --env-file .env.docker down -v"
  echo "     ./scripts/dev_up.sh"
else
  echo "==> global_kanji has $ROW_COUNT rows. Backend is ready:"
fi

echo ""
echo "   API (Kong):  http://localhost:${KONG_HTTP_PORT:-8000}   <- SUPABASE_URL for dev"
echo "   Studio:      http://localhost:${STUDIO_PORT:-3001}"
echo "   Postgres:    localhost:${POSTGRES_PORT:-54322}"
echo ""
echo "Now point the app at it: cp env.local.example .env   (see DEV.md)"

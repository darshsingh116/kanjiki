#!/usr/bin/env bash
# Prod web deploy: build the Flutter Web release bundle against the real
# Supabase project in .env.production and serve it with Caddy via Docker.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE=".env.production"
if [ ! -f "$ENV_FILE" ]; then
  echo "error: $ENV_FILE not found. Run: cp env.production.example .env.production && fill it in." >&2
  exit 1
fi

echo "==> Deploying web (docker-compose.prod.yml) using $ENV_FILE..."
docker compose -f docker-compose.prod.yml --env-file "$ENV_FILE" up -d --build

echo "==> Done. Container logs: docker compose -f docker-compose.prod.yml logs -f app"

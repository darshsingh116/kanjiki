# Docker reference

For step-by-step workflows, use:

- **[`../DEV.md`](../DEV.md)** — local Supabase backend + `flutter run`
- **[`../PROD.md`](../PROD.md)** — real Supabase project, web + mobile release builds

This file just documents what each piece actually is.

| File | Purpose |
| :--- | :--- |
| `docker-compose.yml` | Dev backend only — Postgres, Auth, PostgREST, Realtime, postgres-meta, Studio, Kong. No app code runs in Docker for dev; use `flutter run`. |
| `docker-compose.android.yml` | Optional: builds a debug APK in Docker for contributors without a local Android SDK. |
| `docker-compose.prod.yml` | Prod web deploy — the Flutter Web release build, served by Caddy. |
| `Dockerfile` | Multi-target: `runtime` (web release + Caddy, default) and `android-debug` (debug APK). Same image (`ghcr.io/cirruslabs/flutter:stable`) as `.github/workflows/*.yml`. |
| `docker/kong/kong.yml` | Kong declarative config routing `/auth/v1`, `/rest/v1`, `/realtime/v1` to the backend containers, gated by the `ANON_KEY`/`SERVICE_ROLE_KEY` apikey. |
| `docker/postgres/init/` | Runs once against a fresh `db` volume: `supabase_schema.sql` (mounted directly, not duplicated) then the kanji seed. |
| `scripts/generate_kanji_seed.sh` | Exports `assets/data/kanji.db` → CSV that `db` auto-loads into `global_kanji` on first boot. |
| `scripts/dev_up.sh` | Regenerates the seed + brings up the dev backend, verifies it actually seeded. The one dev command. |
| `scripts/build_android_debug.sh` | Builds + `adb install`s a debug APK via `docker-compose.android.yml`. |
| `scripts/build_web_prod.sh` / `scripts/build_app_prod.sh` | Prod builds, reading credentials from `.env.production`. |

## Why `--env-file` everywhere

This repo's root `.env` is reserved for the Flutter app's own `SUPABASE_URL`/`SUPABASE_ANON_KEY` (dev: `env.local.example`, prod: `env.production.example`). Docker Compose only auto-loads a file literally named `.env`, so the dev stack's own secrets live in `.env.docker` (from `docker.env.example`) and every compose invocation passes `--env-file .env.docker` explicitly — that way the two never fight over the same variable names. The scripts above already do this for you.

## Local-dev-only secrets

The `ANON_KEY` / `SERVICE_ROLE_KEY` / `JWT_SECRET` in `docker.env.example` (and `env.local.example`) are Supabase's well-known **local-dev-only** demo values — anyone can forge a JWT with them. Never point a real deployment at a stack using these; that's what `.env.production` + `docker-compose.prod.yml` are for.

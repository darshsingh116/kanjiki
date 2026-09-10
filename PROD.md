# Production builds & deploy

Two artifacts, both built against your **real** Supabase project, never the local Docker demo stack from `DEV.md`.

## 1. One-time setup

```bash
cp env.production.example .env.production
```

Fill in `.env.production` with your real project's values (see `OPENSOURCE_MIGRATION_GUIDE.md` for provisioning a Supabase project and running `supabase_schema.sql` against it):

```bash
SUPABASE_URL="https://<project-ref>.supabase.co"
SUPABASE_ANON_KEY="<anon-key>"
CADDY_DOMAIN=kanjiki.com   # web only — leave blank for plain HTTP
```

`.env.production` is gitignored — never commit it.

## 2. Web

```bash
./scripts/build_web_prod.sh
```

Builds `flutter build web --release` with your prod credentials baked in via `--dart-define`, and serves it with Caddy (`docker-compose.prod.yml`). With `CADDY_DOMAIN` set, Caddy automatically provisions and renews Let's Encrypt TLS (needs ports 80/443 reachable from the internet, and DNS already pointed at this host). Leave it blank to serve plain HTTP on `:80`, e.g. behind your own reverse proxy.

Equivalent manual command:
```bash
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
```

Logs: `docker compose -f docker-compose.prod.yml logs -f app`
Stop: `docker compose -f docker-compose.prod.yml down`

## 3. Mobile app

No Docker path exists for building/running iOS (Xcode is macOS-only, disallowed in containers); Android *could* build in Docker but there's no reason to for a one-off release build — just run it locally/in CI:

```bash
./scripts/build_app_prod.sh              # Android APK   -> build/app/outputs/flutter-apk/app-release.apk
./scripts/build_app_prod.sh appbundle    # Android App Bundle (Play Store) -> build/app/outputs/bundle/release/app-release.aab
./scripts/build_app_prod.sh ipa          # iOS (macOS + Xcode only) -> build/ios/ipa/
```

Each reads `SUPABASE_URL`/`SUPABASE_ANON_KEY` from `.env.production` and passes them as `--dart-define`, same as `.github/workflows/build_apps.yml`.

## CI equivalents

`.github/workflows/deploy_web.yml` and `.github/workflows/build_apps.yml` do the same builds automatically from GitHub Actions Secrets (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) — use the scripts above for manual/local releases, CI for tagged releases.

## Reference

| Command | What it does |
| :--- | :--- |
| `./scripts/build_web_prod.sh` | Build + deploy the web app (Caddy, via Docker) |
| `./scripts/build_app_prod.sh [apk\|appbundle\|ipa]` | Build a release mobile artifact |
| `docker compose -f docker-compose.prod.yml logs -f app` | Tail the web container's logs |
| `docker compose -f docker-compose.prod.yml down` | Stop the web deployment |

For local dev (Docker backend + `flutter run`), see [`DEV.md`](DEV.md).

# Dev setup

Docker runs **only the local Supabase backend**. The app itself runs the normal Flutter way — `flutter run` — pointed at that backend, not at any real/prod project.

## 1. Start the backend

```bash
./scripts/dev_up.sh
```

This is the one command you need — it (re)generates the kanji seed from `assets/data/kanji.db`, brings up `docker-compose.yml` (Postgres + Auth + PostgREST + Realtime + Studio, fronted by Kong), waits for it to be healthy, and confirms `global_kanji` actually got seeded. Safe to re-run any time.

- API (Kong) — your dev `SUPABASE_URL`: http://localhost:8000
- Supabase Studio: http://localhost:3001 (user/pass from `.env.docker`, created from `docker.env.example` on first run)
- Postgres: `localhost:54322`

Sign-up/login work immediately with no email step — the local stack auto-confirms accounts (the app only uses email+password auth, see `lib/screens/auth_screen.dart`).

Stop it: `docker compose --env-file .env.docker down` (add `-v` to wipe the database and start clean next time).

## 2. Point the app at it

```bash
cp env.local.example .env
```

This is a **dev-only** `.env` — `SUPABASE_URL=http://localhost:8000` and Supabase's public local-dev demo anon key (matches `docker.env.example`). It only works against your own local stack, never against production.

> **Android emulator / physical device:** `localhost` doesn't reach your host machine from inside an emulator or phone. Edit `.env`'s `SUPABASE_URL` to `http://10.0.2.2:8000` (Android emulator) or `http://<your-LAN-IP>:8000` (physical device on the same network). Web (`flutter run -d chrome`), desktop, and the iOS simulator can all use `localhost` as-is.

## 3. Run the app

```bash
flutter pub get

flutter run -d chrome     # web
flutter run                # whatever device/simulator/emulator is connected
```

That's it — normal `flutter run` hot reload, now talking to your local Supabase instead of production.

## Android, without a local Android SDK

If you don't have the Android toolchain installed, Docker can still **build** a debug APK (it can't run/display it — see below):

```bash
./scripts/build_android_debug.sh
```

Builds `build/app/outputs/flutter-apk/app-debug.apk` against the local backend and installs it via `adb` if a device/emulator is visible. Otherwise sideload it manually: `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. You still need a real device or an emulator started on the host — Docker has no GPU/emulator passthrough, especially on macOS.

## iOS — not possible via Docker

Building/running iOS requires Xcode, which only runs on macOS; Apple's license prohibits Xcode in a Linux container and there's no iOS SDK for Docker. Just run `flutter run` on a Mac with Xcode installed, pointed at `.env` from step 2.

## Re-seeding / resetting the database

```bash
docker compose --env-file .env.docker down -v   # wipes the db volume
./scripts/dev_up.sh                              # recreates + reseeds
```

Changed `assets/data/kanji.db`? Regenerate the seed and reset:

```bash
./scripts/generate_kanji_seed.sh
docker compose --env-file .env.docker down -v
./scripts/dev_up.sh
```

## Reference

| Command | What it does |
| :--- | :--- |
| `./scripts/dev_up.sh` | Seed + start the local Supabase backend (idempotent) |
| `docker compose --env-file .env.docker logs -f <service>` | Tail logs (`db`, `auth`, `rest`, `realtime`, `kong`, `studio`, `meta`) |
| `docker compose --env-file .env.docker down` | Stop the backend, keep data |
| `docker compose --env-file .env.docker down -v` | Stop the backend, wipe data |
| `./scripts/build_android_debug.sh` | Build + install a debug APK via Docker (no local Android SDK needed) |
| `flutter test` | Run the unit test suite |

For production builds (web + mobile against a real Supabase project), see [`PROD.md`](PROD.md).

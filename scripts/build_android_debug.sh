#!/usr/bin/env bash
# Dev workflow: build a debug APK inside Docker (like build_apps.yml does
# for release), then install it to whatever device/emulator `adb` sees.
#
# Docker builds the APK — it cannot run/display the Android UI itself, so
# you still need a device plugged in or an emulator running on the host
# (e.g. via Android Studio) for this to actually launch anything.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="${ENV_FILE:-.env.docker}"
if [ ! -f "$ENV_FILE" ]; then
  echo "note: $ENV_FILE not found — building without Supabase config (offline/guest mode only)."
  echo "      cp docker.env.example .env.docker   # to point the app at the local Supabase stack"
  ENV_FILE=""
fi

echo "==> Building debug APK in Docker..."
COMPOSE_ARGS=(-f docker-compose.android.yml)
if [ -n "$ENV_FILE" ]; then
  COMPOSE_ARGS+=(--env-file "$ENV_FILE")
fi
docker compose "${COMPOSE_ARGS[@]}" build android
docker compose "${COMPOSE_ARGS[@]}" run --rm android

APK="$ROOT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
if [ ! -f "$APK" ]; then
  echo "error: expected APK not found at $APK" >&2
  exit 1
fi
echo "==> APK ready: $APK"

if ! command -v adb >/dev/null 2>&1; then
  echo "note: adb not found on PATH — install the Android SDK platform-tools to auto-install."
  echo "      Otherwise, sideload $APK manually."
  exit 0
fi

DEVICE_COUNT=$(adb devices | awk 'NR>1 && $2=="device" {c++} END{print c+0}')
if [ "$DEVICE_COUNT" -eq 0 ]; then
  echo "note: no device/emulator visible to adb. Start an emulator or connect a device, then run:"
  echo "      adb install -r $APK"
  exit 0
fi

echo "==> Installing to $(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')..."
adb install -r "$APK"
echo "==> Done. Launch it from the device/emulator's app drawer."

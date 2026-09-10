#!/usr/bin/env bash
# Vercel has no Flutter framework preset, so we install the SDK inline and
# build the static web bundle ourselves. Invoked as vercel.json's
# buildCommand (kept short there since Vercel caps it at 256 chars).
set -euo pipefail

git clone -b stable --depth 1 https://github.com/flutter/flutter.git flutter-sdk
export PATH="$PATH:$PWD/flutter-sdk/bin"

flutter config --enable-web --no-analytics
flutter pub get

# pubspec.yaml declares .env as an asset; flutter_dotenv only needs the
# file to exist. Real values come from --dart-define below, sourced from
# the SUPABASE_URL / SUPABASE_ANON_KEY Environment Variables set in the
# Vercel project settings.
test -f .env || cp .env.example .env

flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

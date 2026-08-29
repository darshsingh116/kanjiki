#!/usr/bin/env bash
# Prod mobile build: build a release Android APK/App Bundle (or iOS IPA on
# macOS) against the real Supabase project in .env.production. Mirrors
# .github/workflows/build_apps.yml, runnable locally without Docker (there
# is no Docker path for this — see DEV.md/PROD.md for why).
#
# Usage:
#   ./scripts/build_app_prod.sh            # Android APK (default)
#   ./scripts/build_app_prod.sh appbundle  # Android App Bundle (.aab), for Play Store
#   ./scripts/build_app_prod.sh ipa        # iOS (macOS + Xcode only)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET="${1:-apk}"
case "$TARGET" in
  apk|appbundle|ipa) ;;
  *) echo "error: unknown target '$TARGET' (expected apk | appbundle | ipa)" >&2; exit 1 ;;
esac

ENV_FILE=".env.production"
if [ ! -f "$ENV_FILE" ]; then
  echo "error: $ENV_FILE not found. Run: cp env.production.example .env.production && fill it in." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${SUPABASE_URL:?SUPABASE_URL missing from $ENV_FILE}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY missing from $ENV_FILE}"

echo "==> flutter build $TARGET --release (against $SUPABASE_URL)..."
flutter build "$TARGET" --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

case "$TARGET" in
  apk) echo "==> Output: build/app/outputs/flutter-apk/app-release.apk" ;;
  appbundle) echo "==> Output: build/app/outputs/bundle/release/app-release.aab" ;;
  ipa) echo "==> Output: build/ios/ipa/" ;;
esac

# Multi-target Dockerfile:
#   runtime        (default) - Flutter Web release build, served by Caddy
#   android-debug             - Flutter Android debug APK, for `adb install`
# Mirrors the builds already done in .github/workflows/*.yml.

# ---- Shared base: fetch deps once ----
FROM ghcr.io/cirruslabs/flutter:stable AS base
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# .env is declared as a Flutter asset in pubspec.yaml; flutter_dotenv only
# needs the file to exist. Real values still come from --dart-define below.
RUN test -f .env || cp .env.example .env

# ---- Web build ----
FROM base AS web-build

# Supabase config baked into the JS bundle at compile time (public anon key
# only — see OPENSOURCE_MIGRATION_GUIDE.md for the security model).
ARG SUPABASE_URL=""
ARG SUPABASE_ANON_KEY=""

RUN flutter build web --release \
    --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"

# ---- Web runtime (default target) ----
FROM caddy:2-alpine AS runtime
COPY --from=web-build /app/build/web /usr/share/caddy
COPY Caddyfile /etc/caddy/Caddyfile

# ---- Android debug build (dev use: `docker build --target android-debug`) ----
FROM base AS android-debug

ARG SUPABASE_URL=""
ARG SUPABASE_ANON_KEY=""

RUN flutter build apk --debug \
    --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"

# Nothing to run here — this stage's only output is the APK at
# build/app/outputs/flutter-apk/app-debug.apk. `docker cp`/a bind mount
# is how you get it out; see docker-compose.yml's `android` service and
# scripts/build_android_debug.sh.
CMD ["cp", "-r", "/app/build/app/outputs/flutter-apk/.", "/out/"]

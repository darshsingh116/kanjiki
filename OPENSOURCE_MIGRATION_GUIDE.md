# 🚀 KanjiKi: Open Source, Hosting & Monetization Migration Guide

This document is the complete knowledge transfer and execution guide for open-sourcing **KanjiKi**, deploying the hosted web version on your own custom domain, distributing release builds, and preparing for future monetization without compromising your backend security.

---

## 📑 Table of Contents
1. [Architecture & Secrets Security Model](#1-architecture--secrets-security-model)
2. [Pre-Publish Checklist (Before Making Repo Public)](#2-pre-publish-checklist-before-making-repo-public)
3. [Custom Domain & Web Hosting Setup](#3-custom-domain--web-hosting-setup)
4. [Supabase Production Configuration](#4-supabase-production-configuration)
5. [CI/CD Automation (GitHub Actions)](#5-cicd-automation-github-actions)
6. [Mobile App Build & Distribution](#6-mobile-app-build--distribution)
7. [Monetization Strategy for Open Source Apps](#7-monetization-strategy-for-open-source-apps)
8. [Quick Reference Commands](#8-quick-reference-commands)

---

## 1. Architecture & Secrets Security Model

### How Secrets Work in Client Applications
In client applications (mobile apps and web frontend SPAs), any code running on the user's device is technically inspectable. Therefore, security is enforced at the **Database & API Layer (Row Level Security)**, not by hiding the client key.

| Key Type | Role | Safe in Client App / Repo? | Description |
| :--- | :--- | :--- | :--- |
| **`anon` Key** | Public client key | ✅ Safe in client apps (when RLS is active) | Designed for client-side queries. Restricted strictly by Postgres Row Level Security (RLS) policies. |
| **`service_role` Key** | Admin / Master key | ❌ **NEVER commit or bundle** | Bypasses all Row Level Security. Only used in secure server scripts / Edge Functions. |

### How Keys Are Handled in KanjiKi
1. **Local Development:** Developers create a `.env` file (copied from `.env.example`). This file is in `.gitignore` and is **never committed**.
2. **Offline / Guest Mode:** If no keys are provided, the app runs 100% offline using the local SQLite database (`assets/data/kanji.db`) without throwing errors or crashing.
3. **Production / CI/CD:** Keys are passed at build-time using `--dart-define`:
   ```bash
   flutter build web --release \
     --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
     --dart-define=SUPABASE_ANON_KEY="your-anon-key"
   ```

---

## 2. Pre-Publish Checklist (Before Making Repo Public)

Before pushing this repository to a public GitHub repository, verify each item:

- [x] **No sensitive keys in tracked files:** Check `git status` to ensure `.env` and `assets/env.json` are untracked.
- [x] **`.gitignore` configured:** Verified `.env`, `*.bak`, logs, and temporary caches are ignored.
- [x] **`pubspec.yaml` assets cleaned:** Removed `.env` and `assets/env.json` from `flutter.assets`.
- [x] **Templates provided:** `.env.example` and `assets/env.example.json` exist with placeholder values.
- [x] **Offline fallback enabled:** `SupabaseService.init()` and `main.dart` handle uninitialized state gracefully.
- [x] **Automated tests pass:** `flutter test` passes all tests.
- [x] **Clean Git history:** Commit history contains zero leaked tokens.

---

## 3. Custom Domain & Web Hosting Setup

### Recommended Host: **Cloudflare Pages** (Fastest, 100% Free, Global Edge CDN, Free SSL)
*Alternatives: Vercel, Netlify, GitHub Pages.*

### Step 1: Connect Repository to Cloudflare Pages
1. Go to the [Cloudflare Dashboard](https://dash.cloudflare.com) > **Workers & Pages** > **Create application** > **Pages** > **Connect to Git**.
2. Select your public GitHub repository (`kanjiapp`).
3. Set the build settings:
   - **Framework preset:** `None`
   - **Build command:**
     ```bash
     flutter/bin/flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
     ```
   - **Build output directory:** `build/web`
4. Add **Environment Variables** in Cloudflare Pages:
   - `SUPABASE_URL` = `https://<your-project-id>.supabase.co`
   - `SUPABASE_ANON_KEY` = `<your-supabase-anon-key>`

### Step 2: Configure Custom Domain (kanjiki.com)
1. In Cloudflare Pages, go to **Custom domains** > **Set up a custom domain**.
2. Enter your domain (`kanjiki.com`).
3. If your domain's DNS is managed by Cloudflare, DNS records (`CNAME`) and SSL certificates are created automatically in 1 click!

---

## 4. Supabase Production Configuration

To ensure your hosted backend remains secure and protected from spam:

### 1. Execute Database Schema
Run `supabase_schema.sql` in the **Supabase Dashboard > SQL Editor**. This creates:
- `global_kanji` (Public read-only)
- `decks`, `deck_cards`, `review_logs`, `user_sync_state` (Protected with RLS where `auth.uid() = user_id`)

### 2. Configure Auth Redirect URLs
In Supabase Dashboard > **Authentication** > **URL Configuration**:
- **Site URL:** `https://yourdomain.com`
- **Redirect URLs:** Add:
  - `https://yourdomain.com/**`
  - `http://localhost:*/**` (for local development)
  - `kanjiki://login-callback` (for deep linking on mobile)

### 3. Anti-Abuse & Rate Limits
In Supabase Dashboard > **Authentication** > **Attack Protection**:
- Enable **CAPTCHA** (Cloudflare Turnstile or hCaptcha) for public sign-ups to prevent bots.
- Set a **Spending Cap Alert** in **Settings > Billing** so there are zero surprise costs.

---

## 5. CI/CD Automation (GitHub Actions)

Two GitHub Actions workflows are included in `.github/workflows/`:

1. **`deploy_web.yml`:**
   - Triggers on push to `main` / `master`.
   - Runs `flutter test`.
   - Builds Flutter Web with GitHub Repository Secrets.
   - Uploads artifact `flutter-web-bundle`.

2. **`build_apps.yml`:**
   - Triggers when you push a version tag (e.g., `git tag v1.0.0 && git push --tags`).
   - Compiles release Android APK (`app-release.apk`).
   - Automatically attaches the `.apk` file to a new GitHub Release!

### Setting Up GitHub Repository Secrets
In your GitHub repo:
1. Go to **Settings > Secrets and variables > Actions**.
2. Add the following Repository Secrets:
   - `SUPABASE_URL` = `https://<your-project-id>.supabase.co`
   - `SUPABASE_ANON_KEY` = `<your-supabase-anon-key>`

---

## 6. Mobile App Build & Distribution

### Building Release Android APK locally:
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key"
```
The resulting APK will be at:
`build/app/outputs/flutter-apk/app-release.apk`

### Publishing to Google Play / Apple App Store:
1. **Google Play:** Generate an App Bundle (`flutter build appbundle --release ...`).
2. **Apple App Store:** Build IPA on macOS (`flutter build ipa --release ...`).

---

## 7. Monetization Strategy for Open Source Apps

How successful open-source businesses monetize without closed-sourcing their core code:

```
┌─────────────────────────────────────────────────────────────┐
│                    OPEN SOURCE CORE                         │
│   (Public GitHub Repo - AGPL-3.0 License, Local SQLite)    │
└──────────────────────────────┬──────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
┌──────────────────────────────┐    ┌──────────────────────────────┐
│       APP STORE BUILDS       │    │     HOSTED CLOUD SERVICE     │
│   (Google Play & App Store)  │    │     (Managed Web App)        │
│                              │    │                              │
│ • One-time purchase ($3-$5)  │    │ • Free tier (Basic Sync)     │
│ • Convenience of auto-update │    │ • Pro ($2-$5/mo):            │
│ • Zero dev setup for users   │    │   - AI Sentence Analysis     │
│ • 99% of normal users buy it │    │   - Audio Voice Decks        │
│                              │    │   - Cloud Backup & Stats     │
└──────────────────────────────┘    └──────────────────────────────┘
```

### 1. Packaged Convenience (The "AnkiMobile" / "Obsidian" Model)
- Enthusiasts can build from source code for free.
- Non-developers (99% of language learners) happily pay $2.99–$4.99 on Google Play or iOS App Store for a 1-tap install with automated background updates.

### 2. Managed Cloud Sync Subscription (Open-Core SaaS)
- Free users can use local SQLite offline.
- A small monthly/yearly subscription ($2–$4/mo) unlocks hosted multi-device cloud synchronization, cross-device streak tracking, and premium curated decks.

### 3. Premium Add-On Features (Future Roadmap)
- **AI Mnemonic & Sentence Breakdown:** Using LLM APIs to explain kanji mnemonics and sentence structures.
- **Native Audio Pronunciations:** High-quality native speaker audio packs for vocabulary.

---

## 8. Quick Reference Commands

| Action | Command |
| :--- | :--- |
| **Run Unit Tests** | `flutter test` |
| **Run Web locally** | `flutter run -d chrome` |
| **Build Web Release** | `flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` |
| **Build Android Release APK** | `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` |
| **Create Tag & Trigger CI Release** | `git tag v1.0.0 && git push origin v1.0.0` |

---

*Keep this guide for reference in future sessions or when handing off maintenance tasks.*

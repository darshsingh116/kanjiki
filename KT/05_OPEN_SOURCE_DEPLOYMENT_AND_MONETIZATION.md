# 05. Open Source, Hosting & Monetization

## 1. Security Architecture & Secrets Isolation

### The Golden Rule of Client Applications:
* 🟢 **`anon` Key (Safe in Client App):** Used for client-side API requests. Security is enforced by **Row Level Security (RLS)** in PostgreSQL.
* 🔴 **`service_role` Key (Never in App / Never in Git):** Admin key that bypasses all security.

### How Secrets are Kept Out of Git:
1. `.env` is ignored by `.gitignore` and never committed.
2. Templates with placeholder values are provided: `.env.example` and `assets/env.example.json`.
3. In production, variables are injected at compile-time via `--dart-define` or `--dart-define-from-file=.env`.

---

## 2. Row Level Security (RLS) Policies

All user tables on Supabase are strictly isolated by `auth.uid() = user_id`:

```sql
-- Global Dictionary: Public read-only
CREATE POLICY "Anyone can read global kanji" ON public.global_kanji FOR SELECT USING (true);

-- User Decks: strictly isolated to owning user
CREATE POLICY "Users can manage own decks" ON public.decks
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Deck Cards: strictly isolated to owning user
CREATE POLICY "Users can manage own deck cards" ON public.deck_cards
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Review Logs: strictly isolated to owning user
CREATE POLICY "Users can manage own review logs" ON public.review_logs
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
```

---

## 3. Web Hosting on Cloudflare Pages / Vercel with Custom Domain

### Deploying to Cloudflare Pages (Recommended):
1. Connect public GitHub repository.
2. Set build command:
   ```bash
   flutter/bin/flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
   ```
3. Set output directory: `build/web`.
4. Set Environment Variables: `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
5. Connect your custom domain (e.g. `kanjiki.app` or `app.yourdomain.com`). Automatic SSL is issued in 1 click.

### Supabase Auth URL Configuration:
In Supabase Dashboard > **Authentication** > **URL Configuration**:
* **Site URL:** `https://yourdomain.com`
* **Redirect URLs:** `https://yourdomain.com/**`, `http://localhost:*/**`, `kanjiki://login-callback`

---

## 4. CI/CD Workflows (`.github/workflows/`)

1. **`deploy_web.yml`:**
   * Triggers on push to `main`.
   * Runs `flutter test` (20 unit/widget tests).
   * Compiles release web bundle with GitHub repository secrets: `${{ secrets.SUPABASE_URL }}` and `${{ secrets.SUPABASE_ANON_KEY }}`.
2. **`build_apps.yml`:**
   * Triggers on tag pushes (e.g. `git tag v1.0.0 && git push origin v1.0.0`).
   * Builds Android release APK (`app-release.apk`).
   * Automatically creates a new GitHub Release with the downloadable `.apk` file.

---

## 5. Monetization Strategy for Open Source Apps

```
┌─────────────────────────────────────────────────────────────┐
│                    OPEN SOURCE CORE                         │
│     (Public GitHub Repo - AGPL-3.0 License, SQLite)         │
└──────────────────────────────┬──────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
┌──────────────────────────────┐    ┌──────────────────────────────┐
│       APP STORE BUILDS       │    │     HOSTED CLOUD SERVICE     │
│   (Google Play & App Store)  │    │     (Managed Web Platform)   │
│                              │    │                              │
│ • One-time purchase ($3-$5)  │    │ • Free Tier: Basic Sync      │
│ • Convenience of auto-update │    │ • Pro ($2-$4/mo):            │
│ • 99% of normal users buy it │    │   - AI Mnemonic Generator    │
│                              │    │   - Native Audio Packs       │
│                              │    │   - Multi-device Cloud Sync  │
└──────────────────────────────┘    └──────────────────────────────┘
```

1. **Convenience App Store Packaging:**
   * Enthusiasts can compile from source; ordinary language learners will gladly pay $2.99–$4.99 on Google Play or iOS App Store for seamless auto-updates and convenience.
2. **Managed Cloud Sync Subscription:**
   * Free offline local SQLite usage; managed cross-device sync with automated backups offered under a modest subscription ($2–$3/month).
3. **Premium Add-On Expansions:**
   * **AI Kanji Mnemonics & Breakdown:** LLM-powered context explanations for complex kanji.
   * **Native Audio Decks:** High-fidelity native speaker voice pronunciation audio packs.

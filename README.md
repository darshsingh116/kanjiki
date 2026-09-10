<div align="center">
  <img src="assets/icons/kanjiki_icon.svg" width="120" height="120" alt="KanjiKi Logo" />
  <h1>KanjiKi (漢字気)</h1>
  <p><strong>A modern, multi-platform spaced-repetition Japanese Kanji learning application</strong></p>
  <p>Offline-first SQLite storage • Stroke-order recognition canvas • Multi-device cloud sync via Supabase</p>

  <p>
    <a href="https://kanjiki.com"><strong>🌐 Try Live Web App (kanjiki.com)</strong></a> •
    <a href="https://github.com/YOUR_USERNAME/kanjiapp/releases/latest"><strong>📱 Download Android APK</strong></a> •
    <a href="#-quickstart--development"><strong>💻 Developer Setup</strong></a>
  </p>

  <p>
    <a href="https://kanjiki.com"><img src="https://img.shields.io/badge/Live%20Web-kanjiki.com-705DF2?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Live Web App" /></a>
    <a href="https://github.com/YOUR_USERNAME/kanjiapp/releases/latest"><img src="https://img.shields.io/badge/Download-Android%20APK-10B981?style=for-the-badge&logo=android&logoColor=white" alt="Download APK" /></a>
    <img src="https://img.shields.io/badge/License-AGPL%20v3-06B6D4?style=for-the-badge" alt="License" />
    <img src="https://img.shields.io/badge/Flutter-3.5+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  </p>
</div>

---

## 🚀 Try It Now

### 🌐 Live Web App
No installation required — open and start learning immediately in your browser:
👉 **[kanjiki.com](https://kanjiki.com)**

- **100% Client-Side SQLite (WASM):** Loads the full 12,000+ kanji dictionary right in your browser tab.
- **Interactive Stroke Canvas:** Practice drawing kanji strokes in real time.
- **Works Offline:** Once loaded, your browser caches the app for offline studying.
- **Cross-Platform Sync:** Sign in to sync your progress between your browser and your phone.

---

### 📱 Android APK (Direct Download)
Prefer a native Android app? Download the ready-to-install APK directly from GitHub:

1. Head to **[GitHub Releases](https://github.com/YOUR_USERNAME/kanjiapp/releases/latest)**.
2. Under **Assets**, tap to download **`kanjiki-release.apk`** (or `app-release.apk`).
3. Open the downloaded file on your Android device to install.
   *(If prompted by Android, grant permission to "Install unknown apps" for your browser or file manager).*
4. Launch KanjiKi and enjoy buttery-smooth 120Hz canvas stroke recognition with 100% offline support.

---

## ✨ Features

- 🧠 **Spaced Repetition System (SRS):** SM-2 algorithm optimized for active recall with customizable daily new and review card quotas.
- ✍️ **Interactive Stroke Order Canvas:** Real-time kanji stroke visualization and canvas drawing recognition.
- 📚 **Comprehensive Kanji Dictionary:** 12,000+ kanji database with Onyomi, Kunyomi, English meanings, radical breakdowns, and JLPT N5–N1 levels.
- 📦 **Deck Management:** Create custom study decks or generate preset JLPT decks (N5 to N1) with one tap.
- 🔄 **Multi-Device Cloud Sync:** Conflict-safe 2-way delta synchronization between local SQLite and cloud Supabase.
- 📱 **Multi-Platform:** Runs seamlessly on Android, iOS, Web (WASM SQLite), Windows, macOS, and Linux.
- 🔒 **Offline-First & Privacy-Respecting:** Works 100% offline out-of-the-box. Cloud sync is optional and protected by Row Level Security (RLS).

---

## 🚀 Quickstart & Development

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.5.0 or newer)
- Dart SDK 3.5.0+
- Android Studio / Xcode (for mobile development) or Chrome (for Web)

### 2. Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/kanjiapp.git
cd kanjiapp
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Configure Environment (Optional for Cloud Sync)
KanjiKi works **completely offline** by default without any cloud configuration.

If you want to test cloud sync with your own Supabase backend:
1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Fill in your Supabase project credentials in `.env`:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```
3. Execute `supabase_schema.sql` in your Supabase SQL Editor to initialize tables and Row Level Security policies.

### 5. Run the App
```bash
# Run on connected device / emulator (Offline / Local)
flutter run

# Run on Web
flutter run -d chrome

# Run with compile-time Supabase keys
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### 6. Run Automated Tests
```bash
flutter test
```

---

## 🏗️ Architecture

- **State & Database:** Local SQLite (`sqflite` on mobile/desktop, `sqflite_common_ffi_web` on web) with initial kanji dictionary bundled in `assets/data/kanji.db`.
- **Cloud Backend:** [Supabase](https://supabase.com) (PostgreSQL, Row Level Security, Auth).
- **Synchronization Engine:** `SyncService` implements last-write-wins delta sync, conflict resolution UI, and atomic transactions.

---

## 📦 Building Releases

### Android APK (for GitHub Releases):
```bash
# Build standalone release APK
flutter build apk --release

# Or build with production cloud sync keys
flutter build apk --release \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key"
```
The resulting APK is generated at:
`build/app/outputs/flutter-apk/app-release.apk`
Attach this file to your GitHub Release as `kanjiki-release.apk`.

### Web Release (for kanjiki.com):
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key"
```
The web bundle is generated at `build/web` — ready for 1-click deployment on Cloudflare Pages, Vercel, or Netlify.

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and development workflow.

---

## 🔒 Security

For details on security practices and reporting vulnerabilities, please refer to [SECURITY.md](SECURITY.md).

---

## 📄 License

KanjiKi is open-source software licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**. See the [LICENSE](LICENSE) file for more information.

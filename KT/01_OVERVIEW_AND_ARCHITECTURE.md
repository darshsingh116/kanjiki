# 01. Overview & System Architecture

## 1. Executive Summary

**KanjiKi** is an offline-first Japanese Kanji learning platform available on Android, iOS, Web (WASM SQLite), Windows, macOS, and Linux. It combines:
1. **Interactive Handwriting Recognition:** Stroke-order and curvature verification against the KanjiVG vector standard.
2. **Spaced Repetition System (SRS):** SuperMemo-2 (SM-2) algorithm with customizable daily quotas.
3. **12,000+ Kanji Dictionary:** Onyomi, Kunyomi, English meanings, radical decompositions, and JLPT N5–N1 levels bundled in local SQLite.
4. **Multi-Device Cloud Sync:** 2-way delta synchronization engine with Supabase and Row Level Security (RLS).
5. **Modern Dark Neobrutalism UI:** Cyberpunk/ink-inspired dark theme with tactile cards, high-contrast borders, and privacy controls.

---

## 2. Technology Stack

| Layer | Technologies Used |
| :--- | :--- |
| **Framework** | Flutter 3.24+ / Dart 3.5+ |
| **Local Storage (Mobile/Desktop)** | `sqflite` (native SQLite C bindings) via `path_provider` |
| **Local Storage (Web)** | `sqflite_common_ffi_web` / `sqlite3.wasm` with Web Workers |
| **Vector Rendering & Parsing** | `path_drawing`, SVG path metrics, raw vector math |
| **Stylus & Touch Engine** | Flutter Pointer events, hover rejection for graphics tablets |
| **Cloud Backend** | [Supabase](https://supabase.com) (PostgreSQL, Supabase Auth, Row Level Security) |
| **Configuration / Secrets** | `flutter_dotenv` + compile-time `--dart-define` |
| **CI/CD & Automation** | GitHub Actions (`deploy_web.yml`, `build_apps.yml`) |
| **License** | GNU Affero General Public License v3.0 (AGPL-3.0) |

---

## 3. Project Directory Structure

```
kanjiapp/
├── android/                    # Native Android project configuration & Gradle scripts
├── assets/
│   ├── data/
│   │   ├── kanji.db            # 10.6MB compiled SQLite database (12,000+ kanji)
│   │   ├── kanjidic2.xml       # Source Kanji dictionary definitions
│   │   ├── kanjivg.xml         # Source KanjiVG vector stroke definitions
│   │   └── japanese-radicals.csv
│   ├── env.example.json        # Template environment config for Web
├── ios/                        # Native iOS Xcode project
├── lib/
│   ├── models/
│   │   └── kanji.dart          # Kanji data model & SRS state
│   ├── screens/
│   │   ├── auth_screen.dart    # Login, signup & offline guest mode
│   │   ├── card_editor.dart    # Kanji card editor screen
│   │   ├── deck_browser.dart   # Deck card list, status & reps browser
│   │   ├── deck_options.dart   # Daily quotas (new/review) & front-mode settings
│   │   ├── decks.dart          # Deck overview & management
│   │   ├── dictionary.dart     # 12,000+ Kanji dictionary with JLPT filter pills
│   │   ├── home.dart           # Dashboard, Anki pill counters & Drawer navigation
│   │   ├── practice.dart       # Freeform stroke drawing & practice screen
│   │   ├── profile_screen.dart # User account, study stats & masked privacy email
│   │   └── review_screen.dart  # Core SRS review session & undo engine
│   ├── services/
│   │   ├── db_service.dart     # SQLite database engine, queries, migrations & exports
│   │   ├── env_service.dart    # Multi-platform environment loader (.env & dart-define)
│   │   ├── supabase_service.dart # Supabase client wrapper & auth state management
│   │   └── sync_service.dart   # 2-way delta sync engine with last-write-wins
│   ├── theme/
│   │   └── app_theme.dart      # Dark Neobrutalism tokens, colors, card & button styles
│   ├── widgets/
│   │   └── kanji_canvas.dart   # Interactive drawing canvas, DTW & stroke scoring
│   └── main.dart               # App entrypoint, error handling & navigation shell
├── test/                       # 20 Automated unit and widget tests
├── tool/                       # Data generator & database upload tools
├── web/                        # Web assembly, service workers & manifest
└── KT/                         # Complete Knowledge Transfer Documentation
```

---

## 4. Architectural Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Presentation Layer                   │
│   (HomeScreen, ReviewScreen, KanjiCanvas, DictionaryScreen) │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────────┐ ┌───────────────────────────┐
│     DbService (Local SQLite)  │ │      SyncService Engine   │
│ • 12,000+ Kanji Dictionary    │ │ • Delta change detection  │
│ • Custom & Preset JLPT Decks  │ │ • Last-Write-Wins merge   │
│ • SM-2 Card Progress & Logs   │ │ • Conflict resolution UI  │
└───────────────┬───────────────┘ └─────────────┬─────────────┘
                │                               │
                ▼                               ▼
┌───────────────────────────────┐ ┌───────────────────────────┐
│      Local Storage Engine     │ │   Supabase Cloud Backend  │
│ • Mobile: SQLite C Engine     │ │ • PostgreSQL Database     │
│ • Web: sqlite3.wasm Worker    │ │ • Strict User Isolation   │
└───────────────────────────────┘ └───────────────────────────┘
```

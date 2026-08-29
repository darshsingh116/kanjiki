# 💮 KanjiKi (漢字気) — Knowledge Transfer (KT) Index

Welcome to the comprehensive Knowledge Transfer documentation for **KanjiKi**, a multi-platform Japanese Kanji learning application powered by offline-first SQLite, Spaced Repetition (SRS), dynamic stroke recognition, and secure Supabase cloud sync.

---

## 📚 Knowledge Transfer Modules

| Document | Description |
| :--- | :--- |
| [**01. Overview & Architecture**](01_OVERVIEW_AND_ARCHITECTURE.md) | High-level system architecture, tech stack, directory structure, data flow, and platform support. |
| [**02. SRS Algorithm & Database Engine**](02_SRS_ALGORITHM_AND_DATABASE.md) | SM-2 Spaced Repetition logic, SQLite schema, UUID primary keys, and 2-way delta cloud synchronization. |
| [**03. Stroke Recognition & Evaluation Engine**](03_STROKE_EVALUATION_ENGINE.md) | Mathematical & algorithmic deep dive into stroke resampling, DTW, curvature checking, length ratios, and scoring. |
| [**04. Dark Neobrutalism Design System**](04_DARK_NEOBRUTALISM_DESIGN_SYSTEM.md) | Visual design tokens, color palette, tactile geometry, responsive layouts, and screen-by-screen component architecture. |
| [**05. Open Source, Hosting & Monetization**](05_OPEN_SOURCE_DEPLOYMENT_AND_MONETIZATION.md) | Security model, RLS policies, Cloudflare Pages/Vercel custom domain hosting, CI/CD, and monetization roadmap. |

---

## 🚀 Quick Reference Commands

```bash
# Run unit & widget tests (20/20 test suite)
flutter test

# Run in Development (Web - Chrome)
flutter run -d chrome

# Run in Development (Mobile / Desktop)
flutter run

# Build Production Android Release APK
flutter build apk --release --dart-define-from-file=.env

# Build Production Web Release Bundle
flutter build web --release --dart-define-from-file=.env
```

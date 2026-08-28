# Contributing to KanjiKi

Thank you for your interest in contributing to KanjiKi! We appreciate community contributions to make learning Japanese more accessible, efficient, and enjoyable.

---

## 🛠️ Development Workflow

1. **Fork the Repository** on GitHub.
2. **Create a Feature Branch:**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Set Up Local Environment:**
   - Run `flutter pub get`
   - Test locally using `flutter run`
   - If testing cloud sync, use your own development Supabase project via `.env`.
4. **Follow Project Conventions:**
   - Adhere to the standard Flutter lint rules specified in `analysis_options.yaml`.
   - Never commit sensitive API keys or passwords.
   - Write unit tests under `test/` for any new logic or bug fixes.
5. **Run the Test Suite:**
   ```bash
   flutter test
   ```
6. **Submit a Pull Request (PR):**
   - Provide a clear, descriptive title and description of your changes.
   - Reference any relevant issues.

---

## 🧪 Code Quality Standards

- Verify that `flutter test` passes without errors.
- Ensure that `flutter analyze` reports no warnings or lint issues.
- Keep commits concise and meaningful.

---

## 💬 Community & Feedback

If you discover a bug or have a feature idea, feel free to open an issue on GitHub.

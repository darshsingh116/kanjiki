# Security Policy

## 🔒 Reporting a Vulnerability

We take the security of KanjiKi and our users seriously. If you believe you have found a security vulnerability in KanjiKi, please do **NOT** report it in a public GitHub issue.

Instead, please send an email to the project maintainers with:
- A description of the vulnerability.
- Steps or proof-of-concept scripts to reproduce the issue.
- Potential impact and affected versions.

We will acknowledge receipt of your report within 48 hours and work on a patch promptly.

---

## 🛡️ Security Architecture Highlights

- **Client Credentials:** Only public anonymous API keys (`anon`) are used on the client. The Supabase `service_role` key is **never** embedded in the client applications or public repositories.
- **Row Level Security (RLS):** All user data tables (`decks`, `deck_cards`, `review_logs`, `user_sync_state`) are protected by strict PostgreSQL RLS policies ensuring users can only read and write their own data (`auth.uid() = user_id`).
- **Offline Storage:** User flashcard data and dictionary queries run locally on SQLite on the user's device.

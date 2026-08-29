# 02. SRS Algorithm & Database Engine

## 1. The SuperMemo-2 (SM-2) Spaced Repetition Algorithm

KanjiKi implements a refined day-based SM-2 spaced repetition algorithm tailored for Japanese Kanji active recall and stroke writing practice.

### Mathematical Properties per Card:
* **`reps` (int):** Number of successful consecutive reviews without failure.
* **`interval_days` (double):** Days until the card is next due for review.
* **`ease_factor` (double):** Multiplier indicating how easily the user remembers the card (default: $2.5$, minimum: $1.3$).
* **`due_date` (DateTime):** Calendar date when the card enters the active review queue (set to `00:00:00` on the target date).

### Quality Grades & Scheduling Logic:
When reviewing a card, the user grades their recall:

```
                  ┌───────────────┐
                  │ Card Reviewed │
                  └───────┬───────┘
                          │
          ┌───────────────┴───────────────┬───────────────────────────────┐
          ▼                               ▼                               ▼
     Quality = 0                    Quality = 3                     Quality = 4 / 5
    (Again / Fail)                     (Hard)                        (Good / Easy)
          │                               │                               │
• reps = 0                      • ease = max(1.3, ease - 0.15)  • reps += 1
• interval = 0                  • interval = interval * 1.2     • interval = interval * ease
• ease = max(1.3, ease - 0.20)  • reps += 1                     • if Easy: interval *= 1.3
• due = DateTime.now()          • due = Today + interval days   • due = Today + interval days
 (immediate relearn queue)
```

---

## 2. SQLite Database Schema & Multi-Device UUIDs

All local tables use **RFC 4122 v4 UUID primary keys** to ensure collision-free synchronization across multiple offline devices.

```sql
-- 1. Decks Table
CREATE TABLE IF NOT EXISTS decks (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    front_mode TEXT DEFAULT 'both',      -- 'kanji', 'meaning', or 'both'
    new_limit INTEGER DEFAULT 20,        -- Daily new card limit
    review_limit INTEGER DEFAULT 200,    -- Daily review card limit
    is_deleted INTEGER DEFAULT 0,        -- Soft deletion flag for 2-way sync
    updated_at INTEGER NOT NULL          -- Epoch timestamp in milliseconds
);

-- 2. Deck Cards (Membership & SRS State)
CREATE TABLE IF NOT EXISTS deck_cards (
    deck_id TEXT NOT NULL,
    kanji_id INTEGER NOT NULL,
    due_date TEXT,                       -- ISO8601 string
    ease_factor REAL DEFAULT 2.5,
    interval_days REAL DEFAULT 0,
    reps INTEGER DEFAULT 0,
    is_deleted INTEGER DEFAULT 0,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (deck_id, kanji_id),
    FOREIGN KEY (deck_id) REFERENCES decks(id) ON DELETE CASCADE,
    FOREIGN KEY (kanji_id) REFERENCES kanji(id) ON DELETE CASCADE
);

-- 3. Daily Review Logs (Quota & History Tracking)
CREATE TABLE IF NOT EXISTS review_logs (
    id TEXT PRIMARY KEY,
    kanji_id INTEGER NOT NULL,
    deck_id TEXT,
    type TEXT NOT NULL,                  -- 'new' or 'review'
    date_str TEXT NOT NULL,              -- 'YYYY-MM-DD'
    is_deleted INTEGER DEFAULT 0,
    updated_at INTEGER NOT NULL
);

-- 4. Global Kanji Dictionary
CREATE TABLE IF NOT EXISTS kanji (
    id INTEGER PRIMARY KEY,
    char TEXT NOT NULL UNIQUE,
    readings TEXT,                       -- Onyomi & Kunyomi kana strings
    meanings TEXT,                       -- English meanings
    radicals_json TEXT,                  -- JSON array of decomposed radicals
    svg_paths TEXT,                      -- JSON array of KanjiVG SVG path strings
    jlpt INTEGER,                        -- 4=N5, 3=N4, 2=N3/N2, 1=N1
    updated_at INTEGER DEFAULT 0
);
```

---

## 3. Two-Way Delta Cloud Synchronization (`SyncService`)

The synchronization engine performs atomic delta synchronization between the local SQLite database and PostgreSQL on Supabase:

1. **Delta Change Detection:**
   * Only records with `updated_at > last_sync_timestamp` are exchanged.
2. **Conflict Resolution (Last-Write-Wins):**
   * If both cloud and local records were edited offline, the record with the higher `updated_at` millisecond timestamp takes precedence.
3. **Three Sync Strategies Supported:**
   * **Auto-Merge (Default):** Last-write-wins merge across all decks, cards, and review quotas.
   * **Override Cloud with Local:** Force-pushes local state to overwrite the cloud database.
   * **Override Local with Cloud:** Force-pulls cloud database to overwrite local SQLite.
4. **Chunked Uploads:**
   * Batches large datasets (100–250 records per chunk) to avoid payload timeouts on mobile connections.
5. **Undo Action Support (`_undoLastReview`):**
   * Full snapshot restoration of `reps`, `ease_factor`, `interval_days`, `due_date`, and deletion of the corresponding `review_log`.

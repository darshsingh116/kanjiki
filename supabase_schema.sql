-- ==============================================================================
-- KANJIKI SUPABASE DATABASE SCHEMA
-- Multi-device Spaced Repetition Kanji Learning System
-- ==============================================================================

-- ==============================================================================
-- 1. GLOBAL POOL (STATIC DATA - PRESERVED & READ-ONLY FOR ALL USERS)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.global_kanji (
    id INTEGER PRIMARY KEY, -- Matches local SQLite IDs (1 to ~12000)
    char TEXT NOT NULL UNIQUE,
    readings TEXT,
    meanings TEXT,
    radicals_json JSONB,
    svg_paths JSONB,
    jlpt INTEGER
);

-- ==============================================================================
-- 2. USER DATA (SYNCED, ISOLATED & MULTI-DEVICE SAFE)
-- ==============================================================================

-- Table: decks (Custom and JLPT Decks per user)
CREATE TABLE IF NOT EXISTS public.decks (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    front_mode TEXT NOT NULL DEFAULT 'both',
    deck_type TEXT NOT NULL DEFAULT 'custom',
    new_limit INTEGER NOT NULL DEFAULT 20,
    review_limit INTEGER NOT NULL DEFAULT 200,
    rule_params JSONB,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: deck_cards (SRS Progress & Card membership in decks)
CREATE TABLE IF NOT EXISTS public.deck_cards (
    deck_id UUID NOT NULL REFERENCES public.decks(id) ON DELETE CASCADE,
    kanji_id INTEGER NOT NULL REFERENCES public.global_kanji(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    due_date TEXT,
    ease_factor FLOAT NOT NULL DEFAULT 2.5,
    interval_days FLOAT NOT NULL DEFAULT 0,
    reps INTEGER NOT NULL DEFAULT 0,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (deck_id, kanji_id)
);

-- Table: review_logs (Daily review history and quota sync across devices)
CREATE TABLE IF NOT EXISTS public.review_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    deck_id UUID REFERENCES public.decks(id) ON DELETE SET NULL,
    kanji_id INTEGER NOT NULL REFERENCES public.global_kanji(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'new' or 'review'
    date_str TEXT NOT NULL, -- 'YYYY-MM-DD'
    updated_at BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: user_sync_state (Sync cursor and last active marker)
CREATE TABLE IF NOT EXISTS public.user_sync_state (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    last_sync_ms BIGINT NOT NULL DEFAULT 0,
    updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now()) * 1000)::bigint
);

-- ==============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ==============================================================================

-- Global Kanji Pool: readable by everyone (authenticated and anonymous)
ALTER TABLE public.global_kanji ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read global kanji" ON public.global_kanji;
CREATE POLICY "Anyone can read global kanji" ON public.global_kanji FOR SELECT USING (true);

-- User Decks: strictly isolated to the owning user
ALTER TABLE public.decks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own decks" ON public.decks;
CREATE POLICY "Users can manage own decks" ON public.decks
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Deck Cards: strictly isolated to the owning user
ALTER TABLE public.deck_cards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own deck cards" ON public.deck_cards;
CREATE POLICY "Users can manage own deck cards" ON public.deck_cards
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Review Logs: strictly isolated to the owning user
ALTER TABLE public.review_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own review logs" ON public.review_logs;
CREATE POLICY "Users can manage own review logs" ON public.review_logs
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- User Sync State: strictly isolated to the owning user
ALTER TABLE public.user_sync_state ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own sync state" ON public.user_sync_state;
CREATE POLICY "Users can manage own sync state" ON public.user_sync_state
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 4. PERFORMANCE INDEXES
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_decks_user_updated ON public.decks (user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_decks_user_deleted ON public.decks (user_id, is_deleted);
CREATE INDEX IF NOT EXISTS idx_deck_cards_user_updated ON public.deck_cards (user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_deck_cards_deck_kanji ON public.deck_cards (deck_id, kanji_id);
CREATE INDEX IF NOT EXISTS idx_deck_cards_user_deleted ON public.deck_cards (user_id, is_deleted);
CREATE INDEX IF NOT EXISTS idx_review_logs_user_updated ON public.review_logs (user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_review_logs_lookup ON public.review_logs (user_id, date_str, type);
CREATE INDEX IF NOT EXISTS idx_user_sync_state_user ON public.user_sync_state (user_id);

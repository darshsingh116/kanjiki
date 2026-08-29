-- Loads assets/data/kanji.db into public.global_kanji on first container
-- start. The CSV referenced here is generated (not committed) — run
-- `scripts/generate_kanji_seed.sh` at least once before `docker compose up`.
-- If the CSV is missing this step is skipped so the stack still boots with
-- an empty (but schema-correct) global_kanji table.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_stat_file('/seed/global_kanji.csv', true)) THEN
    EXECUTE $copy$
      COPY public.global_kanji (id, char, readings, meanings, radicals_json, svg_paths, jlpt)
      FROM '/seed/global_kanji.csv'
      WITH (FORMAT csv, HEADER true)
    $copy$;
    RAISE NOTICE 'Seeded global_kanji from /seed/global_kanji.csv';
  ELSE
    RAISE NOTICE 'No /seed/global_kanji.csv found — skipping kanji seed. Run scripts/generate_kanji_seed.sh first.';
  END IF;
END $$;

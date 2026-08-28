import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kanjiapp/services/db_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('UUID Generator Tests', () {
    test('generates valid RFC 4122 v4 UUID format', () {
      final uuid = generateUuid();
      expect(uuid.length, equals(36));
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidRegex.hasMatch(uuid), isTrue);
    });

    test('generates unique UUIDs', () {
      final set = <String>{};
      for (int i = 0; i < 1000; i++) {
        set.add(generateUuid());
      }
      expect(set.length, equals(1000));
    });
  });

  group('DbService & SQLite Schema Tests', () {
    late Database testDb;
    late String dbName;

    setUp(() async {
      dbName = 'test_${generateUuid()}.db';
      testDb = await databaseFactoryFfi.openDatabase(dbName);
      DbService.db = testDb;

      // Seed kanji table
      await testDb.execute('''
        CREATE TABLE kanji (
          id INTEGER PRIMARY KEY,
          char TEXT NOT NULL UNIQUE,
          readings TEXT,
          meanings TEXT,
          radicals_json TEXT,
          svg_paths TEXT,
          jlpt INTEGER,
          updated_at INTEGER DEFAULT 0
        )
      ''');

      await testDb.insert('kanji', {
        'id': 1,
        'char': '日',
        'readings': 'ニチ, ジツ, ひ, -び, -か',
        'meanings': 'day, sun, Japan, counter for days',
        'radicals_json': '[]',
        'svg_paths': '[]',
        'jlpt': 4,
      });

      await testDb.insert('kanji', {
        'id': 2,
        'char': '一',
        'readings': 'イチ, イツ, ひと-, ひと.つ',
        'meanings': 'one',
        'radicals_json': '[]',
        'svg_paths': '[]',
        'jlpt': 4,
      });

      await testDb.insert('kanji', {
        'id': 3,
        'char': '国',
        'readings': 'コク, くに',
        'meanings': 'country',
        'radicals_json': '[]',
        'svg_paths': '[]',
        'jlpt': 4,
      });

      // Initialize DbService tables
      await testDb.execute('''
        CREATE TABLE IF NOT EXISTS decks (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          front_mode TEXT DEFAULT 'both',
          new_limit INTEGER DEFAULT 20,
          review_limit INTEGER DEFAULT 200,
          is_deleted INTEGER DEFAULT 0,
          updated_at INTEGER NOT NULL
        )
      ''');

      await testDb.execute('''
        CREATE TABLE IF NOT EXISTS deck_cards (
          deck_id TEXT NOT NULL,
          kanji_id INTEGER NOT NULL,
          due_date TEXT,
          ease_factor REAL DEFAULT 2.5,
          interval_days REAL DEFAULT 0,
          reps INTEGER DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (deck_id, kanji_id)
        )
      ''');

      await testDb.execute('''
        CREATE TABLE IF NOT EXISTS review_logs (
          id TEXT PRIMARY KEY,
          kanji_id INTEGER NOT NULL,
          deck_id TEXT,
          type TEXT NOT NULL,
          date_str TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          updated_at INTEGER NOT NULL
        )
      ''');
    });

    tearDown(() async {
      await testDb.close();
      await databaseFactoryFfi.deleteDatabase(dbName);
    });

    test('createDeck creates a deck with UUID and correct defaults', () async {
      final deckId = await DbService.createDeck('Test Deck');
      expect(deckId.isNotEmpty, isTrue);
      expect(deckId.length, equals(36));

      final decks = await DbService.getDecks();
      expect(decks.length, equals(1));
      expect(decks.first['id'], equals(deckId));
      expect(decks.first['name'], equals('Test Deck'));
      expect(decks.first['front_mode'], equals('both'));
      expect(decks.first['new_limit'], equals(20));
      expect(decks.first['review_limit'], equals(200));
      expect(decks.first['is_deleted'], equals(0));
      expect(decks.first['updated_at'], isNonNegative);
    });

    test('addCardsToDeck and getCardsForDeck works with UUIDs', () async {
      final deckId = await DbService.createDeck('JLPT Deck');
      await DbService.addCardsToDeck(deckId, [1, 2]);

      final cards = await DbService.getCardsForDeck(deckId);
      expect(cards.length, equals(2));
      expect(cards.any((c) => c.id == 1), isTrue);
      expect(cards.any((c) => c.id == 2), isTrue);
      expect(cards.first.deckId, equals(deckId));
    });

    test('deleteDeck performs soft delete correctly', () async {
      final deckId = await DbService.createDeck('To Delete');
      await DbService.addCardsToDeck(deckId, [1]);

      expect((await DbService.getDecks()).length, equals(1));
      expect((await DbService.getCardsForDeck(deckId)).length, equals(1));

      await DbService.deleteDeck(deckId);

      // getDecks filters out soft-deleted decks
      expect((await DbService.getDecks()).length, equals(0));
      // getCardsForDeck filters out soft-deleted cards
      expect((await DbService.getCardsForDeck(deckId)).length, equals(0));

      // Internal check: is_deleted is 1 in DB
      final rawDecks = await DbService.getDecks(includeDeleted: true);
      expect(rawDecks.length, equals(1));
      expect(rawDecks.first['is_deleted'], equals(1));
    });

    test('updateSRS and getReviewQueue track Spaced Repetition progress', () async {
      final deckId = await DbService.createDeck('SRS Deck');
      await DbService.addCardsToDeck(deckId, [1, 2]);

      final initialQueue = await DbService.getReviewQueue(deckId: deckId);
      expect(initialQueue.length, equals(2));

      final card1 = initialQueue.first;
      card1.reps = 1;
      card1.intervalDays = 1;
      card1.dueDate = DateTime.now().add(const Duration(days: 1));
      await DbService.updateSRS(card1);
      await DbService.logReview(card1.id, deckId, true);

      final stats = await DbService.getStats(deckId: deckId);
      expect(stats['total'], equals(2));
      expect(stats['new'], equals(1)); // 1 remaining new card
    });

    test('Legacy INTEGER schema migration migrates old decks to UUIDs cleanly', () async {
      final legacyDbName = 'legacy_${generateUuid()}.db';
      final legacyDb = await databaseFactoryFfi.openDatabase(legacyDbName);

      await legacyDb.execute('''
        CREATE TABLE decks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          front_mode TEXT DEFAULT 'both',
          new_limit INTEGER DEFAULT 20,
          review_limit INTEGER DEFAULT 200,
          updated_at INTEGER DEFAULT 1000
        )
      ''');

      await legacyDb.execute('''
        CREATE TABLE deck_cards (
          deck_id INTEGER,
          kanji_id INTEGER,
          due_date TEXT,
          ease_factor REAL DEFAULT 2.5,
          interval_days REAL DEFAULT 0,
          reps INTEGER DEFAULT 0,
          updated_at INTEGER DEFAULT 1000,
          PRIMARY KEY (deck_id, kanji_id)
        )
      ''');

      await legacyDb.execute('''
        CREATE TABLE review_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kanji_id INTEGER,
          deck_id INTEGER,
          type TEXT,
          date_str TEXT,
          local_uuid TEXT,
          updated_at INTEGER DEFAULT 1000
        )
      ''');

      await legacyDb.insert('decks', {'id': 1, 'name': 'Old Deck 1', 'updated_at': 1000});
      await legacyDb.insert('decks', {'id': 2, 'name': 'Old Deck 2', 'updated_at': 1000});

      await legacyDb.insert('deck_cards', {'deck_id': 1, 'kanji_id': 101, 'reps': 3, 'updated_at': 1000});
      await legacyDb.insert('deck_cards', {'deck_id': 2, 'kanji_id': 102, 'reps': 5, 'updated_at': 1000});

      await legacyDb.insert('review_logs', {
        'id': 1,
        'kanji_id': 101,
        'deck_id': 1,
        'type': 'review',
        'date_str': '2026-08-20',
        'local_uuid': 'legacy-uuid-1',
        'updated_at': 1000,
      });

      DbService.db = legacyDb;

      // Run migration check
      await DbService.migrateLegacySchemaIfNeeded();

      final migratedDecks = await DbService.getDecks();
      expect(migratedDecks.length, equals(2));
      for (var d in migratedDecks) {
        expect(d['id'], isA<String>());
        expect((d['id'] as String).length, equals(36));
      }

      final deck1Uuid = migratedDecks.firstWhere((d) => d['name'] == 'Old Deck 1')['id'] as String;
      final deck1Cards = await legacyDb.query('deck_cards', where: 'deck_id = ?', whereArgs: [deck1Uuid]);
      expect(deck1Cards.length, equals(1));
      expect(deck1Cards.first['kanji_id'], equals(101));
      expect(deck1Cards.first['reps'], equals(3));

      await legacyDb.close();
      await databaseFactoryFfi.deleteDatabase(legacyDbName);
    });
  });
}

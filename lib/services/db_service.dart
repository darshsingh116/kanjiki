import 'dart:io' as io;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/kanji.dart';

/// Helper to generate standard RFC 4122 v4 UUID strings.
String generateUuid() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // RFC 4122 version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  
  final buffer = StringBuffer();
  for (int i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
    buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

class DbService {
  static late Database db;

  static Future<void> init() async {
    String path;
    bool exists;

    if (kIsWeb) {
      path = 'kanji.db';
      var factory = databaseFactoryFfiWeb;
      exists = await factory.databaseExists(path);
    } else {
      var databasesPath = await getDatabasesPath();
      path = join(databasesPath, "kanji.db");
      exists = await databaseExists(path);
    }

    if (!exists) {
      await _copyDbFromAssets(path);
      db = await (kIsWeb
          ? databaseFactoryFfiWeb.openDatabase(path)
          : openDatabase(path));
    } else {
      // Check if the current database has the new JLPT data. If not, overwrite it.
      db = await (kIsWeb
          ? databaseFactoryFfiWeb.openDatabase(path)
          : openDatabase(path));
      bool needsUpdate = false;
      try {
        var countRes = await db.rawQuery("SELECT COUNT(*) FROM kanji");
        int count = Sqflite.firstIntValue(countRes) ?? 0;
        if (count == 0) {
          needsUpdate = true; // DB is empty!
        }
        await db.rawQuery("SELECT jlpt FROM kanji LIMIT 1");
      } catch (e) {
        needsUpdate = true; // Schema might be entirely missing the column
      }

      if (needsUpdate) {
        await db.close();
        if (kIsWeb) {
          await databaseFactoryFfiWeb.deleteDatabase(path);
        } else {
          await deleteDatabase(path);
        }
        await _copyDbFromAssets(path);
        db = await (kIsWeb
            ? databaseFactoryFfiWeb.openDatabase(path)
            : openDatabase(path));
      }
    }

    // 1. Check for legacy integer ID schema migration
    await migrateLegacySchemaIfNeeded();

    // 2. Create Deck & Review tables with UUID primary keys
    await db.execute('''
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS deck_cards (
        deck_id TEXT NOT NULL,
        kanji_id INTEGER NOT NULL,
        due_date TEXT,
        ease_factor REAL DEFAULT 2.5,
        interval_days REAL DEFAULT 0,
        reps INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (deck_id, kanji_id),
        FOREIGN KEY (deck_id) REFERENCES decks(id) ON DELETE CASCADE,
        FOREIGN KEY (kanji_id) REFERENCES kanji(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
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

    // Add updated_at for kanji edits if missing
    try {
      await db.execute("ALTER TABLE kanji ADD COLUMN updated_at INTEGER DEFAULT 0");
    } catch (_) {}

    // Add columns to existing tables defensively (in case tables existed before)
    try {
      await db.execute("ALTER TABLE decks ADD COLUMN is_deleted INTEGER DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE deck_cards ADD COLUMN is_deleted INTEGER DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE review_logs ADD COLUMN is_deleted INTEGER DEFAULT 0");
    } catch (_) {}

    // Add high-performance indexes
    try {
      await db.execute("CREATE INDEX IF NOT EXISTS idx_decks_is_del_up ON decks(is_deleted, updated_at)");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_deck_cards_deck_del ON deck_cards(deck_id, is_deleted)");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_deck_cards_up_del ON deck_cards(updated_at, is_deleted)");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_review_logs_lookup ON review_logs(date_str, type, deck_id)");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_review_logs_up ON review_logs(updated_at)");
    } catch (_) {}
  }

  static Future<void> migrateLegacySchemaIfNeeded() async {
    try {
      final checkDecks = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='decks'");
      if (checkDecks.isNotEmpty) {
        final tableInfo = await db.rawQuery("PRAGMA table_info(decks)");
        final idCol = tableInfo.firstWhere((c) => c['name'] == 'id', orElse: () => <String, dynamic>{});
        final idType = idCol['type']?.toString().toUpperCase() ?? '';

        // If 'id' is INTEGER (old schema), migrate to TEXT UUIDs
        if (idType.contains('INT')) {
          await db.transaction((txn) async {
            final oldDecks = await txn.query('decks');
            final oldDeckCards = await txn.query('deck_cards');
            final oldReviewLogs = await txn.query('review_logs');

            final Map<String, String> idMap = {};
            for (var d in oldDecks) {
              final oldIdStr = d['id'].toString();
              idMap[oldIdStr] = generateUuid();
            }

            await txn.execute("DROP TABLE IF EXISTS deck_cards");
            await txn.execute("DROP TABLE IF EXISTS review_logs");
            await txn.execute("DROP TABLE IF EXISTS decks");

            await txn.execute('''
              CREATE TABLE decks (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                front_mode TEXT DEFAULT 'both',
                new_limit INTEGER DEFAULT 20,
                review_limit INTEGER DEFAULT 200,
                is_deleted INTEGER DEFAULT 0,
                updated_at INTEGER NOT NULL
              )
            ''');

            await txn.execute('''
              CREATE TABLE deck_cards (
                deck_id TEXT NOT NULL,
                kanji_id INTEGER NOT NULL,
                due_date TEXT,
                ease_factor REAL DEFAULT 2.5,
                interval_days REAL DEFAULT 0,
                reps INTEGER DEFAULT 0,
                is_deleted INTEGER DEFAULT 0,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (deck_id, kanji_id),
                FOREIGN KEY (deck_id) REFERENCES decks(id) ON DELETE CASCADE,
                FOREIGN KEY (kanji_id) REFERENCES kanji(id) ON DELETE CASCADE
              )
            ''');

            await txn.execute('''
              CREATE TABLE review_logs (
                id TEXT PRIMARY KEY,
                kanji_id INTEGER NOT NULL,
                deck_id TEXT,
                type TEXT NOT NULL,
                date_str TEXT NOT NULL,
                is_deleted INTEGER DEFAULT 0,
                updated_at INTEGER NOT NULL
              )
            ''');

            final nowMs = DateTime.now().millisecondsSinceEpoch;

            for (var d in oldDecks) {
              final oldIdStr = d['id'].toString();
              final uuid = idMap[oldIdStr] ?? generateUuid();
              await txn.insert('decks', {
                'id': uuid,
                'name': d['name'] ?? 'Deck',
                'front_mode': d['front_mode'] ?? 'both',
                'new_limit': (d['new_limit'] as num?)?.toInt() ?? 20,
                'review_limit': (d['review_limit'] as num?)?.toInt() ?? 200,
                'is_deleted': 0,
                'updated_at': (d['updated_at'] as num?)?.toInt() ?? nowMs,
              });
            }

            for (var dc in oldDeckCards) {
              final oldDeckIdStr = dc['deck_id'].toString();
              final deckUuid = idMap[oldDeckIdStr];
              if (deckUuid != null) {
                await txn.insert('deck_cards', {
                  'deck_id': deckUuid,
                  'kanji_id': dc['kanji_id'],
                  'due_date': dc['due_date'],
                  'ease_factor': (dc['ease_factor'] as num?)?.toDouble() ?? 2.5,
                  'interval_days': (dc['interval_days'] as num?)?.toDouble() ?? 0.0,
                  'reps': (dc['reps'] as num?)?.toInt() ?? 0,
                  'is_deleted': 0,
                  'updated_at': (dc['updated_at'] as num?)?.toInt() ?? nowMs,
                });
              }
            }

            for (var rl in oldReviewLogs) {
              final oldDeckIdStr = rl['deck_id']?.toString();
              String? deckUuid;
              if (oldDeckIdStr != null && idMap.containsKey(oldDeckIdStr)) {
                deckUuid = idMap[oldDeckIdStr];
              }
              final logUuid = rl['local_uuid']?.toString() ?? generateUuid();
              await txn.insert('review_logs', {
                'id': logUuid,
                'kanji_id': rl['kanji_id'],
                'deck_id': deckUuid,
                'type': rl['type'] ?? 'review',
                'date_str': rl['date_str'] ?? DateTime.now().toIso8601String().split('T')[0],
                'is_deleted': 0,
                'updated_at': (rl['updated_at'] as num?)?.toInt() ?? nowMs,
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Migration check exception: $e");
    }
  }

  static Future<void> _copyDbFromAssets(String path) async {
    if (kIsWeb) {
      var factory = databaseFactoryFfiWeb;
      ByteData data = await rootBundle.load("assets/data/kanji.db");
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await factory.writeDatabaseBytes(path, Uint8List.fromList(bytes));
      return;
    }
    try {
      await io.Directory(dirname(path)).create(recursive: true);
    } catch (_) {}

    ByteData data = await rootBundle.load("assets/data/kanji.db");
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await io.File(path).writeAsBytes(bytes, flush: true);
  }

  static Future<List<Kanji>> getReviewQueue({String? deckId}) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final todayStr = nowIso.split('T')[0];
    final endOfTodayIso = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

    int deckNewLimit = 20;
    int deckRevLimit = 200;

    if (deckId != null) {
      final deckInfo = await db.query('decks', where: 'id = ? AND is_deleted = 0', whereArgs: [deckId]);
      if (deckInfo.isNotEmpty) {
        deckNewLimit = (deckInfo.first['new_limit'] as int?) ?? 20;
        deckRevLimit = (deckInfo.first['review_limit'] as int?) ?? 200;
      }
    }

    String logDeckClause = deckId != null ? 'AND deck_id = ?' : '';
    List<dynamic> logArgsNew = [todayStr];
    List<dynamic> logArgsRev = [todayStr];
    if (deckId != null) {
      logArgsNew.add(deckId);
      logArgsRev.add(deckId);
    }

    final newLogRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM review_logs WHERE type = 'new' AND date_str = ? AND is_deleted = 0 $logDeckClause",
      logArgsNew,
    );
    final revLogRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM review_logs WHERE type = 'review' AND date_str = ? AND is_deleted = 0 $logDeckClause",
      logArgsRev,
    );
    
    int newStudied = (newLogRes.first['c'] as int?) ?? 0;
    int revStudied = (revLogRes.first['c'] as int?) ?? 0;

    int effectiveNewLimit = (deckNewLimit - newStudied) > 0 ? (deckNewLimit - newStudied) : 0;
    int effectiveRevLimit = (deckRevLimit - revStudied) > 0 ? (deckRevLimit - revStudied) : 0;

    String selectClause = 'SELECT kanji.*, dc.deck_id, dc.due_date, dc.ease_factor, dc.interval_days, dc.reps, dc.updated_at';
    String joinClause = 'INNER JOIN deck_cards dc ON kanji.id = dc.kanji_id INNER JOIN decks d ON d.id = dc.deck_id';
    String whereDeckClause = deckId != null ? 'AND dc.deck_id = ?' : '';
    List<dynamic> baseArgs = deckId != null ? [deckId] : [];

    // 1. Get learning reviews (cards in learning/relearn phase, reps < 1 or failed)
    // Ordered by updated_at ASC so recently failed cards go to the back of the learning queue!
    final List<Map<String, dynamic>> learningMaps = await db.rawQuery('''
      $selectClause FROM kanji 
      $joinClause
      WHERE dc.is_deleted = 0 AND d.is_deleted = 0 AND dc.due_date IS NOT NULL AND dc.due_date <= ? AND dc.reps < 1 $whereDeckClause
      ORDER BY dc.updated_at ASC, dc.due_date ASC
    ''', [endOfTodayIso, ...baseArgs]);

    // 2. Get due reviews (graduated reviews due on or before today)
    final List<Map<String, dynamic>> dueMaps = await db.rawQuery('''
      $selectClause FROM kanji 
      $joinClause
      WHERE dc.is_deleted = 0 AND d.is_deleted = 0 AND dc.due_date IS NOT NULL AND dc.due_date <= ? AND dc.reps >= 1 $whereDeckClause
      ORDER BY dc.due_date ASC
      LIMIT ?
    ''', [endOfTodayIso, ...baseArgs, effectiveRevLimit]);

    // 3. Get new cards (never introduced, due_date IS NULL)
    final List<Map<String, dynamic>> newMaps = await db.rawQuery('''
      $selectClause FROM kanji 
      $joinClause
      WHERE dc.is_deleted = 0 AND d.is_deleted = 0 AND dc.due_date IS NULL $whereDeckClause
      ORDER BY kanji.id ASC
      LIMIT ?
    ''', [...baseArgs, effectiveNewLimit]);

    final allMaps = [...learningMaps, ...dueMaps, ...newMaps];

    return allMaps.map((m) => Kanji.fromMap(m)).toList();
  }

  static Future<String> logReview(int kanjiId, String? deckId, bool isNew) async {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    final nowMs = now.millisecondsSinceEpoch;
    final uuid = generateUuid();

    await db.insert('review_logs', {
      'id': uuid,
      'kanji_id': kanjiId,
      'deck_id': deckId,
      'type': isNew ? 'new' : 'review',
      'date_str': todayStr,
      'is_deleted': 0,
      'updated_at': nowMs,
    });
    return uuid;
  }

  static Future<void> deleteReviewLog(String logId) async {
    await db.delete('review_logs', where: 'id = ?', whereArgs: [logId]);
  }

  static Future<void> updateSRS(Kanji kanji) async {
    if (kanji.deckId == null) return; // Cannot update SRS without deck context
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'deck_cards',
      {
        'due_date': kanji.dueDate?.toIso8601String(),
        'ease_factor': kanji.easeFactor,
        'interval_days': kanji.intervalDays,
        'reps': kanji.reps,
        'is_deleted': 0,
        'updated_at': nowMs,
      },
      where: 'deck_id = ? AND kanji_id = ?',
      whereArgs: [kanji.deckId, kanji.id],
    );

    await db.update(
      'decks',
      {'updated_at': nowMs},
      where: 'id = ?',
      whereArgs: [kanji.deckId],
    );
  }

  static Future<Map<String, int>> getStats({String? deckId}) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final todayStr = nowIso.split('T')[0];
    final endOfTodayIso = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

    int deckNewLimit = 20;
    int deckRevLimit = 200;

    if (deckId != null) {
      final deckInfo = await db.query('decks', where: 'id = ? AND is_deleted = 0', whereArgs: [deckId]);
      if (deckInfo.isNotEmpty) {
        deckNewLimit = (deckInfo.first['new_limit'] as int?) ?? 20;
        deckRevLimit = (deckInfo.first['review_limit'] as int?) ?? 200;
      }
    }

    String logDeckClause = deckId != null ? 'AND deck_id = ?' : '';
    List<dynamic> logArgsNew = [todayStr];
    List<dynamic> logArgsRev = [todayStr];
    if (deckId != null) {
      logArgsNew.add(deckId);
      logArgsRev.add(deckId);
    }

    final newLogRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM review_logs WHERE type = 'new' AND date_str = ? AND is_deleted = 0 $logDeckClause",
      logArgsNew,
    );
    final revLogRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM review_logs WHERE type = 'review' AND date_str = ? AND is_deleted = 0 $logDeckClause",
      logArgsRev,
    );
    
    int newStudied = (newLogRes.first['c'] as int?) ?? 0;
    int revStudied = (revLogRes.first['c'] as int?) ?? 0;

    int effectiveNewLimit = (deckNewLimit - newStudied) > 0 ? (deckNewLimit - newStudied) : 0;
    int effectiveRevLimit = (deckRevLimit - revStudied) > 0 ? (deckRevLimit - revStudied) : 0;

    String joinClause = 'INNER JOIN deck_cards dc ON kanji.id = dc.kanji_id INNER JOIN decks d ON d.id = dc.deck_id';
    String baseCondition = 'dc.is_deleted = 0 AND d.is_deleted = 0';
    String whereDeckTotal = deckId != null ? 'WHERE $baseCondition AND dc.deck_id = ?' : 'WHERE $baseCondition';
    String whereDeckAnd = deckId != null ? 'AND $baseCondition AND dc.deck_id = ?' : 'AND $baseCondition';

    List<dynamic> args = deckId != null ? [deckId] : [];

    final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM kanji $joinClause $whereDeckTotal', args);

    final newResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM kanji
      $joinClause
      WHERE dc.due_date IS NULL $whereDeckAnd
    ''', args);

    List<dynamic> learningArgs = [endOfTodayIso, ...args];
    final learningResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM kanji
      $joinClause
      WHERE (dc.due_date IS NOT NULL AND dc.due_date <= ?) $whereDeckAnd AND dc.reps < 1
    ''', learningArgs);

    List<dynamic> reviewArgs = [endOfTodayIso, ...args];
    final reviewResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM kanji
      $joinClause
      WHERE (dc.due_date IS NOT NULL AND dc.due_date <= ?) $whereDeckAnd AND dc.reps >= 1
    ''', reviewArgs);

    List<dynamic> dueArgs = [endOfTodayIso, ...args];
    final dueResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM kanji
      $joinClause
      WHERE (dc.due_date IS NOT NULL AND dc.due_date <= ?) $whereDeckAnd
    ''', dueArgs);

    int rawNew = (newResult.first['count'] as int?) ?? 0;
    int rawReview = (reviewResult.first['count'] as int?) ?? 0;

    return {
      'total': (totalResult.first['count'] as int?) ?? 0,
      'new': rawNew > effectiveNewLimit ? effectiveNewLimit : rawNew,
      'learning': (learningResult.first['count'] as int?) ?? 0,
      'review': rawReview > effectiveRevLimit ? effectiveRevLimit : rawReview,
      'due': (dueResult.first['count'] as int?) ?? 0,
    };
  }

  // Custom Deck management
  static Future<List<Map<String, dynamic>>> getDecks({bool includeDeleted = false}) async {
    if (includeDeleted) {
      return await db.query('decks', orderBy: 'updated_at DESC');
    }
    return await db.query('decks', where: 'is_deleted = 0', orderBy: 'updated_at DESC');
  }

  static Future<Map<String, dynamic>?> getDeck(String deckId) async {
    final res = await db.query('decks', where: 'id = ?', whereArgs: [deckId]);
    return res.isNotEmpty ? res.first : null;
  }

  static Future<String> createDeck(String name, {String? id, String frontMode = 'both', int newLimit = 20, int reviewLimit = 200}) async {
    final deckId = id ?? generateUuid();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.insert('decks', {
      'id': deckId,
      'name': name,
      'front_mode': frontMode,
      'new_limit': newLimit,
      'review_limit': reviewLimit,
      'is_deleted': 0,
      'updated_at': nowMs,
    });
    return deckId;
  }

  static Future<void> updateDeckMode(String deckId, String frontMode, {int newLimit = 20, int reviewLimit = 200}) async {
    await db.update(
      'decks',
      {
        'front_mode': frontMode,
        'new_limit': newLimit,
        'review_limit': reviewLimit,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [deckId],
    );
  }

  static Future<void> deleteDeck(String deckId) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'decks',
        {'is_deleted': 1, 'updated_at': nowMs},
        where: 'id = ?',
        whereArgs: [deckId],
      );
      await txn.update(
        'deck_cards',
        {'is_deleted': 1, 'updated_at': nowMs},
        where: 'deck_id = ?',
        whereArgs: [deckId],
      );
    });
  }

  static Future<void> addCardsToDeck(String deckId, List<int> kanjiIds) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (var id in kanjiIds) {
        final existing = await txn.query(
          'deck_cards',
          where: 'deck_id = ? AND kanji_id = ?',
          whereArgs: [deckId, id],
        );
        if (existing.isEmpty) {
          await txn.insert('deck_cards', {
            'deck_id': deckId,
            'kanji_id': id,
            'due_date': null,
            'ease_factor': 2.5,
            'interval_days': 0.0,
            'reps': 0,
            'is_deleted': 0,
            'updated_at': nowMs,
          });
        } else {
          await txn.update(
            'deck_cards',
            {'is_deleted': 0, 'updated_at': nowMs},
            where: 'deck_id = ? AND kanji_id = ?',
            whereArgs: [deckId, id],
          );
        }
      }
      await txn.update(
        'decks',
        {'updated_at': nowMs},
        where: 'id = ?',
        whereArgs: [deckId],
      );
    });
  }

  static Future<void> removeCardsFromDeck(String deckId, List<int> kanjiIds) async {
    if (kanjiIds.isEmpty) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (var id in kanjiIds) {
        await txn.update(
          'deck_cards',
          {'is_deleted': 1, 'updated_at': nowMs},
          where: 'deck_id = ? AND kanji_id = ?',
          whereArgs: [deckId, id],
        );
      }
      await txn.update(
        'decks',
        {'updated_at': nowMs},
        where: 'id = ?',
        whereArgs: [deckId],
      );
    });
  }

  static Future<Map<int, int>> getJlptCounts() async {
    final counts = <int, int>{};
    final res = await db.rawQuery(
        'SELECT jlpt, COUNT(*) as c FROM kanji WHERE jlpt IS NOT NULL GROUP BY jlpt');
    for (var r in res) {
      int? lvl = r['jlpt'] as int?;
      int c = r['c'] as int;
      if (lvl != null) {
        counts[lvl] = c;
      }
    }
    return counts;
  }

  static Future<String?> createJlptDeck(int modernLevel) async {
    int dbJlpt = modernLevel;
    if (modernLevel == 5) {
      dbJlpt = 4;
    } else if (modernLevel == 4) {
      dbJlpt = 3;
    } else if (modernLevel == 3) {
      dbJlpt = 2;
    } else if (modernLevel == 2) {
      dbJlpt = 2;
    } else if (modernLevel == 1) {
      dbJlpt = 1;
    }

    final kanjis =
        await db.query('kanji', where: 'jlpt = ?', whereArgs: [dbJlpt]);
    if (kanjis.isEmpty) return null;

    final deckId = await createDeck('JLPT N$modernLevel');
    final kanjiIds = kanjis.map((k) => k['id'] as int).toList();
    await addCardsToDeck(deckId, kanjiIds);
    return deckId;
  }

  static Future<void> exportDatabase() async {
    if (kIsWeb) {
      final bytes = await databaseFactoryFfiWeb.readDatabaseBytes('kanji.db');
      await Share.shareXFiles([XFile.fromData(bytes, name: 'kanjiki_backup.ktan')],
          subject: 'KanjiKi Backup');
      return;
    }
    final dbPath = join(await getDatabasesPath(), "kanji.db");
    final tempDir = await getTemporaryDirectory();
    final exportPath = join(tempDir.path, "kanjiki_backup.ktan");
    await io.File(dbPath).copy(exportPath);
    await Share.shareXFiles([XFile(exportPath)], subject: 'KanjiKi Backup');
  }

  static Future<void> importDatabase() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null) {
      if (kIsWeb) {
        if (result.files.single.bytes != null) {
          await db.close();
          await databaseFactoryFfiWeb.writeDatabaseBytes(
              'kanji.db', result.files.single.bytes!);
          db = await databaseFactoryFfiWeb.openDatabase('kanji.db');
        }
      } else {
        if (result.files.single.path != null) {
          String importedPath = result.files.single.path!;
          await db.close();
          final dbPath = join(await getDatabasesPath(), "kanji.db");
          await io.File(importedPath).copy(dbPath);
          db = await openDatabase(dbPath);
        }
      }
    }
  }

  static Future<void> updateKanjiInfo(Kanji k) async {
    await db.update(
      'kanji',
      {
        'meanings': k.meanings,
        'readings': k.readings,
        'updated_at': DateTime.now().millisecondsSinceEpoch
      },
      where: 'id = ?',
      whereArgs: [k.id],
    );
  }

  static Future<List<Kanji>> getCardsForDeck(String deckId) async {
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT kanji.*, dc.deck_id, dc.due_date, dc.ease_factor, dc.interval_days, dc.reps, dc.updated_at FROM kanji 
      INNER JOIN deck_cards dc ON kanji.id = dc.kanji_id
      WHERE dc.deck_id = ? AND dc.is_deleted = 0
    ''', [deckId]);
    return maps.map((m) => Kanji.fromMap(m)).toList();
  }

  static Future<void> clearUserData() async {
    await db.transaction((txn) async {
      await txn.delete('decks');
      await txn.delete('deck_cards');
      await txn.delete('review_logs');
      await txn.update(
        'kanji',
        {
          'updated_at': 0,
        },
      );
    });
  }
}

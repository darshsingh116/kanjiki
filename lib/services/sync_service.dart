import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'db_service.dart';

enum SyncStrategy {
  merge,
  overrideCloudWithLocal,
  overrideLocalWithCloud,
}

class SyncService {
  static final ValueNotifier<bool> syncNotifier = ValueNotifier(false);
  static final ValueNotifier<double> syncProgress = ValueNotifier(0.0);
  static final ValueNotifier<String> syncStatus = ValueNotifier("");
  static bool _isSyncing = false;

  /// Checks whether there are un-synced local changes waiting to be pushed to Supabase.
  static Future<bool> hasPendingLocalChanges() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final syncKey = 'last_sync_$userId';
    final int lastSync = prefs.getInt(syncKey) ?? 0;

    final db = DbService.db;

    // Check for updated decks
    final localDecks = await db.query(
      'decks',
      where: 'updated_at > ?',
      whereArgs: [lastSync],
      limit: 1,
    );
    if (localDecks.isNotEmpty) return true;

    // Check for updated deck cards / progress
    final localCards = await db.query(
      'deck_cards',
      where: lastSync == 0
          ? 'reps > 0 OR due_date IS NOT NULL OR updated_at > 0'
          : 'updated_at > ?',
      whereArgs: lastSync == 0 ? null : [lastSync],
      limit: 1,
    );
    if (localCards.isNotEmpty) return true;

    // Check for updated review logs
    final localLogs = await db.query(
      'review_logs',
      where: 'updated_at > ?',
      whereArgs: [lastSync],
      limit: 1,
    );
    if (localLogs.isNotEmpty) return true;

    return false;
  }

  /// Formats raw exception strings into user-friendly error messages.
  static String formatSyncErrorMessage(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network is unreachable') ||
        str.contains('connection refused') ||
        str.contains('no address associated with hostname') ||
        str.contains('clientexception') ||
        str.contains('failed to fetch') ||
        str.contains('networkerror') ||
        str.contains('xmlhttprequest error') ||
        str.contains('connection closed before full header was received') ||
        str.contains('connection reset by peer') ||
        str.contains('handshakeexception') ||
        str.contains('os error') ||
        str.contains('no route to host') ||
        str.contains('connection aborted')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (str.contains('timeoutexception') ||
        str.contains('timed out') ||
        str.contains('timeout') ||
        str.contains('deadline exceeded')) {
      return 'Connection timed out. The server took too long to respond. Please check your internet connection and try again.';
    }
    if (str.contains('jwt') ||
        str.contains('unauthorized') ||
        str.contains('invalid token') ||
        str.contains('session_not_found') ||
        str.contains('pgrst301')) {
      return 'Authentication expired. Please sign out and sign in again.';
    }
    return error.toString();
  }

  /// Full synchronization between local SQLite and cloud Supabase.
  /// If [forcedStrategy] is provided, it skips the conflict resolution prompt.
  static Future<void> syncData(
    BuildContext context, {
    bool showDialogUI = true,
    SyncStrategy? forcedStrategy,
  }) async {
    if (!SupabaseService.isAuthenticated) {
      if (context.mounted && showDialogUI) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text("Please sign in to sync your data.")),
        );
      }
      return;
    }

    if (_isSyncing) return;
    _isSyncing = true;

    bool dialogShown = false;

    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      final prefs = await SharedPreferences.getInstance();
      final syncKey = 'last_sync_$userId';
      final int lastSync = prefs.getInt(syncKey) ?? 0;

      // 1. Pre-fetch counts to check for conflict if strategy not predetermined
      SyncStrategy strategy = forcedStrategy ?? SyncStrategy.merge;

      if (forcedStrategy == null && context.mounted) {
        // Query cloud and local delta counts with network timeout
        final cloudDecksCount = await SupabaseService.client
            .from('decks')
            .count()
            .eq('user_id', userId)
            .gt('updated_at', lastSync)
            .timeout(const Duration(seconds: 15));
        final cloudCardsCount = await SupabaseService.client
            .from('deck_cards')
            .count()
            .eq('user_id', userId)
            .gt('updated_at', lastSync)
            .timeout(const Duration(seconds: 15));

        final db = DbService.db;
        final localDecksRes = await db.query(
          'decks',
          where: 'updated_at > ?',
          whereArgs: [lastSync],
          columns: ['id'],
        );
        final localCardsRes = await db.query(
          'deck_cards',
          where: lastSync == 0
              ? 'reps > 0 OR due_date IS NOT NULL OR updated_at > 0'
              : 'updated_at > ?',
          whereArgs: lastSync == 0 ? null : [lastSync],
          columns: ['deck_id', 'kanji_id'],
        );

        final int cDecks = cloudDecksCount;
        final int cCards = cloudCardsCount;
        final hasCloud = (cDecks + cCards) > 0;
        final hasLocal = (localDecksRes.length + localCardsRes.length) > 0;

        // If both sides have diverged since last sync, prompt the user for preferred strategy
        if (hasCloud && hasLocal && context.mounted) {
          _isSyncing = false; // release lock for dialog
          final chosenStrategy = await _showConflictResolutionDialog(
            context,
            localCount: localDecksRes.length + localCardsRes.length,
            cloudCount: cDecks + cCards,
          );
          if (chosenStrategy == null) return; // User cancelled
          _isSyncing = true;
          strategy = chosenStrategy;
        }
      }

      // 2. Show Progress Dialog
      if (showDialogUI && context.mounted) {
        syncProgress.value = 0.0;
        syncStatus.value = "Preparing sync...";
        dialogShown = true;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2D2D44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.sync, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text("Syncing Data", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: syncStatus,
                    builder: (context, status, child) {
                      return Text(status, style: const TextStyle(color: Colors.white70, fontSize: 14));
                    },
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<double>(
                    valueListenable: syncProgress,
                    builder: (context, progress, child) {
                      return LinearProgressIndicator(
                        value: progress <= 0 ? null : progress,
                        backgroundColor: Colors.white24,
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(4),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      }

      // 3. Execute selected sync strategy
      final syncStartTime = DateTime.now().millisecondsSinceEpoch;
      int downCount = 0;
      int upCount = 0;

      try {
        switch (strategy) {
          case SyncStrategy.overrideCloudWithLocal:
            final res = await _executeOverrideCloudWithLocal(userId, syncStartTime);
            upCount = res;
            break;
          case SyncStrategy.overrideLocalWithCloud:
            final res = await _executeOverrideLocalWithCloud(userId, syncStartTime);
            downCount = res;
            break;
          case SyncStrategy.merge:
            final res = await _executeMergeSync(userId, lastSync, syncStartTime);
            downCount = res.down;
            upCount = res.up;
            break;
        }

        // 4. Update sync cursor
        await prefs.setInt(syncKey, syncStartTime);
        try {
          await SupabaseService.client.from('user_sync_state').upsert({
            'user_id': userId,
            'last_sync_ms': syncStartTime,
            'updated_at': syncStartTime,
          }, onConflict: 'user_id').timeout(const Duration(seconds: 10));
        } catch (_) {}

        syncProgress.value = 1.0;

        // Close dialog
        if (dialogShown && context.mounted) {
          Navigator.pop(context);
          dialogShown = false;
        }

        // Notify UI
        syncNotifier.value = !syncNotifier.value;

        if (context.mounted && showDialogUI) {
          final String msg;
          if (strategy == SyncStrategy.overrideCloudWithLocal) {
            msg = "Cloud overridden with local data ($upCount items uploaded).";
          } else if (strategy == SyncStrategy.overrideLocalWithCloud) {
            msg = "Local overridden with cloud data ($downCount items downloaded).";
          } else if (downCount == 0 && upCount == 0) {
            msg = "All items already up to date!";
          } else {
            msg = "Sync complete: ↓$downCount downloaded, ↑$upCount uploaded.";
          }

          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (err) {
        if (dialogShown && context.mounted) {
          Navigator.pop(context);
          dialogShown = false;
        }

        // If merge failed due to conflict, offer override options to recover
        if (strategy == SyncStrategy.merge && context.mounted) {
          final isNetwork = formatSyncErrorMessage(err).contains('internet') || formatSyncErrorMessage(err).contains('timed out');
          if (!isNetwork) {
            _isSyncing = false;
            final overrideChoice = await _showMergeFailedFallbackDialog(context, err.toString());
            if (overrideChoice != null && context.mounted) {
              await syncData(context, showDialogUI: true, forcedStrategy: overrideChoice);
              return;
            }
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (dialogShown && context.mounted) {
        Navigator.pop(context);
        dialogShown = false;
      }
      if (context.mounted) {
        _showSyncErrorPopup(context, e);
      }
    } finally {
      _isSyncing = false;
    }
  }

  // --- Sync Strategies Implementations ---

  static Future<({int down, int up})> _executeMergeSync(
    String userId,
    int lastSync,
    int syncStartTime,
  ) async {
    syncStatus.value = "Fetching updates from cloud...";
    syncProgress.value = 0.15;

    // Fetch cloud updates with network timeout
    var cloudDecksQuery = SupabaseService.client.from('decks').select().eq('user_id', userId);
    var cloudCardsQuery = SupabaseService.client.from('deck_cards').select().eq('user_id', userId);
    var cloudReviewsQuery = SupabaseService.client.from('review_logs').select().eq('user_id', userId);

    if (lastSync > 0) {
      cloudDecksQuery = cloudDecksQuery.gt('updated_at', lastSync);
      cloudCardsQuery = cloudCardsQuery.gt('updated_at', lastSync);
      cloudReviewsQuery = cloudReviewsQuery.gt('updated_at', lastSync);
    }

    final results = await Future.wait([
      cloudDecksQuery.timeout(const Duration(seconds: 15)),
      cloudCardsQuery.timeout(const Duration(seconds: 15)),
      cloudReviewsQuery.timeout(const Duration(seconds: 15)),
    ]);
    final List<Map<String, dynamic>> cloudDecks = (results[0] as List).cast<Map<String, dynamic>>();
    final List<Map<String, dynamic>> cloudCards = (results[1] as List).cast<Map<String, dynamic>>();
    final List<Map<String, dynamic>> cloudReviews = (results[2] as List).cast<Map<String, dynamic>>();

    syncStatus.value = "Reading local updates...";
    syncProgress.value = 0.3;

    final db = DbService.db;
    final List<Map<String, dynamic>> localDecks = lastSync == 0
        ? (await db.query('decks')).toList()
        : (await db.query('decks', where: 'updated_at > ?', whereArgs: [lastSync])).toList();

    final List<Map<String, dynamic>> localCards = lastSync == 0
        ? (await db.query('deck_cards', where: 'reps > 0 OR due_date IS NOT NULL OR updated_at > 0')).toList()
        : (await db.query('deck_cards', where: 'updated_at > ?', whereArgs: [lastSync])).toList();

    final List<Map<String, dynamic>> localReviews = lastSync == 0
        ? (await db.query('review_logs')).toList()
        : (await db.query('review_logs', where: 'updated_at > ?', whereArgs: [lastSync])).toList();

    // Conflict Resolution: Last-Write-Wins
    final List<Map<String, dynamic>> decksToApplyLocally = [];
    final List<Map<String, dynamic>> decksToUpload = [];

    final Map<String, Map<String, dynamic>> localDecksById = {
      for (var d in localDecks) d['id'] as String: d
    };
    final Map<String, Map<String, dynamic>> cloudDecksById = {
      for (var d in cloudDecks) d['id'] as String: d
    };

    final allDeckIds = {...localDecksById.keys, ...cloudDecksById.keys};
    for (var deckId in allDeckIds) {
      final l = localDecksById[deckId];
      final c = cloudDecksById[deckId];
      if (l != null && c != null) {
        final lTime = (l['updated_at'] as num?)?.toInt() ?? 0;
        final cTime = (c['updated_at'] as num?)?.toInt() ?? 0;
        if (lTime >= cTime) {
          decksToUpload.add(l);
        } else {
          decksToApplyLocally.add(c);
        }
      } else if (l != null) {
        decksToUpload.add(l);
      } else if (c != null) {
        decksToApplyLocally.add(c);
      }
    }

    final List<Map<String, dynamic>> cardsToApplyLocally = [];
    final List<Map<String, dynamic>> cardsToUpload = [];

    final Map<String, Map<String, dynamic>> localCardsByKey = {
      for (var c in localCards) "${c['deck_id']}_${c['kanji_id']}": c
    };
    final Map<String, Map<String, dynamic>> cloudCardsByKey = {
      for (var c in cloudCards) "${c['deck_id']}_${c['kanji_id']}": c
    };

    final allCardKeys = {...localCardsByKey.keys, ...cloudCardsByKey.keys};
    for (var key in allCardKeys) {
      final l = localCardsByKey[key];
      final c = cloudCardsByKey[key];
      if (l != null && c != null) {
        final lTime = (l['updated_at'] as num?)?.toInt() ?? 0;
        final cTime = (c['updated_at'] as num?)?.toInt() ?? 0;
        if (lTime >= cTime) {
          cardsToUpload.add(l);
        } else {
          cardsToApplyLocally.add(c);
        }
      } else if (l != null) {
        cardsToUpload.add(l);
      } else if (c != null) {
        cardsToApplyLocally.add(c);
      }
    }

    final List<Map<String, dynamic>> reviewsToApplyLocally = cloudReviews;
    final List<Map<String, dynamic>> reviewsToUpload = localReviews;

    int totalDownload = decksToApplyLocally.length + cardsToApplyLocally.length + reviewsToApplyLocally.length;
    int totalUpload = decksToUpload.length + cardsToUpload.length + reviewsToUpload.length;

    // Apply downloads in single SQLite transaction
    if (totalDownload > 0) {
      syncStatus.value = "Applying $totalDownload updates locally...";
      syncProgress.value = 0.5;

      await db.transaction((txn) async {
        for (var d in decksToApplyLocally) {
          final deckId = d['id'] as String;
          final isDeleted = (d['is_deleted'] == true || d['is_deleted'] == 1) ? 1 : 0;
          final updatedAt = (d['updated_at'] as num?)?.toInt() ?? syncStartTime;
          final frontMode = d['front_mode'] ?? 'both';
          final newLimit = (d['new_limit'] as num?)?.toInt() ?? 20;
          final reviewLimit = (d['review_limit'] as num?)?.toInt() ?? 200;

          final existing = await txn.query('decks', where: 'id = ?', whereArgs: [deckId], limit: 1);
          if (existing.isEmpty) {
            await txn.insert('decks', {
              'id': deckId,
              'name': d['name'] ?? 'Deck',
              'front_mode': frontMode,
              'new_limit': newLimit,
              'review_limit': reviewLimit,
              'is_deleted': isDeleted,
              'updated_at': updatedAt,
            });
          } else {
            await txn.update('decks', {
              'name': d['name'] ?? 'Deck',
              'front_mode': frontMode,
              'new_limit': newLimit,
              'review_limit': reviewLimit,
              'is_deleted': isDeleted,
              'updated_at': updatedAt,
            }, where: 'id = ?', whereArgs: [deckId]);
          }
        }

        for (var c in cardsToApplyLocally) {
          final deckId = c['deck_id'] as String;
          final kanjiId = (c['kanji_id'] as num).toInt();
          final isDeleted = (c['is_deleted'] == true || c['is_deleted'] == 1) ? 1 : 0;
          final updatedAt = (c['updated_at'] as num?)?.toInt() ?? syncStartTime;

          final existing = await txn.query(
            'deck_cards',
            where: 'deck_id = ? AND kanji_id = ?',
            whereArgs: [deckId, kanjiId],
            limit: 1,
          );

          if (existing.isEmpty) {
            await txn.insert('deck_cards', {
              'deck_id': deckId,
              'kanji_id': kanjiId,
              'due_date': c['due_date'],
              'ease_factor': (c['ease_factor'] as num?)?.toDouble() ?? 2.5,
              'interval_days': (c['interval_days'] as num?)?.toDouble() ?? 0.0,
              'reps': (c['reps'] as num?)?.toInt() ?? 0,
              'is_deleted': isDeleted,
              'updated_at': updatedAt,
            });
          } else {
            await txn.update('deck_cards', {
              'due_date': c['due_date'],
              'ease_factor': (c['ease_factor'] as num?)?.toDouble() ?? 2.5,
              'interval_days': (c['interval_days'] as num?)?.toDouble() ?? 0.0,
              'reps': (c['reps'] as num?)?.toInt() ?? 0,
              'is_deleted': isDeleted,
              'updated_at': updatedAt,
            }, where: 'deck_id = ? AND kanji_id = ?', whereArgs: [deckId, kanjiId]);
          }
        }

        for (var r in reviewsToApplyLocally) {
          final logId = r['id'] as String;
          final updatedAt = (r['updated_at'] as num?)?.toInt() ?? syncStartTime;
          final existing = await txn.query('review_logs', where: 'id = ?', whereArgs: [logId], limit: 1);
          if (existing.isEmpty) {
            await txn.insert('review_logs', {
              'id': logId,
              'kanji_id': r['kanji_id'],
              'deck_id': r['deck_id'],
              'type': r['type'] ?? 'review',
              'date_str': r['date_str'] ?? DateTime.now().toIso8601String().split('T')[0],
              'is_deleted': 0,
              'updated_at': updatedAt,
            });
          }
        }
      });
    }

    // Apply uploads in chunked batches
    if (totalUpload > 0) {
      syncStatus.value = "Uploading $totalUpload changes to cloud...";
      syncProgress.value = 0.75;

      if (decksToUpload.isNotEmpty) {
        final payload = decksToUpload.map((d) => {
          'id': d['id'],
          'user_id': userId,
          'name': d['name'],
          'front_mode': d['front_mode'] ?? 'both',
          'deck_type': 'custom',
          'new_limit': (d['new_limit'] as num?)?.toInt() ?? 20,
          'review_limit': (d['review_limit'] as num?)?.toInt() ?? 200,
          'is_deleted': (d['is_deleted'] == 1 || d['is_deleted'] == true),
          'updated_at': (d['updated_at'] as num?)?.toInt() ?? syncStartTime,
        }).toList();

        for (var batch in _chunk(payload, 100)) {
          await SupabaseService.client.from('decks').upsert(batch, onConflict: 'id').timeout(const Duration(seconds: 15));
        }
      }

      if (cardsToUpload.isNotEmpty) {
        final payload = cardsToUpload.map((c) => {
          'deck_id': c['deck_id'],
          'kanji_id': c['kanji_id'],
          'user_id': userId,
          'due_date': c['due_date'],
          'ease_factor': (c['ease_factor'] as num?)?.toDouble() ?? 2.5,
          'interval_days': (c['interval_days'] as num?)?.toDouble() ?? 0.0,
          'reps': (c['reps'] as num?)?.toInt() ?? 0,
          'is_deleted': (c['is_deleted'] == 1 || c['is_deleted'] == true),
          'updated_at': (c['updated_at'] as num?)?.toInt() ?? syncStartTime,
        }).toList();

        for (var batch in _chunk(payload, 250)) {
          await SupabaseService.client.from('deck_cards').upsert(batch, onConflict: 'deck_id, kanji_id').timeout(const Duration(seconds: 15));
        }
      }

      if (reviewsToUpload.isNotEmpty) {
        final payload = reviewsToUpload.map((r) => {
          'id': r['id'],
          'user_id': userId,
          'deck_id': r['deck_id'],
          'kanji_id': r['kanji_id'],
          'type': r['type'] ?? 'review',
          'date_str': r['date_str'],
          'updated_at': (r['updated_at'] as num?)?.toInt() ?? syncStartTime,
        }).toList();

        for (var batch in _chunk(payload, 250)) {
          await SupabaseService.client.from('review_logs').upsert(batch, onConflict: 'id').timeout(const Duration(seconds: 15));
        }
      }
    }

    return (down: totalDownload, up: totalUpload);
  }

  /// Replaces cloud data entirely with this local device's data.
  static Future<int> _executeOverrideCloudWithLocal(String userId, int syncStartTime) async {
    syncStatus.value = "Clearing cloud user tables...";
    syncProgress.value = 0.2;

    // Delete existing cloud user records with timeout
    await SupabaseService.client.from('review_logs').delete().eq('user_id', userId).timeout(const Duration(seconds: 15));
    await SupabaseService.client.from('deck_cards').delete().eq('user_id', userId).timeout(const Duration(seconds: 15));
    await SupabaseService.client.from('decks').delete().eq('user_id', userId).timeout(const Duration(seconds: 15));

    syncStatus.value = "Uploading all local data to cloud...";
    syncProgress.value = 0.5;

    final db = DbService.db;
    final localDecks = await db.query('decks');
    final localCards = await db.query('deck_cards');
    final localLogs = await db.query('review_logs');

    if (localDecks.isNotEmpty) {
      final payload = localDecks.map((d) => {
        'id': d['id'],
        'user_id': userId,
        'name': d['name'],
        'front_mode': d['front_mode'] ?? 'both',
        'deck_type': 'custom',
        'new_limit': (d['new_limit'] as num?)?.toInt() ?? 20,
        'review_limit': (d['review_limit'] as num?)?.toInt() ?? 200,
        'is_deleted': (d['is_deleted'] == 1 || d['is_deleted'] == true),
        'updated_at': syncStartTime,
      }).toList();

      for (var batch in _chunk(payload, 100)) {
        await SupabaseService.client.from('decks').insert(batch).timeout(const Duration(seconds: 15));
      }
    }

    if (localCards.isNotEmpty) {
      final payload = localCards.map((c) => {
        'deck_id': c['deck_id'],
        'kanji_id': c['kanji_id'],
        'user_id': userId,
        'due_date': c['due_date'],
        'ease_factor': (c['ease_factor'] as num?)?.toDouble() ?? 2.5,
        'interval_days': (c['interval_days'] as num?)?.toDouble() ?? 0.0,
        'reps': (c['reps'] as num?)?.toInt() ?? 0,
        'is_deleted': (c['is_deleted'] == 1 || c['is_deleted'] == true),
        'updated_at': syncStartTime,
      }).toList();

      for (var batch in _chunk(payload, 250)) {
        await SupabaseService.client.from('deck_cards').insert(batch).timeout(const Duration(seconds: 15));
      }
    }

    if (localLogs.isNotEmpty) {
      final payload = localLogs.map((r) => {
        'id': r['id'],
        'user_id': userId,
        'deck_id': r['deck_id'],
        'kanji_id': r['kanji_id'],
        'type': r['type'] ?? 'review',
        'date_str': r['date_str'],
        'updated_at': syncStartTime,
      }).toList();

      for (var batch in _chunk(payload, 250)) {
        await SupabaseService.client.from('review_logs').insert(batch).timeout(const Duration(seconds: 15));
      }
    }

    return localDecks.length + localCards.length + localLogs.length;
  }

  /// Replaces local data entirely with cloud data.
  static Future<int> _executeOverrideLocalWithCloud(String userId, int syncStartTime) async {
    syncStatus.value = "Fetching all cloud data...";
    syncProgress.value = 0.3;

    final results = await Future.wait([
      SupabaseService.client.from('decks').select().eq('user_id', userId).timeout(const Duration(seconds: 15)),
      SupabaseService.client.from('deck_cards').select().eq('user_id', userId).timeout(const Duration(seconds: 15)),
      SupabaseService.client.from('review_logs').select().eq('user_id', userId).timeout(const Duration(seconds: 15)),
    ]);

    final List<Map<String, dynamic>> cloudDecks = (results[0] as List).cast<Map<String, dynamic>>();
    final List<Map<String, dynamic>> cloudCards = (results[1] as List).cast<Map<String, dynamic>>();
    final List<Map<String, dynamic>> cloudReviews = (results[2] as List).cast<Map<String, dynamic>>();

    syncStatus.value = "Overwriting local database...";
    syncProgress.value = 0.6;

    final db = DbService.db;
    await db.transaction((txn) async {
      await txn.delete('review_logs');
      await txn.delete('deck_cards');
      await txn.delete('decks');

      for (var d in cloudDecks) {
        await txn.insert('decks', {
          'id': d['id'],
          'name': d['name'] ?? 'Deck',
          'front_mode': d['front_mode'] ?? 'both',
          'new_limit': (d['new_limit'] as num?)?.toInt() ?? 20,
          'review_limit': (d['review_limit'] as num?)?.toInt() ?? 200,
          'is_deleted': (d['is_deleted'] == true || d['is_deleted'] == 1) ? 1 : 0,
          'updated_at': (d['updated_at'] as num?)?.toInt() ?? syncStartTime,
        });
      }

      for (var c in cloudCards) {
        await txn.insert('deck_cards', {
          'deck_id': c['deck_id'],
          'kanji_id': c['kanji_id'],
          'due_date': c['due_date'],
          'ease_factor': (c['ease_factor'] as num?)?.toDouble() ?? 2.5,
          'interval_days': (c['interval_days'] as num?)?.toDouble() ?? 0.0,
          'reps': (c['reps'] as num?)?.toInt() ?? 0,
          'is_deleted': (c['is_deleted'] == true || c['is_deleted'] == 1) ? 1 : 0,
          'updated_at': (c['updated_at'] as num?)?.toInt() ?? syncStartTime,
        });
      }

      for (var r in cloudReviews) {
        await txn.insert('review_logs', {
          'id': r['id'],
          'kanji_id': r['kanji_id'],
          'deck_id': r['deck_id'],
          'type': r['type'] ?? 'review',
          'date_str': r['date_str'] ?? DateTime.now().toIso8601String().split('T')[0],
          'is_deleted': 0,
          'updated_at': (r['updated_at'] as num?)?.toInt() ?? syncStartTime,
        });
      }
    });

    return cloudDecks.length + cloudCards.length + cloudReviews.length;
  }

  // --- Dialog Helpers ---

  static Future<SyncStrategy?> _showConflictResolutionDialog(
    BuildContext context, {
    required int localCount,
    required int cloudCount,
  }) async {
    return showDialog<SyncStrategy>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.compare_arrows, color: Colors.orangeAccent),
              SizedBox(width: 10),
              Text("Sync Conflict Detected", style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Both your local device ($localCount updates) and cloud ($cloudCount updates) have changes since last sync.\n\nHow would you like to resolve this?",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.merge_type, color: Colors.blueAccent),
                title: const Text("Auto-Merge (Recommended)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Combines all decks & keeps latest card progress", style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, SyncStrategy.merge),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_upload_outlined, color: Colors.greenAccent),
                title: const Text("Override Cloud with Local", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Replaces cloud database with this device's data", style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, SyncStrategy.overrideCloudWithLocal),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_download_outlined, color: Colors.purpleAccent),
                title: const Text("Override Local with Cloud", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Replaces this device's data with cloud database", style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, SyncStrategy.overrideLocalWithCloud),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  static Future<SyncStrategy?> _showMergeFailedFallbackDialog(BuildContext context, String error) async {
    return showDialog<SyncStrategy>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("Merge Conflict", style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Automatic merge encountered a conflict:\n$error\n\nPlease select an override option to resolve:",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_upload_outlined, color: Colors.greenAccent),
                title: const Text("Override Cloud with Local", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Force push this device's data to cloud", style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, SyncStrategy.overrideCloudWithLocal),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_download_outlined, color: Colors.purpleAccent),
                title: const Text("Override Local with Cloud", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Force pull cloud data to replace local", style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, SyncStrategy.overrideLocalWithCloud),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  static void _showSyncErrorPopup(BuildContext context, dynamic error) {
    final friendlyMsg = formatSyncErrorMessage(error);
    final isNetwork = friendlyMsg.contains('internet') ||
        friendlyMsg.contains('timed out') ||
        friendlyMsg.contains('network');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isNetwork ? Icons.wifi_off : Icons.error_outline,
              color: Colors.redAccent,
              size: 24,
            ),
            const SizedBox(width: 10),
            const Text("Sync Failed", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              friendlyMsg,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            if (!isNetwork) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: error.toString()));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Details copied to clipboard!'), duration: Duration(seconds: 1)),
                  );
                },
                child: Text(
                  "Details: ${error.toString()}\n(Tap to copy)",
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  static Iterable<List<T>> _chunk<T>(List<T> lst, int chunkSize) sync* {
    for (var i = 0; i < lst.length; i += chunkSize) {
      yield lst.sublist(
        i,
        i + chunkSize > lst.length ? lst.length : i + chunkSize,
      );
    }
  }
}

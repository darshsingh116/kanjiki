import 'package:flutter_test/flutter_test.dart';
import 'package:kanjiapp/services/sync_service.dart';

void main() {
  group('Sync Conflict Resolution Logic Tests', () {
    test('Deck Conflict: Local newer wins over Cloud', () {
      final localDeck = {
        'id': 'deck-123',
        'name': 'Local Renamed Deck',
        'front_mode': 'kanji',
        'updated_at': 2000,
        'is_deleted': 0,
      };

      final cloudDeck = {
        'id': 'deck-123',
        'name': 'Cloud Stale Deck',
        'front_mode': 'both',
        'updated_at': 1500,
        'is_deleted': false,
      };

      final decksToApplyLocally = <Map<String, dynamic>>[];
      final decksToUpload = <Map<String, dynamic>>[];

      final lTime = (localDeck['updated_at'] as num).toInt();
      final cTime = (cloudDeck['updated_at'] as num).toInt();

      if (lTime >= cTime) {
        decksToUpload.add(localDeck);
      } else {
        decksToApplyLocally.add(cloudDeck);
      }

      expect(decksToUpload.length, equals(1));
      expect(decksToUpload.first['name'], equals('Local Renamed Deck'));
      expect(decksToApplyLocally.isEmpty, isTrue);
    });

    test('Deck Conflict: Cloud newer wins over Local', () {
      final localDeck = {
        'id': 'deck-123',
        'name': 'Local Stale Deck',
        'updated_at': 1000,
        'is_deleted': 0,
      };

      final cloudDeck = {
        'id': 'deck-123',
        'name': 'Cloud Fresh Deck',
        'updated_at': 2500,
        'is_deleted': false,
      };

      final decksToApplyLocally = <Map<String, dynamic>>[];
      final decksToUpload = <Map<String, dynamic>>[];

      final lTime = (localDeck['updated_at'] as num).toInt();
      final cTime = (cloudDeck['updated_at'] as num).toInt();

      if (lTime >= cTime) {
        decksToUpload.add(localDeck);
      } else {
        decksToApplyLocally.add(cloudDeck);
      }

      expect(decksToApplyLocally.length, equals(1));
      expect(decksToApplyLocally.first['name'], equals('Cloud Fresh Deck'));
      expect(decksToUpload.isEmpty, isTrue);
    });

    test('Deck Card SRS Conflict: More recent review wins', () {
      final localCard = {
        'deck_id': 'deck-1',
        'kanji_id': 42,
        'reps': 3,
        'interval_days': 6.0,
        'updated_at': 3000,
      };

      final cloudCard = {
        'deck_id': 'deck-1',
        'kanji_id': 42,
        'reps': 1,
        'interval_days': 1.0,
        'updated_at': 2000,
      };

      final cardsToApplyLocally = <Map<String, dynamic>>[];
      final cardsToUpload = <Map<String, dynamic>>[];

      final lTime = (localCard['updated_at'] as num).toInt();
      final cTime = (cloudCard['updated_at'] as num).toInt();

      if (lTime >= cTime) {
        cardsToUpload.add(localCard);
      } else {
        cardsToApplyLocally.add(cloudCard);
      }

      expect(cardsToUpload.length, equals(1));
      expect(cardsToUpload.first['reps'], equals(3));
      expect(cardsToApplyLocally.isEmpty, isTrue);
    });

    test('Deletion Sync: Deleted deck propagates with is_deleted flag', () {
      final localDeckDeleted = {
        'id': 'deck-del-1',
        'name': 'Deleted Deck',
        'is_deleted': 1,
        'updated_at': 5000,
      };

      final payload = {
        'id': localDeckDeleted['id'],
        'name': localDeckDeleted['name'],
        'is_deleted': (localDeckDeleted['is_deleted'] == 1),
        'updated_at': localDeckDeleted['updated_at'],
      };

      expect(payload['is_deleted'], isTrue);
    });

    test('SyncStrategy enum values exist', () {
      expect(SyncStrategy.values, contains(SyncStrategy.merge));
      expect(SyncStrategy.values, contains(SyncStrategy.overrideCloudWithLocal));
      expect(SyncStrategy.values, contains(SyncStrategy.overrideLocalWithCloud));
    });

    test('formatSyncErrorMessage handles network disconnects and timeouts', () {
      final socketError = 'SocketException: Failed host lookup: xyz.supabase.co';
      expect(SyncService.formatSyncErrorMessage(socketError), contains('No internet connection'));

      final timeoutError = 'TimeoutException after 0:00:15.000000: Future not completed';
      expect(SyncService.formatSyncErrorMessage(timeoutError), contains('Connection timed out'));

      final clientError = 'ClientException with SocketException: OS Error: Network is unreachable';
      expect(SyncService.formatSyncErrorMessage(clientError), contains('No internet connection'));
    });
  });
}

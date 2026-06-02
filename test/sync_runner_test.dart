import 'dart:convert';

import 'package:erfasser_app/services/speicher_service.dart';
import 'package:erfasser_app/services/sync_adapter.dart';
import 'package:erfasser_app/services/sync_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Hilfsmethoden
// ---------------------------------------------------------------------------

Future<void> _insertEntry(String key,
    {String evnr = 'E001', String strasse = 'Testweg', String posNr = '1'}) async {
  await SpeicherService.upsertEntry(key, {
    'typ': 'DIV',
    'evnr': evnr,
    'strasse': strasse,
    'posNr': posNr,
  });
}

// ---------------------------------------------------------------------------
// Fehler-Adapter: lässt alle Keys fehlschlagen
// ---------------------------------------------------------------------------

class _AlwaysFailAdapter implements SyncAdapter {
  const _AlwaysFailAdapter();

  @override
  Future<SyncResult> pushChanges(
    Map<String, List<Map<String, dynamic>>> changesByEvNr,
  ) async {
    final failed = <String, String>{};
    for (final entries in changesByEvNr.values) {
      for (final entry in entries) {
        final key = entry['storageKey'] as String?;
        if (key != null) {
          failed[key] = 'Verbindungsfehler';
        }
      }
    }
    return SyncResult(syncedKeys: const [], failedKeys: failed);
  }

  @override
  Future<bool> testConnection() async => false;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // -------------------------------------------------------------------------
  // SyncAdapter / LocalNoOpSyncAdapter
  // -------------------------------------------------------------------------

  group('LocalNoOpSyncAdapter', () {
    test('pushChanges gibt alle Keys als synced zurück', () async {
      await _insertEntry('obj_E001_Testweg_1_DIV');

      final pending = await SpeicherService.loadPendingSyncChanges();
      expect(pending, isNotEmpty);

      const adapter = LocalNoOpSyncAdapter();
      final result = await adapter.pushChanges(pending);

      expect(result.hasErrors, isFalse);
      expect(result.syncedKeys, contains('obj_E001_Testweg_1_DIV'));
      expect(result.failedKeys, isEmpty);
    });

    test('testConnection gibt true zurück', () async {
      const adapter = LocalNoOpSyncAdapter();
      expect(await adapter.testConnection(), isTrue);
    });

    test('pushChanges mit leerem changesByEvNr liefert leeres SyncResult', () async {
      const adapter = LocalNoOpSyncAdapter();
      final result = await adapter.pushChanges({});
      expect(result.syncedKeys, isEmpty);
      expect(result.failedKeys, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // markSyncError und loadReadyToRetry
  // -------------------------------------------------------------------------

  group('markSyncError / loadReadyToRetry', () {
    test('markSyncError schreibt Fehlerfelder auf bestehenden Eintrag', () async {
      const key = 'obj_E001_Testweg_1_DIV';
      await _insertEntry(key);

      await SpeicherService.markSyncError(
        key: key,
        error: 'Timeout nach 30 s',
        retryCount: 1,
        backoff: const Duration(minutes: 10),
      );

      // decode via SpeicherService output
      final entries = await SpeicherService.ladeEintraegeFuerEvNr('E001',
          strasse: 'Testweg');
      expect(entries, hasLength(1));
      final entry = entries.first;
      expect(entry['syncRetryCount'], 1);
      expect(entry['lastSyncError'], 'Timeout nach 30 s');
      expect(entry['nextRetryAfter'], isNotNull);

      final nextRetry = DateTime.tryParse(entry['nextRetryAfter'] as String);
      expect(nextRetry, isNotNull);
      expect(nextRetry!.isAfter(DateTime.now()), isTrue);
    });

    test('loadReadyToRetry schließt Einträge mit zukünftigem nextRetryAfter aus', () async {
      const key = 'obj_E001_Testweg_1_DIV';
      await _insertEntry(key);

      // Backoff in der Zukunft setzen
      await SpeicherService.markSyncError(
        key: key,
        error: 'Fehler',
        retryCount: 1,
        backoff: const Duration(hours: 2),
      );

      final ready = await SpeicherService.loadReadyToRetry();
      expect(ready, isEmpty);
    });

    test('loadReadyToRetry liefert Einträge ohne nextRetryAfter sofort', () async {
      await _insertEntry('obj_E001_Testweg_1_DIV');

      final ready = await SpeicherService.loadReadyToRetry();
      expect(ready['E001'], hasLength(1));
    });

    test('loadReadyToRetry liefert Einträge mit vergangenem nextRetryAfter', () async {
      const key = 'obj_E001_Testweg_1_DIV';
      await _insertEntry(key);

      // Direkt Backoff in der Vergangenheit schreiben
      final prefs = await SharedPreferences.getInstance();
      final entries = await SpeicherService.ladeEintraegeFuerEvNr('E001',
          strasse: 'Testweg');
      final patchedEntry = Map<String, dynamic>.from(entries.first);
      patchedEntry['nextRetryAfter'] =
          DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String();
      await prefs.setString(key, jsonEncode(patchedEntry));

      final ready = await SpeicherService.loadReadyToRetry();
      expect(ready['E001'], hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // SyncRunner
  // -------------------------------------------------------------------------

  group('SyncRunner', () {
    test('SyncRunner mit NoOp-Adapter markiert alle Einträge als synced', () async {
      await _insertEntry('obj_E001_Testweg_1_DIV');
      await _insertEntry('obj_E001_Testweg_2_DIV',
          posNr: '2');

      final runner = SyncRunner(adapter: const LocalNoOpSyncAdapter());
      final result = await runner.run();

      expect(result.totalEntries, 2);
      expect(result.syncedCount, 2);
      expect(result.failedCount, 0);
      expect(result.hasErrors, isFalse);

      // Einträge sollten jetzt 'synced' sein
      final entries = await SpeicherService.ladeEintraegeFuerEvNr('E001',
          strasse: 'Testweg');
      for (final e in entries) {
        expect(e['syncStatus'], 'synced');
      }
    });

    test('SyncRunner mit immer-Fehler-Adapter schreibt Fehlerinfo', () async {
      await _insertEntry('obj_E001_Testweg_1_DIV');

      final runner = SyncRunner(
        adapter: const _AlwaysFailAdapter(),
        baseDuration: const Duration(seconds: 10),
      );
      final result = await runner.run();

      expect(result.failedCount, 1);
      expect(result.syncedCount, 0);
      expect(result.hasErrors, isTrue);

      // Eintrag sollte Fehlerinfo haben
      final entries = await SpeicherService.ladeEintraegeFuerEvNr('E001',
          strasse: 'Testweg');
      expect(entries.first['syncRetryCount'], 1);
      expect(entries.first['lastSyncError'], 'Verbindungsfehler');
      expect(entries.first['nextRetryAfter'], isNotNull);
    });

    test('SyncRunner läuft ohne Fehler bei leerem pending-Stand', () async {
      final runner = SyncRunner(adapter: const LocalNoOpSyncAdapter());
      final result = await runner.run();

      expect(result.totalEntries, 0);
      expect(result.syncedCount, 0);
      expect(result.failedCount, 0);
    });

    test('SyncRunner zweiter Lauf nach backoff überspringt noch-nicht-fällige Einträge',
        () async {
      const key = 'obj_E001_Testweg_1_DIV';
      await _insertEntry(key);

      // Ersten Lauf mit Fehler durchführen
      final runner = SyncRunner(
        adapter: const _AlwaysFailAdapter(),
        baseDuration: const Duration(hours: 1),
      );
      await runner.run();

      // Zweiten Lauf sofort – Eintrag darf noch nicht fällig sein
      final secondRun = SyncRunner(adapter: const LocalNoOpSyncAdapter());
      final result = await secondRun.run();

      expect(result.totalEntries, 0); // backoff noch aktiv
    });

    test('exponentieller Backoff erhöht sich mit jeder Retry', () async {
      const key = 'obj_E001_Testweg_1_DIV';
      await _insertEntry(key);

      final runner = SyncRunner(
        adapter: const _AlwaysFailAdapter(),
        baseDuration: const Duration(minutes: 5),
        maxDuration: const Duration(hours: 4),
      );

      // Ersten Fehler produzieren
      await runner.run();

      final entries = await SpeicherService.ladeEintraegeFuerEvNr('E001',
          strasse: 'Testweg');
      expect(entries.first['syncRetryCount'], 1);

      // nextRetryAfter sollte ~5 min in der Zukunft liegen (backoff für retry 1)
      final nextRetry =
          DateTime.parse(entries.first['nextRetryAfter'] as String);
      final diff = nextRetry.difference(DateTime.now());
      expect(diff.inSeconds, greaterThan(200)); // > 3 min 20 s (5 min - Toleranz)
    });
  });
}

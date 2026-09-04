/// SyncRunner: Orchestriert einen Sync-Zyklus.
///
/// Liest ausstehende Änderungen, übergibt sie an einen [SyncAdapter],
/// markiert erfolgreiche Einträge und speichert Fehlerinfo für Retry.
library;

import 'package:flutter/foundation.dart';

import 'speicher_service.dart';
import 'sync_adapter.dart';

/// Ergebnis eines vollständigen Sync-Laufs.
class SyncRunResult {
  final int totalEntries;
  final int syncedCount;
  final int failedCount;

  /// Fehlermeldungen nach Storage-Key.
  final Map<String, String> errors;

  const SyncRunResult({
    required this.totalEntries,
    required this.syncedCount,
    required this.failedCount,
    required this.errors,
  });

  bool get hasErrors => failedCount > 0;

  @override
  String toString() =>
      'SyncRunResult(total=$totalEntries, synced=$syncedCount, failed=$failedCount)';
}

/// Führt einen vollständigen Sync-Zyklus durch.
///
/// Ablauf:
/// 1. [SpeicherService.loadReadyToRetry] – liefert alle fälligen pending-Einträge.
/// 2. [SyncAdapter.pushChanges] – sendet an Zielsystem.
/// 3. [SpeicherService.markSyncedAndCleanup] – markiert erfolgreiche Einträge.
/// 4. [SpeicherService.markSyncError] – schreibt Fehler + Backoff für fehlgeschlagene.
class SyncRunner {
  final SyncAdapter adapter;

  /// Backoff-Strategie: [baseDuration] wird mit [2^(retryCount-1)] multipliziert,
  /// maximal [maxDuration].
  final Duration baseDuration;
  final Duration maxDuration;

  const SyncRunner({
    required this.adapter,
    this.baseDuration = const Duration(minutes: 5),
    this.maxDuration = const Duration(hours: 4),
  });

  /// Startet den Sync. Gibt [SyncRunResult] zurück.
  ///
  /// Wirft keine Exceptions: Adapter-Fehler werden pro-Key gespeichert.
  Future<SyncRunResult> run() async {
    Map<String, List<Map<String, dynamic>>> pending;
    try {
      pending = await SpeicherService.loadReadyToRetry();
    } catch (e) {
      debugPrint('[SyncRunner] Fehler beim Laden der pending Einträge: $e');
      return const SyncRunResult(
        totalEntries: 0,
        syncedCount: 0,
        failedCount: 0,
        errors: {},
      );
    }

    if (pending.isEmpty) {
      return const SyncRunResult(
        totalEntries: 0,
        syncedCount: 0,
        failedCount: 0,
        errors: {},
      );
    }

    final totalEntries = pending.values.fold(0, (sum, list) => sum + list.length);

    SyncResult adapterResult;
    try {
      adapterResult = await adapter.pushChanges(pending);
    } catch (e) {
      // Adapter hat eine unerwartete Exception geworfen – alle Keys als fehlgeschlagen markieren
      debugPrint('[SyncRunner] Adapter-Fehler: $e');
      final allKeys = <String>[];
      for (final entries in pending.values) {
        for (final entry in entries) {
          final key = entry['storageKey'] as String?;
          if (key != null) allKeys.add(key);
        }
      }
      final errorMsg = e.toString();
      for (final key in allKeys) {
        await _applyError(key: key, error: errorMsg, pending: pending);
      }
      return SyncRunResult(
        totalEntries: totalEntries,
        syncedCount: 0,
        failedCount: allKeys.length,
        errors: {for (final k in allKeys) k: errorMsg},
      );
    }

    // Erfolgreiche Keys bereinigen
    if (adapterResult.syncedKeys.isNotEmpty) {
      try {
        await SpeicherService.markSyncedAndCleanup(
          syncedKeys: adapterResult.syncedKeys,
        );
      } catch (e) {
        debugPrint('[SyncRunner] markSyncedAndCleanup fehlgeschlagen: $e');
      }
    }

    // Fehlgeschlagene Keys mit Backoff versehen
    for (final entry in adapterResult.failedKeys.entries) {
      await _applyError(
        key: entry.key,
        error: entry.value,
        pending: pending,
      );
    }

    return SyncRunResult(
      totalEntries: totalEntries,
      syncedCount: adapterResult.syncedKeys.length,
      failedCount: adapterResult.failedKeys.length,
      errors: adapterResult.failedKeys,
    );
  }

  /// Schreibt Fehlerinfo auf einen Key und berechnet exponentiellen Backoff.
  Future<void> _applyError({
    required String key,
    required String error,
    required Map<String, List<Map<String, dynamic>>> pending,
  }) async {
    // Aktuellen retryCount aus dem bereits geladenen Meta lesen
    int currentRetryCount = 0;
    outer:
    for (final entries in pending.values) {
      for (final entry in entries) {
        if (entry['storageKey'] == key) {
          final raw = entry['syncRetryCount'];
          if (raw is int) currentRetryCount = raw;
          break outer;
        }
      }
    }

    final nextRetryCount = currentRetryCount + 1;
    final backoffMultiplier =
        (1 << (nextRetryCount - 1)).clamp(1, 512); // 2^(n-1), max 512
    final backoff = Duration(
      microseconds: (baseDuration.inMicroseconds * backoffMultiplier)
          .clamp(baseDuration.inMicroseconds, maxDuration.inMicroseconds),
    );

    await SpeicherService.markSyncError(
      key: key,
      error: error,
      retryCount: nextRetryCount,
      backoff: backoff,
    );
  }
}

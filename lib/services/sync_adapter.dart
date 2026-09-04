/// Abstrakte Schnittstelle für Sync-Adapter.
///
/// Konkrete Implementierungen können später für OSIRIS, NIS, TraffX oder
/// andere Zielsysteme erstellt werden, sobald IT-Zugang und API-Schemata
/// vorliegen. Bis dahin steht [LocalNoOpSyncAdapter] für Tests bereit.
library;

/// Ergebnis eines Sync-Versuchs für einen einzelnen EVNr-Batch.
class SyncResult {
  /// Storage-Keys, die erfolgreich übertragen wurden.
  final List<String> syncedKeys;

  /// Storage-Keys, die fehlgeschlagen sind, mit Fehlerbeschreibung.
  final Map<String, String> failedKeys;

  const SyncResult({
    required this.syncedKeys,
    required this.failedKeys,
  });

  bool get hasErrors => failedKeys.isNotEmpty;

  @override
  String toString() =>
      'SyncResult(synced=${syncedKeys.length}, failed=${failedKeys.length})';
}

/// Abstrakte Schnittstelle für alle Sync-Adapter.
///
/// Ein Adapter erhält einen Batch von Änderungen (geordnet nach EVNr) und
/// gibt zurück, welche Keys erfolgreich übertragen wurden und welche nicht.
abstract class SyncAdapter {
  /// Sendet ausstehende Änderungen an das Zielsystem.
  ///
  /// [changesByEvNr] enthält für jede EVNr die Liste der Meta-Objekte
  /// (sowohl `pending` als auch `pending_delete` Einträge).
  ///
  /// Gibt ein [SyncResult] zurück, das angibt, welche [storageKey]-Werte
  /// übertragen wurden bzw. fehlgeschlagen sind.
  Future<SyncResult> pushChanges(
    Map<String, List<Map<String, dynamic>>> changesByEvNr,
  );

  /// Optionaler Verbindungstest. Gibt `true` zurück wenn das Zielsystem
  /// erreichbar ist. Standard-Implementierung gibt immer `false` zurück.
  Future<bool> testConnection() async => false;
}

/// Kein-Betrieb-Adapter für Tests und Offline-Modus.
///
/// Markiert alle übergebenen Einträge sofort als erfolgreich, ohne eine
/// echte Netzwerkverbindung herzustellen.
class LocalNoOpSyncAdapter implements SyncAdapter {
  const LocalNoOpSyncAdapter();

  @override
  Future<SyncResult> pushChanges(
    Map<String, List<Map<String, dynamic>>> changesByEvNr,
  ) async {
    final syncedKeys = <String>[];

    for (final entries in changesByEvNr.values) {
      for (final entry in entries) {
        final key = entry['storageKey'] as String?;
        if (key != null && key.isNotEmpty) {
          syncedKeys.add(key);
        }
      }
    }

    return SyncResult(syncedKeys: syncedKeys, failedKeys: const {});
  }

  @override
  Future<bool> testConnection() async => true;
}

import 'dart:convert';
// ...existing code...
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// SpeicherService: arbeitet primär mit Meta-JSON; direkte Model-Imports wurden
// entfernt, da die meisten Export-Funktionen meta-first arbeiten.

/// Service zum Laden aller gespeicherten Einträge aus SharedPreferences
class SpeicherService {
  static const String _syncStatusPending = 'pending';
  static const String _syncStatusPendingDelete = 'pending_delete';
  static const String _objectKeyPrefix = 'obj_';
  static const String _prefsWebPrefix = 'flutter.';
  static const String _deleteTombstonePrefix = 'deleted_obj_';
  static const List<String> _mediaFields = <String>[
    'mediaFotos',
    'mediaVideos',
    'mediaAudios',
    'mediaPdfs',
  ];

  static String _logicalPrefsKey(String key) {
    if (key.startsWith(_prefsWebPrefix)) {
      return key.substring(_prefsWebPrefix.length);
    }
    final objectMarker = '.$_objectKeyPrefix';
    final objectMarkerIndex = key.indexOf(objectMarker);
    if (objectMarkerIndex >= 0) {
      return key.substring(objectMarkerIndex + 1);
    }
    return key;
  }

  static bool _isObjectKey(String key) {
    return _logicalPrefsKey(key).startsWith(_objectKeyPrefix);
  }

  static bool _objectKeyStartsWith(String key, String prefix) {
    return _logicalPrefsKey(key).startsWith(prefix);
  }

  /// Lädt alle Einträge für eine bestimmte EVNr aus SharedPreferences
  static Future<List<Map<String, dynamic>>> ladeEintraegeFuerEvNr(
    String evnr, {
    String? strasse,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final results = <Map<String, dynamic>>[];

    // If a street is provided, try the per-EV/Street index first to avoid
    // scanning all SharedPreferences keys (important for Web/IndexedDB).
    if (strasse != null && strasse.isNotEmpty) {
      try {
        final indexKey = 'pos_index_${evnr}_$strasse';
        final posList = prefs.getStringList(indexKey);
        if (posList != null && posList.isNotEmpty) {
          final seenKeys = <String>{};
          for (final pos in posList) {
            final keyPrefix = 'obj_${evnr}_${strasse}_$pos';
            final matchingKeys = prefs.getKeys().where((key) {
              if (seenKeys.contains(key)) return false;
              final logicalKey = _logicalPrefsKey(key);
              if (logicalKey == keyPrefix) return true;
              return logicalKey.startsWith('${keyPrefix}_');
            }).toList();

            for (final candidateKey in matchingKeys) {
              try {
                final jsonStr = prefs.getString(candidateKey);
                if (jsonStr != null) {
                  final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
                  meta['storageKey'] = candidateKey;
                  results.add(meta);
                  seenKeys.add(candidateKey);
                }
              } catch (e) {
                debugPrint('Fehler beim Laden von $candidateKey: $e');
              }
            }
          }
        } else {
          // Index missing or empty: fall back to full scan to be robust
          final keys = prefs.getKeys();
          for (final key in keys) {
            if (_objectKeyStartsWith(key, 'obj_$evnr')) {
              try {
                final jsonStr = prefs.getString(key);
                if (jsonStr != null) {
                  final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
                  meta['storageKey'] =
                      key; // Speichere den Key für spätere Updates
                  results.add(meta);
                }
              } catch (e) {
                debugPrint('Fehler beim Laden von $key: $e');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Fehler beim Verwenden des Positionsindex: $e');
      }
    } else {
      // No street provided: full scan (backwards compatible behaviour)
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (_objectKeyStartsWith(key, 'obj_$evnr')) {
          try {
            final jsonStr = prefs.getString(key);
            if (jsonStr != null) {
              final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
              meta['storageKey'] = key; // Speichere den Key für spätere Updates
              results.add(meta);
            }
          } catch (e) {
            debugPrint('Fehler beim Laden von $key: $e');
          }
        }
      }
    }

    // Sortiere nach Positionsnummer
    results.sort((a, b) {
      final posA = a['posNr'] as String? ?? '';
      final posB = b['posNr'] as String? ?? '';
      return _comparePositions(posA, posB);
    });

    // Stelle sicher, dass jeder Eintrag eine posNr hat - für ältere Daten ohne posNr
    for (var i = 0; i < results.length; i++) {
      final entry = results[i];
      final posNr = entry['posNr'] as String? ?? '';
      if (posNr.isEmpty) {
        debugPrint(
          '[ladeEintraegeFuerEvNr] WARNUNG: Eintrag ohne posNr gefunden, setze auf Index.',
        );
        entry['posNr'] = (i + 1).toString();
      }
    }

    return results;
  }

  /// Lädt alle vorhandenen EVNr aus SharedPreferences
  static Future<List<String>> ladeAlleEvNr() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final evFromObjects = <String>{};

    // Schneller Start: Fuer die EVNr-Liste reicht der Speicher-Key.
    // Die Objekt-JSONs koennen gross sein, weil Medien darin stecken.
    for (final key in keys) {
      final logicalKey = _logicalPrefsKey(key);
      if (!logicalKey.startsWith(_objectKeyPrefix)) continue;
      final parts = logicalKey.split('_');
      if (parts.length < 2) continue;
      final evnr = parts[1].trim();
      if (evnr.isNotEmpty) {
        evFromObjects.add(evnr);
      }
    }

    final recentEvNr = prefs.getStringList('recent_evnr') ?? <String>[];
    final cleanedRecent = recentEvNr
        .where((evnr) => evnr.trim().isNotEmpty && evFromObjects.contains(evnr))
        .toList();
    if (cleanedRecent.length != recentEvNr.length) {
      await prefs.setStringList('recent_evnr', cleanedRecent);
    }

    final list = evFromObjects.toList();
    list.sort();
    return list;
  }

  /// Aktualisiert einen Eintrag in SharedPreferences
  static Future<void> updateEntry(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? oldMeta;
    try {
      final existing = prefs.getString(key);
      if (existing != null) {
        oldMeta = jsonDecode(existing) as Map<String, dynamic>;
      }
    } catch (_) {
      oldMeta = null;
    }

    final toStore = _withSyncState(
      Map<String, dynamic>.from(data),
      oldMeta: oldMeta,
      key: key,
    );
    await prefs.setString(key, jsonEncode(toStore));
  }

  /// Insert or update an entry and maintain the per-EV position index.
  /// Ensures the index `pos_index_<evnr>_<strasse>` contains the current posNr.
  static Future<void> upsertEntry(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // Read existing meta (if any) to cleanup old index entries when pos/ev/strasse change
    String? oldJson;
    try {
      oldJson = prefs.getString(key);
    } catch (_) {
      oldJson = null;
    }

    String? oldEv;
    String? oldStr;
    String? oldPos;
    Map<String, dynamic>? oldMeta;
    if (oldJson != null) {
      try {
        oldMeta = jsonDecode(oldJson) as Map<String, dynamic>;
        oldEv = oldMeta['evnr'] as String?;
        oldStr = oldMeta['strasse'] as String?;
        oldPos = oldMeta['posNr'] as String?;
      } catch (_) {}
    }

    // Ensure we store the storageKey on the saved meta
    final toStore = _withSyncState(
      Map<String, dynamic>.from(data),
      oldMeta: oldMeta,
      key: key,
    );

    await prefs.setString(key, jsonEncode(toStore));

    // Update index for the new meta
    try {
      final evnr = toStore['evnr'] as String?;
      final strasse = toStore['strasse'] as String?;
      final pos = toStore['posNr'] as String?;
      if (evnr != null && strasse != null && pos != null) {
        final indexKey = 'pos_index_${evnr}_$strasse';
        final list = prefs.getStringList(indexKey) ?? <String>[];
        if (!list.contains(pos)) {
          list.add(pos);
          await prefs.setStringList(indexKey, list);
        }
      }

      // If the entry moved EV/Strasse/Pos, remove it from the old index
      if (oldEv != null && oldStr != null && oldPos != null) {
        final oldIndex = 'pos_index_${oldEv}_$oldStr';
        final oldList = prefs.getStringList(oldIndex) ?? <String>[];
        if (oldList.contains(oldPos)) {
          oldList.remove(oldPos);
          await prefs.setStringList(oldIndex, oldList);
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Aktualisieren des Positionsindex: $e');
    }
  }

  /// Löscht einen Eintrag aus SharedPreferences
  static Future<void> deleteEntry(String key) async {
    final prefs = await SharedPreferences.getInstance();

    // Read meta first so we can cleanup the index reliably
    try {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
        final evnr = meta['evnr'] as String?;
        final strasse = meta['strasse'] as String?;
        final posNr = meta['posNr'] as String?;

        if (evnr != null && strasse != null && posNr != null) {
          final indexKey = 'pos_index_${evnr}_$strasse';
          final list = prefs.getStringList(indexKey) ?? <String>[];
          list.remove(posNr);
          await prefs.setStringList(indexKey, list);
        }

        await _writeDeleteTombstone(prefs, key: key, meta: meta);
      }
    } catch (e) {
      debugPrint('Fehler beim Löschen des Positionsindex: $e');
    }

    // Finally remove the stored meta
    try {
      await prefs.remove(key);
    } catch (e) {
      debugPrint('Fehler beim Entfernen des Eintrags $key: $e');
    }
  }

  static Future<void> _writeDeleteTombstone(
    SharedPreferences prefs, {
    required String key,
    required Map<String, dynamic> meta,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final previousVersion = meta['syncVersion'];
    final currentVersion = previousVersion is num ? previousVersion.toInt() : 0;
    final mediaBindings = (meta['mediaBindings'] is List)
        ? List<dynamic>.from(meta['mediaBindings'] as List)
        : <dynamic>[];
    final deletedMediaBindingIds = <String>{
      ..._normalizeStringList(meta['deletedMediaBindingIds']),
      ...mediaBindings
          .whereType<Map>()
          .map((binding) => _stringValue(binding['id']))
          .whereType<String>(),
    };

    final tombstone = <String, dynamic>{
      'storageKey': key,
      'deletedAt': nowIso,
      'syncStatus': _syncStatusPendingDelete,
      'lastLocalChangeAt': nowIso,
      'syncVersion': currentVersion + 1,
      'typ': meta['typ'],
      'evnr': meta['evnr'],
      'strasse': meta['strasse'],
      'posNr': meta['posNr'],
      'idNr': meta['idNr'],
      'deletedMediaBindingIds': deletedMediaBindingIds.toList()..sort(),
      'lastSyncedAt': meta['lastSyncedAt'],
    };

    await prefs.setString('$_deleteTombstonePrefix$key', jsonEncode(tombstone));
  }

  static Map<String, dynamic> _withSyncState(
    Map<String, dynamic> data, {
    Map<String, dynamic>? oldMeta,
    required String key,
  }) {
    final toStore = Map<String, dynamic>.from(data);
    final previousVersion = oldMeta?['syncVersion'];
    final currentVersion = previousVersion is num ? previousVersion.toInt() : 0;
    final nowIso = DateTime.now().toIso8601String();

    toStore['storageKey'] = key;
    toStore['syncStatus'] = _syncStatusPending;
    toStore['lastLocalChangeAt'] = nowIso;
    toStore['syncVersion'] = currentVersion + 1;
    _withGpsMetadata(toStore, oldMeta: oldMeta, nowIso: nowIso);
    _withMediaMetadata(toStore, oldMeta: oldMeta, key: key, nowIso: nowIso);

    if (oldMeta != null && oldMeta['lastSyncedAt'] != null) {
      toStore['lastSyncedAt'] = oldMeta['lastSyncedAt'];
    }

    return toStore;
  }

  static void _withGpsMetadata(
    Map<String, dynamic> toStore, {
    Map<String, dynamic>? oldMeta,
    required String nowIso,
  }) {
    Map<String, dynamic>? extractGps(Map<String, dynamic>? source) {
      if (source == null) return null;

      double? toDoubleValue(dynamic value) {
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value.replaceAll(',', '.'));
        return null;
      }

      num? toNumValue(dynamic value) {
        if (value is num) return value;
        if (value is String) return num.tryParse(value.replaceAll(',', '.'));
        return null;
      }

      final rawGps = source['gps'];
      if (rawGps is Map) {
        final gpsMap = Map<String, dynamic>.from(rawGps);
        final lat = toDoubleValue(
          gpsMap['lat'] ?? gpsMap['latitude'] ?? gpsMap['gpsLat'],
        );
        final lon = toDoubleValue(
          gpsMap['lon'] ?? gpsMap['lng'] ?? gpsMap['gpsLon'],
        );
        if (lat == null || lon == null) return null;

        return <String, dynamic>{
          'lat': lat,
          'lon': lon,
          if (toNumValue(
                gpsMap['accuracy_m'] ?? gpsMap['acc'] ?? gpsMap['accuracy'],
              ) !=
              null)
            'accuracy_m': toNumValue(
              gpsMap['accuracy_m'] ?? gpsMap['acc'] ?? gpsMap['accuracy'],
            ),
          'ts': (gpsMap['ts'] as String?) ?? nowIso,
        };
      }

      final lat = toDoubleValue(source['gpsLat'] ?? source['lat']);
      final lon = toDoubleValue(source['gpsLon'] ?? source['lon']);
      if (lat == null || lon == null) return null;

      return <String, dynamic>{
        'lat': lat,
        'lon': lon,
        if (toNumValue(source['gpsAcc']) != null)
          'accuracy_m': toNumValue(source['gpsAcc']),
        'ts': (source['gpsTs'] as String?) ?? nowIso,
      };
    }

    final normalizedGps = extractGps(toStore) ?? extractGps(oldMeta);
    if (normalizedGps != null) {
      toStore['gps'] = normalizedGps;
    }
  }

  static void _withMediaMetadata(
    Map<String, dynamic> toStore, {
    Map<String, dynamic>? oldMeta,
    required String key,
    required String nowIso,
  }) {
    final existingBindings = _groupBindingsByFieldAndValue(
      oldMeta?['mediaBindings'],
    );
    final nextBindings = <Map<String, dynamic>>[];
    final activeBindingIds = <String>{};

    for (final field in _mediaFields) {
      final values = _normalizeMediaValues(toStore[field]);
      toStore[field] = values;

      for (var index = 0; index < values.length; index++) {
        final value = values[index];
        final bindingKey = '$field\u0000$value';
        final reusable = existingBindings[bindingKey];
        final existing = reusable != null && reusable.isNotEmpty
            ? reusable.removeAt(0)
            : null;
        final bindingId =
            _stringValue(existing?['id']) ?? _newMediaBindingId(field, index);

        nextBindings.add(<String, dynamic>{
          'id': bindingId,
          'field': field,
          'kind': _mediaKindForField(field),
          'value': value,
          'objectKey': key,
          'createdAt': _stringValue(existing?['createdAt']) ?? nowIso,
          'updatedAt': nowIso,
        });
        activeBindingIds.add(bindingId);
      }
    }

    final deletedBindingIds = <String>{
      ..._normalizeStringList(oldMeta?['deletedMediaBindingIds']),
    };

    for (final queuedBindings in existingBindings.values) {
      for (final binding in queuedBindings) {
        final bindingId = _stringValue(binding['id']);
        if (bindingId != null && !activeBindingIds.contains(bindingId)) {
          deletedBindingIds.add(bindingId);
        }
      }
    }

    toStore['mediaBindings'] = nextBindings;
    toStore['deletedMediaBindingIds'] = deletedBindingIds.toList()..sort();
  }

  static Map<String, List<Map<String, dynamic>>> _groupBindingsByFieldAndValue(
    dynamic rawBindings,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    if (rawBindings is! List) {
      return grouped;
    }

    for (final raw in rawBindings) {
      if (raw is! Map) {
        continue;
      }

      final binding = Map<String, dynamic>.from(raw);
      final field = _stringValue(binding['field']);
      final value = _stringValue(binding['value']);
      if (field == null || value == null) {
        continue;
      }

      final bindingKey = '$field\u0000$value';
      grouped
          .putIfAbsent(bindingKey, () => <Map<String, dynamic>>[])
          .add(binding);
    }

    return grouped;
  }

  static List<String> _normalizeMediaValues(dynamic rawValues) {
    if (rawValues is List) {
      return rawValues
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    if (rawValues is String) {
      final value = rawValues.trim();
      return value.isEmpty ? <String>[] : <String>[value];
    }

    return <String>[];
  }

  static List<String> _normalizeStringList(dynamic rawValues) {
    if (rawValues is! List) {
      return <String>[];
    }

    return rawValues
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  static String _mediaKindForField(String field) {
    switch (field) {
      case 'mediaFotos':
        return 'foto';
      case 'mediaVideos':
        return 'video';
      case 'mediaAudios':
        return 'audio';
      case 'mediaPdfs':
        return 'pdf';
      default:
        return 'unbekannt';
    }
  }

  static String _newMediaBindingId(String field, int index) {
    return 'mb_${DateTime.now().microsecondsSinceEpoch}_${field}_$index';
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  /// Lädt alle ausstehenden Sync-Änderungen (pending oder pending_delete)
  /// grouped by EVNr für Batch-Übertragung oder Konflikt-Erkennung.
  static Future<Map<String, List<Map<String, dynamic>>>>
  loadPendingSyncChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final byEvNr = <String, List<Map<String, dynamic>>>{};

    final keys = prefs.getKeys().toList();

    for (final key in keys) {
      if (_isObjectKey(key)) {
        try {
          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
            final syncStatus = meta['syncStatus'] as String?;
            if (syncStatus == _syncStatusPending) {
              final evnr = meta['evnr'] as String?;
              if (evnr != null) {
                meta['storageKey'] = key;
                byEvNr
                    .putIfAbsent(evnr, () => <Map<String, dynamic>>[])
                    .add(meta);
              }
            }
          }
        } catch (_) {}
      } else if (key.startsWith(_deleteTombstonePrefix)) {
        try {
          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            final tombstone = jsonDecode(jsonStr) as Map<String, dynamic>;
            final syncStatus = tombstone['syncStatus'] as String?;
            if (syncStatus == _syncStatusPendingDelete) {
              final evnr = tombstone['evnr'] as String?;
              if (evnr != null) {
                byEvNr
                    .putIfAbsent(evnr, () => <Map<String, dynamic>>[])
                    .add(tombstone);
              }
            }
          }
        } catch (_) {}
      }
    }

    return byEvNr;
  }

  // ---------------------------------------------------------------------------
  // Retry / Fehler-Logik
  // ---------------------------------------------------------------------------

  /// Schreibt Fehlerinfo auf einen Eintrag nach einem fehlgeschlagenen Sync.
  ///
  /// [key] darf ein `obj_*`- oder `deleted_obj_*`-Key sein.
  /// [error] wird als lesbarer Fehlertext gespeichert.
  /// [retryCount] wird üblicherweise aus dem bestehenden Wert + 1 berechnet.
  /// [backoff] bestimmt, wie lange der Eintrag nicht erneut versucht wird.
  static Future<void> markSyncError({
    required String key,
    required String error,
    int retryCount = 1,
    Duration backoff = const Duration(minutes: 5),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) return;
      final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
      meta['syncRetryCount'] = retryCount;
      meta['lastSyncError'] = error;
      meta['nextRetryAfter'] = DateTime.now().add(backoff).toIso8601String();
      await prefs.setString(key, jsonEncode(meta));
    } catch (e) {
      debugPrint('markSyncError für $key fehlgeschlagen: $e');
    }
  }

  /// Gibt alle pending-Einträge zurück, deren [nextRetryAfter] in der
  /// Vergangenheit liegt (oder nicht gesetzt ist) – bereit für den nächsten
  /// Sync-Versuch.
  ///
  /// Das Ergebnis ist nach EVNr gruppiert, analog zu [loadPendingSyncChanges].
  static Future<Map<String, List<Map<String, dynamic>>>>
  loadReadyToRetry() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final byEvNr = <String, List<Map<String, dynamic>>>{};

    final keys = prefs.getKeys().toList();

    for (final key in keys) {
      final isObj = _isObjectKey(key);
      final isTombstone = key.startsWith(_deleteTombstonePrefix);
      if (!isObj && !isTombstone) continue;

      try {
        final jsonStr = prefs.getString(key);
        if (jsonStr == null) continue;
        final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
        final syncStatus = meta['syncStatus'] as String?;

        if (syncStatus != _syncStatusPending &&
            syncStatus != _syncStatusPendingDelete) {
          continue;
        }

        // Prüfe ob Backoff noch aktiv
        final nextRetryRaw = meta['nextRetryAfter'] as String?;
        if (nextRetryRaw != null) {
          final nextRetry = DateTime.tryParse(nextRetryRaw);
          if (nextRetry != null && nextRetry.isAfter(now)) {
            continue; // Noch nicht fällig
          }
        }

        final evnr = meta['evnr'] as String?;
        if (evnr != null) {
          meta['storageKey'] = key;
          byEvNr.putIfAbsent(evnr, () => <Map<String, dynamic>>[]).add(meta);
        }
      } catch (_) {}
    }

    return byEvNr;
  }

  // ---------------------------------------------------------------------------
  // Sync-Cleanup
  // ---------------------------------------------------------------------------

  /// Markiert Einträge als erfolgreich synchronisiert und entfernt alte Tombstones.
  /// [syncedKeys] = actual object storage keys that were successfully synced (can include pending_delete items)
  /// [retentionDays] = wie lange Tombstones aufbewahrt werden sollen für Konflikt-Erkennung (default 30 Tage)
  static Future<void> markSyncedAndCleanup({
    required List<String> syncedKeys,
    int retentionDays = 30,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    for (final key in syncedKeys) {
      if (_isObjectKey(key)) {
        try {
          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (meta['syncStatus'] == _syncStatusPending) {
              meta['syncStatus'] = 'synced';
              meta['lastSyncedAt'] = DateTime.now().toIso8601String();
              await prefs.setString(key, jsonEncode(meta));
            }
          }
        } catch (_) {}
      } else if (key.startsWith(_deleteTombstonePrefix)) {
        try {
          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            final tombstone = jsonDecode(jsonStr) as Map<String, dynamic>;
            tombstone['syncStatus'] = 'synced';
            tombstone['lastSyncedAt'] = DateTime.now().toIso8601String();
            await prefs.setString(key, jsonEncode(tombstone));
          }
        } catch (_) {}
      }
    }

    final cutoffTime = DateTime.now().subtract(Duration(days: retentionDays));
    final allKeys = prefs.getKeys().toList();
    for (final key in allKeys) {
      if (key.startsWith(_deleteTombstonePrefix)) {
        try {
          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            final tombstone = jsonDecode(jsonStr) as Map<String, dynamic>;
            final syncStatus = tombstone['syncStatus'] as String?;
            final lastSyncedAt = tombstone['lastSyncedAt'] as String?;

            if (syncStatus == 'synced' && lastSyncedAt != null) {
              final syncedDateTime = DateTime.tryParse(lastSyncedAt);
              if (syncedDateTime != null &&
                  !syncedDateTime.isAfter(cutoffTime)) {
                await prefs.remove(key);
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  /// Löscht alle Einträge für eine bestimmte EVNr
  static Future<void> deleteAllForEvNr(String evnr) async {
    final prefs = await SharedPreferences.getInstance();
    var keys = prefs.getKeys();

    final keysToDelete = keys.where((key) {
      if (!_isObjectKey(key)) return false;
      try {
        final jsonStr = prefs.getString(key);
        if (jsonStr == null) return false;
        final meta = jsonDecode(jsonStr) as Map<String, dynamic>;
        return meta['evnr'] == evnr;
      } catch (_) {
        return false;
      }
    }).toList();

    for (final key in keysToDelete) {
      await deleteEntry(key);
    }

    // Cleanup recent_evnr nach Löschen aller Einträge
    final recentEvNr = prefs.getStringList('recent_evnr') ?? <String>[];
    final cleanedRecent = recentEvNr.where((e) => e != evnr).toList();
    if (cleanedRecent.length != recentEvNr.length) {
      await prefs.setStringList('recent_evnr', cleanedRecent);
    }

    // Aktualisiere keys nach dem Löschen
    keys = prefs.getKeys();

    // Bereinige auch alle pos_index_ Einträge für diese EVNr
    final indexKeys = keys
        .where((key) => _logicalPrefsKey(key).startsWith('pos_index_$evnr'))
        .toList();
    debugPrint('[deleteAllForEvNr] Lösche ${indexKeys.length} Index-Keys');
    for (final indexKey in indexKeys) {
      await prefs.remove(indexKey);
    }

    // Entferne EVNr auch aus der recent_evnr Liste, damit sie nicht mehr angezeigt wird
    final recent = prefs.getStringList('recent_evnr') ?? <String>[];
    if (recent.contains(evnr)) {
      recent.removeWhere((e) => e == evnr);
      await prefs.setStringList('recent_evnr', recent);
    }
  }

  /// Vergleicht Positionsnummern (z.B. "1", "1a", "2", "10")
  static int _comparePositions(String a, String b) {
    final regExp = RegExp(r'^(\d+)([a-zA-Z]?)$');
    final matchA = regExp.firstMatch(a);
    final matchB = regExp.firstMatch(b);

    if (matchA == null && matchB == null) return a.compareTo(b);
    if (matchA == null) return 1;
    if (matchB == null) return -1;

    final numA = int.tryParse(matchA.group(1)!) ?? 0;
    final numB = int.tryParse(matchB.group(1)!) ?? 0;

    if (numA != numB) return numA.compareTo(numB);

    final letterA = matchA.group(2) ?? '';
    final letterB = matchB.group(2) ?? '';
    return letterA.compareTo(letterB);
  }

  /// Konvertiert ein Meta-Objekt zu einem BaseEntry (für Kompatibilität)
  // metaToBaseEntry entfernt: export-from-meta APIs verwenden intern eine
  // lokale Konvertierung oder arbeiten direkt mit den Meta-Feldern.

  /// Hilfsmethode: Erzeuge eine Feld-Map für Export/Steckbrief direkt aus
  /// dem gespeicherten Meta-JSON. Diese Map kann an
  /// `ExportService.buildEinzelFromFields` übergeben werden.
  static Map<String, String> metaToFields(
    Map<String, dynamic> meta, {
    String? erfasser,
    String? strasse,
    String? wetter,
  }) {
    final rawTyp = (meta['typ'] as String?)?.trim() ?? 'DIV';
    final upperTyp = rawTyp.toUpperCase();
    final typ =
        (upperTyp == 'VS' ||
            upperTyp == 'VG' ||
            upperTyp == 'G' ||
            upperTyp.contains('SICKERGRUBE') ||
            upperTyp.contains('GRUBE'))
        ? 'VG'
        : upperTyp;

    String listToText(dynamic v) {
      if (v == null) return '';
      if (v is List) {
        return v
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join(', ');
      }
      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) return '';
        return s
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .join(', ');
      }
      return v.toString().trim();
    }

    String abteilungenText() {
      final raw = meta['abteilungen'] ?? meta['abteilungsMarker'];
      return listToText(raw);
    }

    double? toDoubleValue(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.'));
      return null;
    }

    num? toNumValue(dynamic v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v.replaceAll(',', '.'));
      return null;
    }

    String? formatWeather(String? w, String? t) {
      final weather = (w ?? '').trim();
      final temp = (t ?? '').trim();

      if (weather.isEmpty && temp.isEmpty) return null;
      if (weather.isEmpty) return temp;
      if (temp.isEmpty) return weather;
      return '$weather $temp°C';
    }

    String? formatGps() {
      double? lat;
      double? lon;
      num? acc;

      final rawGps = meta['gps'];
      if (rawGps is Map) {
        final g = Map<String, dynamic>.from(rawGps);
        lat = toDoubleValue(g['lat'] ?? g['latitude'] ?? g['gpsLat']);
        lon = toDoubleValue(g['lon'] ?? g['lng'] ?? g['gpsLon']);
        acc = toNumValue(g['accuracy_m'] ?? g['acc'] ?? g['accuracy']);
      } else {
        lat = toDoubleValue(meta['gpsLat'] ?? meta['lat']);
        lon = toDoubleValue(meta['gpsLon'] ?? meta['lon']);
        acc = toNumValue(meta['gpsAcc']);
      }

      if (lat == null || lon == null) return null;
      final accText = acc != null ? ' (±${acc.toString()} m)' : '';
      return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}$accText';
    }

    final fields = <String, String>{
      'EVNr': meta['evnr'] as String? ?? '',
      'Positionsnummer': meta['posNr'] as String? ?? '—',
      // ID kommt aus dem Formular (nicht aus storageKey)
      'ID-Nummer': (meta['idNr'] as String?)?.trim() ?? '',
      'Straße': meta['strasse'] as String? ?? strasse ?? '—',
      'Erfasser:in': (meta['erfasser'] as String?)?.trim().isNotEmpty == true
          ? (meta['erfasser'] as String)
          : (erfasser ?? '—'),
      'Datum/Zeit': meta['zeitIso'] != null ? (meta['zeitIso'] as String) : '—',
      'Wetter':
          formatWeather(
            meta['wetter'] as String?,
            meta['temperatur'] as String?,
          ) ??
          (wetter ?? '—'),
      'Verfügbarkeit': listToText(meta['verfuegbarkeit']),
      'Status vor Ort': listToText(meta['statusVorOrt']),
      'Abteilungen': abteilungenText(),
      'Bemerkung': (meta['bemerkung'] as String?) ?? '—',
    };

    final gpsText = formatGps();
    if (gpsText != null) {
      fields['GPS'] = gpsText;
    }

    // ---------- Typ-spezifische Felder 1:1 aus den Screens ----------

    void putIfFilled(String key, dynamic val) {
      final s = (val ?? '').toString().trim();
      if (s.isNotEmpty) fields[key] = s;
    }

    if (typ == 'ES') {
      // Einsteigschacht
      putIfFilled('Eingang', meta['eingang']);
      // Einsteigart (Alt/Neu bei Steigeisen)
      final einsteigart = (meta['einsteigart'] as String?)?.trim() ?? '';
      final steigeisenStand =
          (meta['steigeisenStand'] as String?)?.trim() ?? '';
      if (einsteigart.isNotEmpty) {
        fields['Einsteigart'] =
            (einsteigart == 'Steigeisen' && steigeisenStand.isNotEmpty)
            ? 'Steigeisen – $steigeisenStand'
            : einsteigart;
      }
      // Für PDF auch explizit den Stand der Steigeisen mitgeben (Alt/Neu)
      if (einsteigart == 'Steigeisen' && steigeisenStand.isNotEmpty) {
        fields['steigeisenStand'] = steigeisenStand;
      }
      putIfFilled('Deckelart', meta['deckel']);
      putIfFilled('KL', meta['kl']);

      final keinBefund = meta['keinBefund'] == true;
      final rawSchaeden = meta['schaeden'];
      final schaedenList = rawSchaeden is List
          ? rawSchaeden
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : (rawSchaeden is String
                ? rawSchaeden
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList()
                : <String>[]);
      final schaedenText = schaedenList.join(', ');
      if (keinBefund) {
        fields['Schäden'] = 'Kein Befund';
      } else if (schaedenText.isNotEmpty) {
        fields['Schäden'] = schaedenText;
      }

      putIfFilled('Schacht Durchmesser', meta['durchmesser']);
      putIfFilled('Kanalprofil', meta['kanalprofil']);

      putIfFilled('Örtlichkeit', meta['oertlichkeit']);
      putIfFilled('Örtlichkeit – Bemerkung', meta['oertlBem']);

      putIfFilled('Oberflächenart', meta['oberflaeche']);
      putIfFilled('Oberfläche – Bemerkung', meta['obflBem']);

      putIfFilled('Schachtkopfdaten', meta['schachtkopf']);
      putIfFilled('Übergangsplatte (Höhe)', meta['uebergangsBem']);

      // Maße (nur wenn RF aktiv gespeichert wurde – Screen speichert sonst "")
      putIfFilled('1. Steigeisen – Steighöhe', meta['st1Hoehe']);
      putIfFilled('1. Steigeisen – Rückenfreiheit', meta['st1Rf']);
      putIfFilled('2. Steigeisen – Steighöhe', meta['st2Hoehe']);
      putIfFilled('2. Steigeisen – Rückenfreiheit', meta['st2Rf']);
      putIfFilled('Konusanfang', meta['mKonusAnf']);
      putIfFilled('Konusende', meta['mKonusEnd']);
      putIfFilled('Berme', meta['mBerme']);
      putIfFilled('Solltiefe', meta['mSolltiefe']);
    }

    // ---------------- SSK (Straßensinkkasten) ----------------
    if (typ == 'SSK') {
      // ID-Nummer für SSK
      final idNr = (meta['idNr'] as String?)?.trim();
      if (idNr != null && idNr.isNotEmpty) {
        fields['ID-Nummer'] = idNr;
      }

      // Deckelart aus 'sskTyp' oder aus Gruppe/Ausprägung ableiten
      String? sskTyp = (meta['sskTyp'] as String?)?.trim();
      if (sskTyp == null || sskTyp.isEmpty) {
        final gruppe = (meta['gruppe'] as String?)?.trim() ?? '';
        final auspr = (meta['auspraegung'] as String?)?.trim() ?? '';
        if (gruppe.isNotEmpty && auspr.isNotEmpty) {
          if (gruppe == 'SSK Münchner Modell') {
            sskTyp = 'Münchner Modell – $auspr';
          } else {
            // Ausprägung kann "Bemerkung: <Text>" sein
            if (auspr.toLowerCase().startsWith('bemerkung:')) {
              final txt = auspr.substring('Bemerkung:'.length).trim();
              sskTyp =
                  'Weitere Hersteller – ${txt.isEmpty ? 'Bemerkung' : txt}';
            } else {
              sskTyp = 'Weitere Hersteller – $auspr';
            }
          }
        }
      }
      if (sskTyp != null && sskTyp.isNotEmpty) putIfFilled('Deckelart', sskTyp);

      final keinBefundSSK = meta['keinBefund'] == true;
      final schSSK = listToText(meta['schaeden']);
      if (keinBefundSSK) {
        fields['Schäden'] = 'Kein Befund';
      } else if (schSSK.isNotEmpty) {
        fields['Schäden'] = schSSK;
      }

      if (meta['ablaufrinne'] == true) {
        putIfFilled('Ablaufrinne', 'Ja');
      }

      final leitungsverlauf = (meta['leitungsverlauf'] as String?)?.trim();
      if (leitungsverlauf != null && leitungsverlauf.isNotEmpty) {
        putIfFilled('Leitungsverlauf', leitungsverlauf);
      }

      // Tiefe und Wasserstand für SSK
      putIfFilled('Tiefe (cm)', meta['tiefe_cm']);
      putIfFilled('Wasserstand (cm)', meta['wasser_cm']);
    }

    // ---------------- VG / Grube ----------------
    if (typ == 'VG' || typ == 'VS' || typ == 'G') {
      // ID-Nummer für VG/Grube
      final idNr = (meta['idNr'] as String?)?.trim();
      if (idNr != null && idNr.isNotEmpty) {
        fields['ID-Nummer'] = idNr;
      }

      // Schäden/Kein Befund aufnehmen
      final keinBefund = meta['keinBefund'] == true;
      final schaedenText = listToText(meta['schaeden']);
      if (keinBefund) {
        fields['Schäden'] = 'Kein Befund';
      } else if (schaedenText.isNotEmpty) {
        fields['Schäden'] = schaedenText;
      }

      putIfFilled('Grubentyp', meta['grubentyp'] ?? meta['grubenart']);
      putIfFilled('Grubenart', meta['grubentyp'] ?? meta['grubenart']);
      putIfFilled('Deckelart', meta['deckel']);
      putIfFilled('KL', meta['kl']);
      putIfFilled('Baujahr', meta['baujahr']);
      putIfFilled(
        'Filtersand Eigenschaften',
        listToText(meta['filtersandEigensch']),
      );
      if (meta['filtersandJa'] is bool) {
        putIfFilled('Filtersand', meta['filtersandJa'] == true ? 'Ja' : 'Nein');
      } else {
        putIfFilled('Filtersand', meta['filtersand']);
      }
    }

    // ---------------- LÜ / SK ----------------
    if (typ == 'LÜ' || typ == 'SK') {
      // ID-Nummer für LÜ und SK
      final idNr = (meta['idNr'] as String?)?.trim();
      if (idNr != null && idNr.isNotEmpty) {
        fields['ID-Nummer'] = idNr;
      }

      // Schäden/Kein Befund aufnehmen
      final keinBefund = meta['keinBefund'] == true;
      final schaedenText = listToText(meta['schaeden']);
      if (keinBefund) {
        fields['Schäden'] = 'Kein Befund';
      } else if (schaedenText.isNotEmpty) {
        fields['Schäden'] = schaedenText;
      }

      // Fuer Lueftung: Deckelart = echter Deckel bei Neu, Aufbau = Alt/Neu.
      if (typ == 'LÜ') {
        final art =
            (meta['art'] as String?)?.trim() ??
            (meta['typ_detail'] as String?)?.trim() ??
            '';
        final deckel = (meta['deckel'] as String?)?.trim() ?? '';
        if (deckel.isNotEmpty) {
          fields['Deckelart'] = deckel;
        } else if (art.isNotEmpty) {
          fields['Deckelart'] = art;
        }
        if (art.isNotEmpty) {
          fields['Aufbau'] = art;
        }
        final kl = (meta['kl'] as String?)?.trim();
        if (kl != null && kl.isNotEmpty) {
          fields['KL'] = kl;
        }
      }

      // Für Schieber: Typ und Zustand
      if (typ == 'SK') {
        final td = (meta['typ_detail'] as String?)?.trim();
        final zustand = (meta['zustand'] as String?)?.trim();
        if (td != null && td.isNotEmpty) fields['Typ'] = td;
        if (zustand != null && zustand.isNotEmpty) fields['Zustand'] = zustand;

        // Austausch erforderlich
        final austausch = meta['austauschErforderlich'] == true;
        if (austausch) {
          fields['Austausch erforderlich'] = 'Ja';
        }
      }
    }

    // ---------------- KANAL ----------------
    if (typ == 'KANAL') {
      putIfFilled('ID-Nummer', meta['idNr']);
      putIfFilled('Kanalprofil', meta['kanalprofil']);
      final keinBefund = meta['keinBefund'] == true;
      final schaedenText = listToText(meta['schaeden']);
      final schadensdetails = (meta['schadensdetails'] as String?)?.trim();
      if (keinBefund) {
        fields['Schäden'] = 'Kein Befund';
      } else if (schaedenText.isNotEmpty) {
        fields['Schäden'] = schaedenText;
      } else if (schadensdetails != null && schadensdetails.isNotEmpty) {
        fields['Schäden'] = schadensdetails;
      }
      if (schadensdetails != null && schadensdetails.isNotEmpty) {
        fields['Schadensdetails'] = schadensdetails;
      }
    }

    // ---------------- DIV / Sonstiges ----------------
    if (typ == 'DIV') {
      final titel = (meta['titel'] as String?)?.trim();
      final beschreibung = (meta['beschreibung'] as String?)?.trim();
      if (titel != null && titel.isNotEmpty) putIfFilled('Titel', titel);
      if (beschreibung != null && beschreibung.isNotEmpty)
        putIfFilled('Beschreibung', beschreibung);

      final keinBefund = meta['keinBefund'] == true;
      final schaedenText = listToText(meta['schaeden']);
      final schadensdetails = (meta['schadensdetails'] as String?)?.trim();
      if (keinBefund) {
        fields['Schäden'] = 'Kein Befund';
      } else if (schaedenText.isNotEmpty) {
        fields['Schäden'] = schaedenText;
      } else if (schadensdetails != null && schadensdetails.isNotEmpty) {
        fields['Schäden'] = schadensdetails;
      }
      if (schadensdetails != null && schadensdetails.isNotEmpty) {
        fields['Schadensdetails'] = schadensdetails;
      }
    }

    // ---------- Grube/VG (nur wenn es wirklich Grube ist) ----------
    final grubeMap = <String, String>{};
    void put(String key, dynamic val) {
      final s = (val ?? '').toString().trim();
      if (s.isNotEmpty) grubeMap[key] = s;
    }

    if ((typ == 'VG' || typ == 'VS') && meta['grube'] is Map) {
      final gm = Map<String, dynamic>.from(meta['grube'] as Map);
      gm.forEach((k, v) => put(k.toString(), v));
    } else if (typ == 'VG' || typ == 'VS') {
      // Fallback: direkte Felder
      put('Grubentyp', meta['grubentyp']);

      put('Deckelart', meta['deckel']);
      put('KL', meta['kl']);

      final tiefeCmRaw = (meta['tiefe_cm'] as String?)?.trim();
      final tiefeMRaw = (meta['tiefe_m'] as String?)?.trim();
      if (tiefeCmRaw != null && tiefeCmRaw.isNotEmpty) {
        put('Grubentiefe (cm)', tiefeCmRaw);
        grubeMap['tiefe_cm'] = tiefeCmRaw;
      } else if (tiefeMRaw != null && tiefeMRaw.isNotEmpty) {
        final mVal = num.tryParse(tiefeMRaw.replaceAll(',', '.'));
        if (mVal != null) {
          final cm = (mVal * 100).toStringAsFixed(
            mVal.truncateToDouble() == mVal ? 0 : 2,
          );
          put('Grubentiefe (cm)', cm);
          grubeMap['tiefe_cm'] = cm;
        }
      }

      final wasserCmRaw = (meta['wasser_cm'] as String?)?.trim();
      final wasserMRaw = (meta['wasser_m'] as String?)?.trim();
      if (wasserCmRaw != null && wasserCmRaw.isNotEmpty) {
        put('Wasserstand (cm)', wasserCmRaw);
        grubeMap['wasser_cm'] = wasserCmRaw;
      } else if (wasserMRaw != null && wasserMRaw.isNotEmpty) {
        final mVal2 = num.tryParse(wasserMRaw.replaceAll(',', '.'));
        if (mVal2 != null) {
          final cm2 = (mVal2 * 100).toStringAsFixed(
            mVal2.truncateToDouble() == mVal2 ? 0 : 2,
          );
          put('Wasserstand (cm)', cm2);
          grubeMap['wasser_cm'] = cm2;
        }
      }

      final anschlussJa = meta['anschlussJa'] == true;
      final anschlussRaw = (meta['anschluss'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final hasAnschluss =
          anschlussJa || anschlussRaw == 'ja' || anschlussRaw == 'nein';
      if (hasAnschluss) {
        put(
          'Anschluss am Kanal',
          anschlussJa || anschlussRaw == 'ja' ? 'Ja' : 'Nein',
        );
        grubeMap['anschluss'] = anschlussJa || anschlussRaw == 'ja'
            ? 'Ja'
            : 'Nein';
      }
      if (anschlussJa || anschlussRaw == 'ja') {
        put('Überlauf', meta['teller']);
        put('teller', meta['teller']);
      }

      if (meta['filtersandJa'] is bool) {
        put('Filtersand', meta['filtersandJa'] == true ? 'Ja' : 'Nein');
      } else {
        put('Filtersand', meta['filtersand']);
      }
      put('Filtersand Eigenschaften', listToText(meta['filtersandEigensch']));
      put('Baujahr', meta['baujahr']);
    }

    // Merge into fields (human-readable keys)
    grubeMap.forEach((k, v) {
      fields[k.toString()] = v;
    });

    return fields;
  }
}

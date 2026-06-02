import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'speicher_service.dart';

/// Service zum Importieren/Exportieren kompletter Datensätze
/// Format: ZIP-Datei mit:
/// - erfassungen.json (Metadaten aller Einträge nach EVNr)
/// - medien/ (Ordner mit allen Fotos/Videos)
/// - metadata.json (Exportzeitpunkt, Version, App-Info)
class ImportExportService {
  static const Map<String, String> _mediaFieldToFolder = {
    'mediaFotos': 'fotos',
    'mediaVideos': 'videos',
    'mediaAudios': 'audios',
    'mediaPdfs': 'pdfs',
  };

    /// Englischer Alias für exportiereDaten, damit alte Aufrufe weiterhin funktionieren
    static Future<Uint8List> exportData({
      required List<String> evnrs,
      String? erfasser,
      String? strasse,
      DateTime? exportTime,
    }) {
      return exportiereDaten(
        evnrs: evnrs,
        erfasser: erfasser,
        strasse: strasse,
        exportZeit: exportTime,
      );
    }
  /// Exportiert alle Daten für die angegebenen EVNr(s) als ZIP-Datei
  /// Gibt Uint8List mit den ZIP-Datei-Bytes zurück
  static Future<Uint8List> exportiereDaten({
    required List<String> evnrs,
    String? erfasser,
    String? strasse,
    DateTime? exportZeit,
  }) async {
    final encoder = ZipEncoder();
    final archiv = Archive();
    // Metadaten hinzufügen
    final metadaten = {
      'exportZeit': (exportZeit ?? DateTime.now()).toIso8601String(),
      'exportierteEvNrs': evnrs,
      'erfasser': erfasser ?? 'unbekannt',
      'strasse': strasse ?? '',
      'appVersion': '1.0',
    };
    archiv.addFile(
      ArchiveFile(
        'metadata.json',
        jsonEncode(metadaten).length,
        utf8.encode(jsonEncode(metadaten)),
      ),
    );

    // Alle Einträge und Mediendateien sammeln
    final erfassungenMap = <String, List<Map<String, dynamic>>>{};
    final medienDateien = <String, Uint8List>{};

    for (final evnr in evnrs) {
      try {
        final eintraege = await SpeicherService.ladeEintraegeFuerEvNr(evnr, strasse: strasse);
        final exportEintraege = <Map<String, dynamic>>[];
        for (final eintrag in eintraege) {
          final exportEintrag = Map<String, dynamic>.from(eintrag);
          await _sammleMedienFuerExport(
            evnr: evnr,
            eintrag: exportEintrag,
            medienDateien: medienDateien,
          );
          exportEintraege.add(exportEintrag);
        }
        erfassungenMap[evnr] = exportEintraege;
      } catch (e) {
        debugPrint('Fehler beim Export von EVNr $evnr: $e');
      }
    }

    // erfassungen.json mit allen Einträgen hinzufügen
    archiv.addFile(
      ArchiveFile(
        'erfassungen.json',
        jsonEncode(erfassungenMap).length,
        utf8.encode(jsonEncode(erfassungenMap)),
      ),
    );
    

    // Mediendateien zum Archiv hinzufügen
    for (final eintrag in medienDateien.entries) {
      archiv.addFile(ArchiveFile.noCompress(eintrag.key, eintrag.value.length, eintrag.value));
    }

    // ZIP kodieren und zurückgeben
    final zipBytes = encoder.encode(archiv);
    return Uint8List.fromList(zipBytes);
  }

  /// Importiert Daten aus einer ZIP-Datei
  /// Erwartete ZIP-Struktur:
  /// - metadata.json
  /// - erfassungen.json
  /// - medien/ (optional Ordner mit Mediendateien)
  /// Gibt ein Tupel zurück: (importierte EVNr-Anzahl, Gesamtanzahl Einträge)
  static Future<(int, int)> importiereDaten(Uint8List zipBytes) async {
    int evnrAnzahl = 0;
    int eintragAnzahl = 0;
    try {
      final archiv = ZipDecoder().decodeBytes(zipBytes);
      final archiveFilesByName = <String, ArchiveFile>{
        for (final file in archiv.files.where((file) => file.isFile))
          file.name.replaceAll('\\', '/'): file,
      };
      final erfassungenDatei = _waehleErfassungenJsonDatei(archiv);
      if (erfassungenDatei == null) {
        debugPrint('Keine erfassungen.json in ZIP gefunden');
        return (0, 0);
      }
      final erfassungenJson = utf8.decode(erfassungenDatei.content as List<int>);
      final parsed = jsonDecode(erfassungenJson);
      final erfassungenMap = _normalisiereErfassungen(parsed);
      if (erfassungenMap.isEmpty) {
        debugPrint('erfassungen.json hat unerwartetes Format (leer nach Normalisierung)');
        return (0, 0);
      }
      for (final evnrEntry in erfassungenMap.entries) {
        final evnr = evnrEntry.key;
        final eintraege = evnrEntry.value;
        evnrAnzahl++;
        for (final eintragsDaten in eintraege) {
          try {
            final normalisierteDaten = await _rekonstruiereMedienAusArchiv(
              Map<String, dynamic>.from(eintragsDaten),
              archiveFilesByName,
            );
            // eintragsDaten ist immer Map<String, dynamic> durch Normalisierung
            final speicherKey = _buildImportStorageKey(evnr, normalisierteDaten);
            await SpeicherService.upsertEntry(speicherKey, normalisierteDaten);
            eintragAnzahl++;
          } catch (e) {
            debugPrint('Fehler beim Import eines Eintrags: $e');
          }
        }
      }
      debugPrint('Import abgeschlossen: $evnrAnzahl EVNr(s), $eintragAnzahl Einträge');
    } catch (e) {
      debugPrint('Fehler beim Import der ZIP-Datei: $e');
    }
    return (evnrAnzahl, eintragAnzahl);
  }

  /// Importiert aus einer normalen JSON-Datei (gleiche Struktur wie erfassungen.json)
  /// Erwartet: { "EVNR": [ {meta...}, ... ], ... }
  static Future<(int, int)> importiereJson(Uint8List jsonBytes) async {
    int evnrAnzahl = 0;
    int eintragAnzahl = 0;
    try {
      final content = utf8.decode(jsonBytes);
      final parsed = jsonDecode(content);
      final daten = _normalisiereErfassungen(parsed);
      if (daten.isEmpty) {
        debugPrint('importiereJson: Unerwartetes JSON-Format');
        return (0, 0);
      }
      for (final evnrEntry in daten.entries) {
        final evnr = evnrEntry.key;
        final eintraege = evnrEntry.value;
        evnrAnzahl++;
        for (final eintragsDaten in eintraege) {
          // eintragsDaten ist immer Map<String, dynamic> durch Normalisierung
          final speicherKey = _buildImportStorageKey(evnr, eintragsDaten);
          await SpeicherService.upsertEntry(speicherKey, eintragsDaten);
          eintragAnzahl++;
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Import von JSON: $e');
    }
    return (evnrAnzahl, eintragAnzahl);
  }

  /// Normalisiert verschiedene mögliche JSON-Formate zu { evnr: [eintrag, ...] }
  static Map<String, List<Map<String, dynamic>>> _normalisiereErfassungen(dynamic parsed) {
    final result = <String, List<Map<String, dynamic>>>{};

    void eintragHinzufuegen(String evnr, Map<String, dynamic> eintrag) {
      final key = evnr.trim();
      if (key.isEmpty) return;
      result.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(eintrag);
    }

    Map<String, dynamic>? versucheUnwrapData(dynamic obj) {
      if (obj is Map<String, dynamic> && obj['data'] is Map<String, dynamic>) {
        return obj['data'];
      }
      return null;
    }

    String leseEvnr(Map<String, dynamic> m) {
      final keys = ['evnr', 'EVNr', 'evNr', 'ev', 'EV'];
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return 'UNBEKANNT';
    }

    Map<String, List<Map<String, dynamic>>> ausMap(Map<String, dynamic> map) {
      final out = <String, List<Map<String, dynamic>>>{};
      for (final entry in map.entries) {
        final evnr = entry.key.toString();
        final val = entry.value;
        if (val is List) {
          final list = val.whereType<Map<String, dynamic>>().toList();
          if (list.isNotEmpty) out[evnr] = list;
        } else if (val is Map<String, dynamic>) {
          out[evnr] = [val];
        }
      }
      return out;
    }

    if (parsed is Map<String, dynamic>) {
      final unwrapped = versucheUnwrapData(parsed);
      final mapToUse = unwrapped ?? parsed;

      // Sonderfall: Map hat nur einen Key und darin steckt die eigentliche Struktur
      if (mapToUse.length == 1) {
        final singleVal = mapToUse.values.first;
        if (singleVal is Map<String, dynamic>) {
          result.addAll(ausMap(singleVal));
          return result;
        }
        if (singleVal is List) {
          // Liste von Einträgen, EVNr muss aus Inhalt gelesen werden
          for (final item in singleVal) {
            if (item is! Map<String, dynamic>) continue;
            final ev = leseEvnr(item);
            eintragHinzufuegen(ev, item);
          }
          return result;
        }
      }

      result.addAll(ausMap(mapToUse));
      return result;
    }

    if (parsed is List) {
      for (final item in parsed) {
        if (item is! Map<String, dynamic>) continue;
        final ev = leseEvnr(item);
        eintragHinzufuegen(ev, item);
      }
      return result;
    }

    return result;
  }

  /// Wählt eine passende JSON-Datei aus dem ZIP, bevorzugt erfassungen.json, sonst erste sinnvolle JSON.
  static ArchiveFile? _waehleErfassungenJsonDatei(Archive archiv) {
    ArchiveFile? fallback;

    for (final file in archiv) {
      final name = file.name.toLowerCase();
      if (!name.endsWith('.json')) continue;
      // Bevorzugt explizit erfassungen.json
      if (name.endsWith('erfassungen.json')) return file;
      // Falls in Unterordnern mit anderem Prefix/Suffix
      if (name.contains('erfassungen')) return file;
      if (name.endsWith('metadata.json')) {
        fallback ??= file; // Metadata nur als letzter Notnagel
        continue;
      }
      // Erste andere JSON als Kandidat merken
      fallback ??= file;
    }
    return fallback;
  }

  static Future<void> _sammleMedienFuerExport({
    required String evnr,
    required Map<String, dynamic> eintrag,
    required Map<String, Uint8List> medienDateien,
  }) async {
    final posNr = _sanitizePathSegment((eintrag['posNr'] ?? 'ohne_pos').toString());
    final typ = _sanitizePathSegment((eintrag['typ'] ?? 'objekt').toString());
    final storageKey = _sanitizePathSegment((eintrag['storageKey'] ?? 'eintrag').toString());
    final exportRefs = <String, List<String>>{};

    for (final entry in _mediaFieldToFolder.entries) {
      final fieldName = entry.key;
      final folderName = entry.value;
      final rawList = eintrag[fieldName];
      if (rawList is! List) continue;

      final refs = <String>[];
      for (var index = 0; index < rawList.length; index++) {
        final raw = rawList[index]?.toString() ?? '';
        if (raw.trim().isEmpty) continue;

        final bytes = _decodeDataUrl(raw);
        if (bytes == null) continue;

        final extension = _extensionForMedia(fieldName, raw);
        final archivePath = 'medien/$evnr/$posNr/$folderName/${typ}_${storageKey}_${index + 1}$extension';
        medienDateien.putIfAbsent(archivePath, () => bytes);
        refs.add(archivePath);
      }

      if (refs.isNotEmpty) {
        exportRefs[fieldName] = refs;
      }
    }

    if (exportRefs.isNotEmpty) {
      eintrag['mediaExportRefs'] = exportRefs;
    }
  }

  static Future<Map<String, dynamic>> _rekonstruiereMedienAusArchiv(
    Map<String, dynamic> eintrag,
    Map<String, ArchiveFile> archiveFilesByName,
  ) async {
    final refsRaw = eintrag['mediaExportRefs'];
    final mediaRefs = refsRaw is Map ? refsRaw.cast<String, dynamic>() : const <String, dynamic>{};

    for (final fieldName in _mediaFieldToFolder.keys) {
      final rawList = eintrag[fieldName];
      final values = rawList is List ? rawList.map((e) => e?.toString() ?? '').toList() : <String>[];
      final refs = mediaRefs[fieldName] is List
          ? (mediaRefs[fieldName] as List).map((e) => e.toString()).toList()
          : <String>[];

      final hydrated = <String>[];
      for (final value in values) {
        final normalized = value.trim();
        if (normalized.isEmpty) continue;
        if (normalized.startsWith('data:')) {
          hydrated.add(normalized);
          continue;
        }
        final dataUrl = _dataUrlFromArchivePath(fieldName, normalized, archiveFilesByName);
        if (dataUrl != null) hydrated.add(dataUrl);
      }

      if (hydrated.isEmpty && refs.isNotEmpty) {
        for (final ref in refs) {
          final dataUrl = _dataUrlFromArchivePath(fieldName, ref, archiveFilesByName);
          if (dataUrl != null) hydrated.add(dataUrl);
        }
      }

      if (hydrated.isNotEmpty) {
        eintrag[fieldName] = hydrated;
      }
    }

    eintrag.remove('mediaExportRefs');
    return eintrag;
  }

  static String? _dataUrlFromArchivePath(
    String fieldName,
    String archivePath,
    Map<String, ArchiveFile> archiveFilesByName,
  ) {
    final normalizedPath = archivePath.replaceAll('\\', '/');
    final file = archiveFilesByName[normalizedPath];
    if (file == null) return null;
    final content = file.content as List<int>;
    final mimeType = _mimeTypeForPath(fieldName, normalizedPath);
    return 'data:$mimeType;base64,${base64Encode(content)}';
  }

  static Uint8List? _decodeDataUrl(String dataUrl) {
    final idx = dataUrl.indexOf(',');
    if (idx == -1) return null;
    final base64Part = dataUrl.substring(idx + 1);
    try {
      return Uint8List.fromList(base64Decode(base64Part));
    } catch (_) {
      return null;
    }
  }

  static String _extensionForMedia(String fieldName, String dataUrl) {
    final lower = dataUrl.toLowerCase();
    if (fieldName == 'mediaFotos') {
      if (lower.startsWith('data:image/png')) return '.png';
      if (lower.startsWith('data:image/webp')) return '.webp';
      return '.jpg';
    }
    if (fieldName == 'mediaVideos') {
      if (lower.startsWith('data:video/webm')) return '.webm';
      if (lower.startsWith('data:video/quicktime')) return '.mov';
      return '.mp4';
    }
    if (fieldName == 'mediaAudios') {
      if (lower.startsWith('data:audio/mpeg')) return '.mp3';
      if (lower.startsWith('data:audio/mp4')) return '.m4a';
      if (lower.startsWith('data:audio/wav')) return '.wav';
      return '.webm';
    }
    return '.pdf';
  }

  static String _mimeTypeForPath(String fieldName, String archivePath) {
    final lower = archivePath.toLowerCase();
    if (fieldName == 'mediaFotos') {
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.webp')) return 'image/webp';
      return 'image/jpeg';
    }
    if (fieldName == 'mediaVideos') {
      if (lower.endsWith('.webm')) return 'video/webm';
      if (lower.endsWith('.mov')) return 'video/quicktime';
      return 'video/mp4';
    }
    if (fieldName == 'mediaAudios') {
      if (lower.endsWith('.mp3')) return 'audio/mpeg';
      if (lower.endsWith('.m4a')) return 'audio/mp4';
      if (lower.endsWith('.wav')) return 'audio/wav';
      return 'audio/webm';
    }
    return 'application/pdf';
  }

  static String _sanitizePathSegment(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return cleaned.isEmpty ? 'leer' : cleaned;
  }

  static String _buildImportStorageKey(String evnr, Map<String, dynamic> eintrag) {
    final posNr = (eintrag['posNr'] as String?)?.trim();
    final strasse = (eintrag['strasse'] as String?)?.trim();
    final typ = (eintrag['typ'] as String?)?.trim();

    final posSegment = posNr?.isNotEmpty == true ? posNr! : UniqueKey().hashCode.toString();
    final strassenSegment = strasse?.isNotEmpty == true ? strasse! : 'Unbekannt';
    final typSegment = typ?.isNotEmpty == true ? typ! : 'OBJ';

    return 'obj_${evnr}_${strassenSegment}_${posSegment}_$typSegment';
  }
}

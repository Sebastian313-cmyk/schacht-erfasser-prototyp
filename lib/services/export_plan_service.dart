import 'package:flutter/foundation.dart';

import '../models/base_entry.dart';

/// Repräsentiert einen geplanten Export vor Erzeugung der PDFs/ZIP.
class ExportPlan {
  final String rootFolder;          // z.B. Strasse
  final String evnr;                // EVNr
  final String? strasse;            // Straße (für PDF Kopf)
  final bool gesamtPdfPlanned;      // Gesamt_Bericht.pdf enthalten?
  final List<PlannedPosition> positions;
  ExportPlan({
    required this.rootFolder,
    required this.evnr,
    required this.strasse,
    required this.gesamtPdfPlanned,
    required this.positions,
  });
}

class PlannedPosition {
  final int index;                  // Laufende Nummer / Fallback
  final BaseEntry? entry;           // Original Eintrag (nullable for meta-first)
  final Map<String, dynamic>? meta; // Original meta JSON (nullable for entry-first)
  final String? positionsnummer;    // Positionsnummer aus Entry oder Meta
  bool steckbriefPlanned;           // Steckbrief.pdf exportieren?
  final List<PlannedMedia> fotos;   // Fotos
  final List<PlannedMedia> videos;  // Videos
  final List<PlannedMedia> audios;  // Audio
  final List<PlannedMedia> pdfs;    // PDFs
  PlannedPosition({
    required this.index,
    this.entry,
    this.meta,
    required this.positionsnummer,
    required this.steckbriefPlanned,
    required this.fotos,
    required this.videos,
    this.audios = const [],
    this.pdfs = const [],
  });
}

enum MediaType { photo, video, audio, pdf }

class PlannedMedia {
  final String id;          // interne ID (posX_fotoY)
  final MediaType type;     // Foto/Video
  final String dataUrl;     // data:image/... oder data:video/...
  bool planned;             // ausgewählt für Export
  PlannedMedia({
    required this.id,
    required this.type,
    required this.dataUrl,
    this.planned = true,
  });
}

/// Hilfsfunktion: baut einen ExportPlan aus vorhandenen Einträgen und Medienlisten.
ExportPlan buildExportPlan({
  required String evnr,
  required String? strasse,
  required List<BaseEntry> entries,
  required List<List<String>> fotosPerEntry,
  required List<List<String>> videosPerEntry,
  bool includeGesamtPdf = true,
}) {
  final rootFolder = _cleanFileName(strasse ?? 'Unbekannt');
  final positions = <PlannedPosition>[];
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    final fotosRaw = i < fotosPerEntry.length ? fotosPerEntry[i] : const <String>[];
    final videosRaw = i < videosPerEntry.length ? videosPerEntry[i] : const <String>[];

    final fotos = fotosRaw.asMap().entries.map((kv) => PlannedMedia(
          id: 'pos${i + 1}_foto${kv.key + 1}',
          type: MediaType.photo,
          dataUrl: kv.value,
        )).toList();
    final videos = videosRaw.asMap().entries.map((kv) => PlannedMedia(
          id: 'pos${i + 1}_video${kv.key + 1}',
          type: MediaType.video,
          dataUrl: kv.value,
        )).toList();

    positions.add(PlannedPosition(
      index: i + 1,
      entry: e,
      meta: null,
      positionsnummer: e.positionsnummer,
      steckbriefPlanned: true,
      fotos: fotos,
      videos: videos,
    ));
  }

  return ExportPlan(
    rootFolder: rootFolder,
    evnr: evnr,
    strasse: strasse,
    gesamtPdfPlanned: includeGesamtPdf,
    positions: positions,
  );
}

/// Baut einen ExportPlan direkt aus gespeicherten Meta-JSON-Objekten.
ExportPlan buildExportPlanFromMeta({
  required String evnr,
  required String? strasse,
  required List<Map<String, dynamic>> metas,
  required List<List<String>> fotosPerEntry,
  required List<List<String>> videosPerEntry,
  List<List<String>>? audiosPerEntry,
  List<List<String>>? pdfsPerEntry,
  bool includeGesamtPdf = true,
}) {
  final rootFolder = _cleanFileName(strasse ?? 'Unbekannt');
  final positions = <PlannedPosition>[];

  for (var i = 0; i < metas.length; i++) {
    final meta = metas[i];
    final fotosRaw = i < fotosPerEntry.length ? fotosPerEntry[i] : const <String>[];
    final videosRaw = i < videosPerEntry.length ? videosPerEntry[i] : const <String>[];
    final audiosRaw = (audiosPerEntry != null && i < audiosPerEntry.length) ? audiosPerEntry[i] : const <String>[];
    final pdfsRaw = (pdfsPerEntry != null && i < pdfsPerEntry.length) ? pdfsPerEntry[i] : const <String>[];

    final fotos = fotosRaw.asMap().entries.map((kv) => PlannedMedia(
          id: 'pos${i + 1}_foto${kv.key + 1}',
          type: MediaType.photo,
          dataUrl: kv.value,
        )).toList();
    final videos = videosRaw.asMap().entries.map((kv) => PlannedMedia(
          id: 'pos${i + 1}_video${kv.key + 1}',
          type: MediaType.video,
          dataUrl: kv.value,
        )).toList();
    final audios = audiosRaw.asMap().entries.map((kv) => PlannedMedia(
          id: 'pos${i + 1}_audio${kv.key + 1}',
          type: MediaType.audio,
          dataUrl: kv.value,
        )).toList();
    final pdfs = pdfsRaw.asMap().entries.map((kv) => PlannedMedia(
          id: 'pos${i + 1}_pdf${kv.key + 1}',
          type: MediaType.pdf,
          dataUrl: kv.value,
        )).toList();

    final positionsnummer = meta['posNr'] as String?;
    
    // Warnung, wenn positionsnummer fehlt
    if ((positionsnummer ?? '').isEmpty) {
      debugPrint('[buildExportPlanFromMeta] WARNUNG: Position ${i + 1} hat keine posNr in meta! Fallback zu Index.');
    }

    positions.add(PlannedPosition(
      index: i + 1,
      entry: null,
      meta: meta,
      positionsnummer: positionsnummer,
      steckbriefPlanned: true,
      fotos: fotos,
      videos: videos,
      audios: audios,
      pdfs: pdfs,
    ));
  }

  return ExportPlan(
    rootFolder: rootFolder,
    evnr: evnr,
    strasse: strasse,
    gesamtPdfPlanned: includeGesamtPdf,
    positions: positions,
  );
}

String _cleanFileName(String name) {
  return name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
}

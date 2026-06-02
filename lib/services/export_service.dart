import 'dart:convert';
import 'dart:typed_data';
// ...existing code...

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/base_entry.dart';
import '../models/enums.dart';
import '../services/speicher_service.dart';
import '../services/export_plan_service.dart';
import '../services/rf_aufmass_service.dart';
import '../services/formular_service.dart';
import '../pdf_mini_kit.dart';

/// ExportService (meta-first)
/// - Gesamtbericht & Steckbriefe werden DIREKT aus Meta-JSON gebaut.
/// - Keine BaseEntry-Abhängigkeit notwendig.
class ExportService {
  static final DateFormat _date = DateFormat('dd.MM.yyyy HH:mm');

  static Uint8List buildCsvFromMetas({
    required String evnr,
    required List<Map<String, dynamic>> metas,
    String? strasse,
  }) {
    const headers = <String>[
      'EVNr',
      'Straße',
      'Position',
      'Objekt',
      'Status vor Ort',
      'Verfügbarkeit',
      'Schäden',
      'Bemerkung',
      'Abteilungen',
      'Fotos',
      'Videos',
      'Audios',
      'PDFs',
    ];

    final lines = <String>[_csvLine(headers)];
    for (final meta in metas) {
      final schaedenRaw = (meta['schaeden'] as List<dynamic>?) ?? const <dynamic>[];
      final schaeden = meta['keinBefund'] == true
          ? 'Kein Befund'
          : (meta['typ'] == 'ES'
              ? _augmentEsSchaeden(schaedenRaw).join(', ')
              : schaedenRaw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).join(', '));

      lines.add(_csvLine([
        evnr,
        (meta['strasse'] ?? strasse ?? '').toString(),
        (meta['posNr'] ?? '').toString(),
        (meta['typ'] ?? '').toString(),
        _csvJoin(meta['statusVorOrt']),
        _csvJoin(meta['verfuegbarkeit']),
        schaeden,
        (meta['bemerkung'] ?? '').toString(),
        _csvJoin(meta['abteilungen'] ?? meta['abteilungsMarker']),
        ((meta['mediaFotos'] as List<dynamic>?)?.length ?? 0).toString(),
        ((meta['mediaVideos'] as List<dynamic>?)?.length ?? 0).toString(),
        ((meta['mediaAudios'] as List<dynamic>?)?.length ?? 0).toString(),
        ((meta['mediaPdfs'] as List<dynamic>?)?.length ?? 0).toString(),
      ]));
    }

    return Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\n')}'));
  }

  static Future<pw.ThemeData> _theme() async {
    try {
      final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      // Fallbacks für Unicode-Zeichen (en/em dash etc.)
      final notoReg = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      final notoBold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
      return pw.ThemeData.withFont(
        base: reg,
        bold: bold,
        fontFallback: [notoReg, notoBold],
      );
    } catch (_) {
      return pw.ThemeData();
    }
  }

  /// Gesamtbericht aus Meta-Objekten.
  /// Spalten: Pos | Objekt | Deckelart | Aufbau | KL | Schaden | Bemerkung
  /// Zeile rot, wenn Schaden (aber nicht bei "Kein Befund").
  static Future<Uint8List> buildGesamtPdfFromMetas({
    required String evnr,
    required List<Map<String, dynamic>> metas,
    String? erfasser,
    String? strasse,
    String? wetter,
    DateTime? zeit,
  }) async {
    final pdf = pw.Document(theme: await _theme());

    final headerRow = pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Erfassung - Gesamtbericht',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('EVNr: $evnr', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Erfasser: ${erfasser ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Straße: ${strasse ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Datum/Zeit: ${zeit != null ? _date.format(zeit) : '—'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Wetter: ${wetter ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );

    final headers = const [
      'Pos.',
      'Objekt',
      'Deckelart',
      'Aufbau',
      'KL',
      'Schaden',
      'Bemerkung',
      'Medien',
    ];

    // Zeilen vorbereiten
    final rows = <List<pw.Widget>>[];
    final rowIsRed = <bool>[];

    for (final meta in metas) {
      final pos = (meta['posNr'] as String?)?.trim().isNotEmpty == true ? (meta['posNr'] as String).trim() : '—';
      final typ = (meta['typ'] as String?) ?? 'DIV';

      // Schaden-Logik: rot wenn es echte Schäden gibt.
      // "Kein Befund" => NICHT rot.
      // RF gilt als Schaden-Hinweis, zählt hier als Schaden (weil in Schäden-Liste enthalten).
      final bool keinBefund = meta['keinBefund'] == true;
        final List<dynamic> schaedenListRaw = (meta['schaeden'] as List<dynamic>?) ?? const [];
        final schaeden = typ == 'ES'
          ? _augmentEsSchaeden(schaedenListRaw)
          : schaedenListRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
      final hasSchaden = !keinBefund && schaeden.isNotEmpty;

      final titel = _metaTitel(meta);

      final deckelart = _deckelart(meta);
      final aufbau = _aufbau(meta);
      final kl = (meta['kl'] ?? '').toString().trim();

      // Medien
      final bemerkungRaw = (meta['bemerkung'] ?? '').toString().trim();
      final bemerkung = _mergeBemerkung(bemerkungRaw, '');

      // Medien: nur Indikatoren mit Anzahl
      final List<dynamic> fotos = (meta['mediaFotos'] as List<dynamic>?) ?? const [];
      final List<dynamic> videos = (meta['mediaVideos'] as List<dynamic>?) ?? const [];
      final List<dynamic> audios = (meta['mediaAudios'] as List<dynamic>?) ?? const [];

      final List<String> mediaIndicators = [];
      if (fotos.isNotEmpty) mediaIndicators.add('Fotos: ${fotos.length}');
      if (videos.isNotEmpty) mediaIndicators.add('🎥 ${videos.length}');
      if (audios.isNotEmpty) mediaIndicators.add('🔊 ${audios.length}');
      final mediaStr = mediaIndicators.isEmpty ? '—' : mediaIndicators.join(' ');

      rows.add([
        pw.Text(pos, style: pw.TextStyle(fontSize: 8)),
        pw.Text(typ, style: pw.TextStyle(fontSize: 8)),
        pw.Text(deckelart.isEmpty ? '—' : deckelart, style: pw.TextStyle(fontSize: 8)),
        pw.Text(aufbau.isEmpty ? '—' : aufbau, style: pw.TextStyle(fontSize: 8)),
        pw.Text(kl.isEmpty ? '—' : kl, style: pw.TextStyle(fontSize: 8)),
        pw.Text(titel, style: pw.TextStyle(fontSize: 8)),
        pw.Text(bemerkung.isEmpty ? '—' : bemerkung, style: pw.TextStyle(fontSize: 8)),
        pw.Text(mediaStr, style: pw.TextStyle(fontSize: 8)),
      ]);
      rowIsRed.add(hasSchaden);
    }

    // PDF Seite
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (ctx) => [
          headerRow,
          pw.SizedBox(height: 10),
          _tableWithRowStylesWidgets(headers, rows, rowIsRed),
        ],
      ),
    );

    return pdf.save();
  }
  // Neue Version für Widget-Zeilen
  static pw.Widget _tableWithRowStylesWidgets(List<String> headers, List<List<pw.Widget>> data, List<bool> redRows) {
    // Header
    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: headers
          .map((h) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ))
          .toList(),
    );

    // Data rows
    final rows = <pw.TableRow>[headerRow];
    for (var i = 0; i < data.length; i++) {
      final isRed = (i < redRows.length) ? redRows[i] : false;
      final bg = isRed ? PdfColor.fromInt(0xFFFFEBEE) : null; // sehr helles Rot

      rows.add(
        pw.TableRow(
          decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
          children: data[i]
              .map((c) => pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: c,
                  ))
              .toList(),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.7),   // Pos.
        1: pw.FlexColumnWidth(1.0),   // Objekt
        2: pw.FlexColumnWidth(2.2),   // Deckelart
        3: pw.FlexColumnWidth(2.2),   // Aufbau
        4: pw.FlexColumnWidth(0.9),   // KL
        5: pw.FlexColumnWidth(2.6),   // Schaden
        6: pw.FlexColumnWidth(3.2),   // Bemerkung
        7: pw.FlexColumnWidth(3.2),   // Medien
      },
      children: rows,
    );
  }

  /// Abteilungs-PDF: Listet alle Positionen einer bestimmten Abteilung auf.
  /// Spalten: Pos | Typ | Beschreibung | Schaden | Bemerkung
  static Future<Uint8List> buildAbteilungsPdfFromMetas({
    required String abteilung,
    required String evnr,
    required List<Map<String, dynamic>> metas,
    String? erfasser,
    String? strasse,
    String? wetter,
    DateTime? zeit,
  }) async {
    final pdf = pw.Document(theme: await _theme());

    final abteilungName = {
      'M': 'Maurer',
      'S': 'Schlosser',
      'BAUKO': 'Baukontrollmeister',
      'NIS': 'NIS',
      'R': 'Reinigung',
    }[abteilung] ?? abteilung;

    final headerRow = pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Abteilungsbericht - $abteilungName',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('EVNr: $evnr', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Erfasser: ${erfasser ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Straße: ${strasse ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Datum/Zeit: ${zeit != null ? _date.format(zeit) : '—'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Wetter: ${wetter ?? '—'}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );

    final headers = const [
      'Pos.',
      'Typ',
      'Beschreibung',
      'Schaden',
      'Bemerkung',
    ];

    // Zeilen vorbereiten
    final rows = <List<String>>[];
    final rowIsRed = <bool>[];

    for (final meta in metas) {
      final pos = (meta['posNr'] as String?)?.trim().isNotEmpty == true ? (meta['posNr'] as String).trim() : '—';
      final typ = (meta['typ'] as String?) ?? 'DIV';

      // Schaden-Logik
      final bool keinBefund = meta['keinBefund'] == true;
      final List<dynamic> schaedenListRaw = (meta['schaeden'] as List<dynamic>?) ?? const [];
      final schaeden = schaedenListRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
      final hasSchaden = !keinBefund && schaeden.isNotEmpty;
      
      final schadenText = keinBefund ? 'Kein Befund' : (schaeden.isEmpty ? '—' : schaeden.join(', '));

      // Beschreibung aus verschiedenen Quellen
      String beschreibung = '';
      if (typ == 'DIV') {
        beschreibung = (meta['beschreibung'] ?? '').toString().trim();
      } else if (typ == 'ES') {
        beschreibung = (meta['einsteigart'] ?? '').toString().trim();
      } else if (typ == 'VS') {
        beschreibung = (meta['grubentyp'] ?? '').toString().trim();
      } else if (typ == 'LÜ') {
        beschreibung = (meta['art'] ?? '').toString().trim();
      } else if (typ == 'SSK') {
        final gruppe = (meta['gruppe'] ?? '').toString().trim();
        final auspr = (meta['auspraegung'] ?? '').toString().trim();
        if (gruppe.isNotEmpty && auspr.isNotEmpty) {
          beschreibung = '$gruppe - $auspr';
        }
      } else if (typ == 'SK') {
        beschreibung = (meta['typ_detail'] ?? '').toString().trim();
      }

      final mediaHint = _mediaHint(meta);
      final bemerkungRaw = (meta['bemerkung'] ?? '').toString().trim();
      final bemerkung = _mergeBemerkung(bemerkungRaw, mediaHint);

      rows.add([
        pos,
        typ,
        beschreibung.isEmpty ? '—' : beschreibung,
        schadenText,
        bemerkung.isEmpty ? '—' : bemerkung,
      ]);
      rowIsRed.add(hasSchaden);
    }

    // PDF Seite
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(12),
        build: (ctx) => [
          headerRow,
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(width: 0.4),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.7),   // Pos
              1: pw.FlexColumnWidth(0.6),   // Typ
              2: pw.FlexColumnWidth(2.5),   // Beschreibung
              3: pw.FlexColumnWidth(2.0),   // Schaden
              4: pw.FlexColumnWidth(2.2),   // Bemerkung
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: headers
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ))
                    .toList(),
              ),
              // Datenzeilen
              ...List.generate(rows.length, (i) {
                final isRed = (i < rowIsRed.length) ? rowIsRed[i] : false;
                final bg = isRed ? PdfColor.fromInt(0xFFFFEBEE) : null;
                final fg = isRed ? PdfColors.red900 : PdfColors.black;

                return pw.TableRow(
                  decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
                  children: rows[i]
                      .map((c) => pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text(c, style: pw.TextStyle(fontSize: 8, color: fg)),
                          ))
                      .toList(),
                );
              }),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// ZIP aus Preview-Plan + Meta.
  /// Neue Ordnerstruktur:
  /// - Hauptordner: ErfasserApp/
  /// - Export-Unterordner: E00000_Musterstraße/
  /// - Aufträge/ (Abteilungen mit 312/313 Struktur)
  /// - Erfassungen/ (Objekte mit Positionsnummern + Gesamtbericht)
  /// - EV Ordner/ (Maßnahme von T22 per Email)
  /// - NIS/ (Plan mit Nummerierung)
  /// - Schriftverkehr/ (alle Emails zur Maßnahme)
  static Future<Uint8List> buildZipFromPlanMeta(
    ExportPlan plan,
    List<Map<String, dynamic>> metas, {
    String? erfasser,
    String? wetter,
    DateTime? zeit,
    String? nisPlanPdfBase64,
  }) async {
    final archive = Archive();

    // Hauptordner mit App-Namen, darin pro Export ein EVNr/Strasse-Unterordner
    final appRootFolder = 'ErfasserApp';
    final exportFolder =
      '${plan.evnr.replaceAll('/', '-')}_${plan.strasse?.replaceAll('/', '-') ?? 'Strasse'}';
    final mainFolder = '$appRootFolder/$exportFolder';

    // erfassungen.json hinzufügen (für Import-Kompatibilität)
    final erfassungenMap = <String, dynamic>{
      plan.evnr: metas,
    };
    final erfassungenJson = jsonEncode(erfassungenMap);
    archive.addFile(
      ArchiveFile(
        '$mainFolder/erfassungen.json',
        erfassungenJson.length,
        utf8.encode(erfassungenJson),
      ),
    );

    // Gesamtbericht im Erfassungen-Ordner
    if (plan.gesamtPdfPlanned) {
      final bytes = await buildGesamtPdfFromMetas(
        evnr: plan.evnr,
        metas: plan.positions.map((p) => p.meta).whereType<Map<String, dynamic>>().toList(),
        erfasser: erfasser,
        strasse: plan.strasse,
        wetter: wetter,
        zeit: zeit,
      );
      archive.addFile(ArchiveFile('$mainFolder/Erfassungen/Gesamt_Bericht.pdf', bytes.length, bytes));
    }

    // Einzelpositionen: Erfassungen/1/, Erfassungen/2/, Erfassungen/3/, ...
    for (final pos in plan.positions) {
      // Verwende positionsnummer, oder als Fallback den Index
      final posNum = (pos.positionsnummer ?? '').trim().isEmpty 
          ? pos.index.toString()
          : (pos.positionsnummer ?? '').trim();
      
      final posFolder = '$mainFolder/Erfassungen/$posNum';
      final meta = pos.meta;

      if (pos.steckbriefPlanned && meta != null) {
        final einzelBytes = await buildEinzelPdfFromMeta(
          meta: meta,
          erfasser: erfasser,
          wetter: wetter,
        );
        archive.addFile(ArchiveFile('$posFolder/Steckbrief.pdf', einzelBytes.length, einzelBytes));

        // DOCX-Formular auf Platzhalterbasis hinzufügen (nur ES/VS)
        final typ = (meta['typ']?.toString() ?? '').trim();
        if (typ == 'ES') {
          final esDocx = await FormularService.buildEinsteigschaechteDocxBytesFromMeta(meta);
          if (esDocx != null && esDocx.isNotEmpty) {
            archive.addFile(ArchiveFile('$posFolder/Erfassungsblatt_Einsteigschacht.docx', esDocx.length, esDocx));
          }
        } else if (typ == 'VS') {
          if (_shouldCreateVsDocx(meta)) {
            final vsDocx = await FormularService.buildSickergrubenDocxBytesFromMeta(meta);
            if (vsDocx != null && vsDocx.isNotEmpty) {
              archive.addFile(ArchiveFile('$posFolder/Erfassung_Sickergrube.docx', vsDocx.length, vsDocx));
            }
          } else {
            debugPrint('⚠️  VG-DOCX für Position $posNum nicht erstellt (Felder unvollständig).');
          }
        }

        // RF-Aufmaßblatt zusätzlich speichern, wenn ES mit Rückenfreiheit
        if (await _shouldAddRfAufmass(meta)) {
          try {
            final rfBytes = await RfAufmassService.buildRfAufmaessPdf(
              evnr: plan.evnr,
              posNr: posNum,
              strasse: plan.strasse,
              erfasser: erfasser,
              zeit: meta['zeit'] != null ? DateTime.tryParse(meta['zeit'] as String) : null,
              meta: meta,
            );
            archive.addFile(ArchiveFile('$posFolder/Aufmass_Ruckenfreiheit.pdf', rfBytes.length, rfBytes));
          } catch (e) {
            debugPrint('⚠️  Fehler beim Erstellen des RF-Aufmaßblatts für Position $posNum: $e');
          }
        }
      }

      // Fotos
      int fotoCounter = 1;
      for (final f in pos.fotos.where((m) => m.planned)) {
        final bytes = await _decodeDataUrl(f.dataUrl);
        if (bytes != null) {
          archive.addFile(ArchiveFile('$posFolder/foto_$fotoCounter.jpg', bytes.length, bytes));
          fotoCounter++;
        }
      }

      // Videos
      int videoCounter = 1;
      for (final v in pos.videos.where((m) => m.planned)) {
        final bytes = await _decodeDataUrl(v.dataUrl);
        if (bytes != null) {
          archive.addFile(ArchiveFile('$posFolder/video_$videoCounter.mp4', bytes.length, bytes));
          videoCounter++;
        }
      }

      // Audios
      int audioCounter = 1;
      for (final a in pos.audios.where((m) => m.planned)) {
        final bytes = await _decodeDataUrl(a.dataUrl);
        if (bytes != null) {
          archive.addFile(ArchiveFile('$posFolder/audio_$audioCounter.webm', bytes.length, bytes));
          audioCounter++;
        }
      }

      // PDFs
      int pdfCounter = 1;
      for (final p in pos.pdfs.where((m) => m.planned)) {
        final bytes = await _decodeDataUrl(p.dataUrl);
        if (bytes != null) {
          archive.addFile(ArchiveFile('$posFolder/pdf_$pdfCounter.pdf', bytes.length, bytes));
          pdfCounter++;
        }
      }
    }

    // Abteilungs-Ordner: Aufträge/ mit 312_IZ AR/, 312_Ost/, 312_Service/, 312_West/, 313_TU/, 313_BU/, 313_BauKo/
    final abteilungsMap = _groupPositionsByAbteilung(plan.positions);
    for (final abteilung in abteilungsMap.keys) {
      final positions = abteilungsMap[abteilung] ?? [];
      
      // Abteilungs-PDF erstellen mit allen Positionen dieser Abteilung
      if (positions.isNotEmpty) {
        final abteilungMetas = positions.map((p) => p.meta).whereType<Map<String, dynamic>>().toList();
        final abteilungPdfBytes = await buildAbteilungsPdfFromMetas(
          abteilung: abteilung,
          evnr: plan.evnr,
          metas: abteilungMetas,
          erfasser: erfasser,
          strasse: plan.strasse,
          wetter: wetter,
          zeit: zeit,
        );
        archive.addFile(ArchiveFile('$mainFolder/Aufträge/$abteilung/Abteilungsbericht_$abteilung.pdf', abteilungPdfBytes.length, abteilungPdfBytes));
      }
      
      for (final pos in positions) {
        final posNum = (pos.positionsnummer ?? pos.index.toString()).trim();
        final abtFolder = '$mainFolder/Aufträge/$abteilung/$posNum';
        final meta = pos.meta;

        if (pos.steckbriefPlanned && meta != null) {
          final einzelBytes = await buildEinzelPdfFromMeta(
            meta: meta,
            erfasser: erfasser,
            wetter: wetter,
          );
          archive.addFile(ArchiveFile('$abtFolder/Steckbrief.pdf', einzelBytes.length, einzelBytes));

          // DOCX-Formular auf Platzhalterbasis auch im Abteilungsordner hinzufügen
          final typ = (meta['typ']?.toString() ?? '').trim();
          if (typ == 'ES') {
            final esDocx = await FormularService.buildEinsteigschaechteDocxBytesFromMeta(meta);
            if (esDocx != null && esDocx.isNotEmpty) {
              archive.addFile(ArchiveFile('$abtFolder/Erfassungsblatt_Einsteigschacht.docx', esDocx.length, esDocx));
            }
          } else if (typ == 'VS') {
            if (_shouldCreateVsDocx(meta)) {
              final vsDocx = await FormularService.buildSickergrubenDocxBytesFromMeta(meta);
              if (vsDocx != null && vsDocx.isNotEmpty) {
                archive.addFile(ArchiveFile('$abtFolder/Erfassung_Sickergrube.docx', vsDocx.length, vsDocx));
              }
            } else {
              debugPrint('⚠️  VG-DOCX für Position $posNum im Abteilungsordner nicht erstellt (Felder unvollständig).');
            }
          }

          // RF-Aufmaßblatt zusätzlich speichern, wenn ES mit Rückenfreiheit
          if (await _shouldAddRfAufmass(meta)) {
            try {
              final rfBytes = await RfAufmassService.buildRfAufmaessPdf(
                evnr: plan.evnr,
                posNr: posNum,
                strasse: plan.strasse,
                erfasser: erfasser,
                zeit: meta['zeit'] != null ? DateTime.tryParse(meta['zeit'] as String) : null,
                meta: meta,
              );
              archive.addFile(ArchiveFile('$abtFolder/Aufmass_Ruckenfreiheit.pdf', rfBytes.length, rfBytes));
            } catch (e) {
              debugPrint('⚠️  Fehler beim Erstellen des RF-Aufmaßblatts für Position $posNum: $e');
            }
          }
        }

        // Fotos
        int fotoCounter = 1;
        for (final f in pos.fotos.where((m) => m.planned)) {
          final bytes = await _decodeDataUrl(f.dataUrl);
          if (bytes != null) {
            archive.addFile(ArchiveFile('$abtFolder/foto_$fotoCounter.jpg', bytes.length, bytes));
            fotoCounter++;
          }
        }

        // Videos
        int videoCounter = 1;
        for (final v in pos.videos.where((m) => m.planned)) {
          final bytes = await _decodeDataUrl(v.dataUrl);
          if (bytes != null) {
            archive.addFile(ArchiveFile('$abtFolder/video_$videoCounter.mp4', bytes.length, bytes));
            videoCounter++;
          }
        }

        // Audios
        int audioCounter = 1;
        for (final a in pos.audios.where((m) => m.planned)) {
          final bytes = await _decodeDataUrl(a.dataUrl);
          if (bytes != null) {
            archive.addFile(ArchiveFile('$abtFolder/audio_$audioCounter.webm', bytes.length, bytes));
            audioCounter++;
          }
        }

        // PDFs
        int pdfCounter = 1;
        for (final p in pos.pdfs.where((m) => m.planned)) {
          final bytes = await _decodeDataUrl(p.dataUrl);
          if (bytes != null) {
            archive.addFile(ArchiveFile('$abtFolder/pdf_$pdfCounter.pdf', bytes.length, bytes));
            pdfCounter++;
          }
        }
      }
    }

    // Platzhalter-Ordner für EV Ordner, NIS und Schriftverkehr
    // Diese werden mit einer Readme.txt Datei befüllt
    archive.addFile(ArchiveFile(
      '$mainFolder/EV Ordner/README.txt',
      57,
      utf8.encode('Hier kommen Maßnahmen von T22 per Email rein.'),
    ));
    
    // NIS-Ordner: PDF hinzufügen, falls vorhanden, sonst README
    if (nisPlanPdfBase64 != null && nisPlanPdfBase64.isNotEmpty) {
      try {
        final pdfBytes = base64Decode(nisPlanPdfBase64);
        archive.addFile(ArchiveFile(
          '$mainFolder/NIS/Plan.pdf',
          pdfBytes.length,
          pdfBytes,
        ));
      } catch (e) {
        // Fallback bei Fehler: README
        archive.addFile(ArchiveFile(
          '$mainFolder/NIS/README.txt',
          49,
          utf8.encode('Hier kommt der Plan mit Nummerierung rein.'),
        ));
      }
    } else {
      archive.addFile(ArchiveFile(
        '$mainFolder/NIS/README.txt',
        49,
        utf8.encode('Hier kommt der Plan mit Nummerierung rein.'),
      ));
    }
    
    archive.addFile(ArchiveFile(
      '$mainFolder/Schriftverkehr/README.txt',
      53,
      utf8.encode('Hier kommen alle Emails zur Maßnahme rein.'),
    ));

    // Vorgefertigte Emails für jede Abteilung in Schriftverkehr/Vorlagen/
    _generateAbteilungEmails(
      archive,
      mainFolder,
      abteilungsMap,
      erfasser,
      evnr: plan.evnr,
      strasse: plan.strasse,
    );

    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes);
  }

  /// Einzel-PDF direkt aus Meta.
  /// (Für ES ist es jetzt 1:1, weil metaToFields exakt die Screen-Reihenfolge mappt.)
  static Future<Uint8List> buildEinzelPdfFromMeta({
    required Map<String, dynamic> meta,
    String? erfasser,
    String? wetter,
  }) async {
    final typ = (meta['typ'] as String?) ?? 'DIV';

    final fields = SpeicherService.metaToFields(
      meta,
      erfasser: erfasser ?? (meta['erfasser'] as String?),
      strasse: (meta['strasse'] as String?),
      wetter: wetter ?? (meta['wetter'] as String?),
    );
    
    if (typ == 'LÜ') {
      debugPrint('[buildEinzelPdfFromMeta] LÜ fields: $fields');
    }

    final notes = <String>[];
    final mediaHint = _mediaHint(meta);
    if (mediaHint.isNotEmpty) notes.add(mediaHint);

    switch (typ) {
      case 'ES':
        final rf = _rfActive(meta);
        final bytes = await PdfMiniKit.esSteckbrief(fields: fields, rf: rf, notes: notes);
        return Uint8List.fromList(bytes);

      case 'VS':
        // Grube
        return await PdfMiniKit.gSteckbrief(fields: fields, notes: notes);

      case 'SSK':
        final leitungRows = <Map<String, String>>[];
        final raw = meta['leitung'];
        if (raw is List) {
          for (final it in raw) {
            if (it is Map) {
              final m = Map<String, dynamic>.from(it);
              final meter = (m['meter'] ?? '').toString();
              final art = (m['art'] ?? '').toString();
              if (meter.trim().isEmpty && art.trim().isEmpty) continue;
              leitungRows.add({'meter': meter, 'art': art});
            }
          }
        }
        return await PdfMiniKit.sskSteckbrief(
          felder: fields,
          leitungRows: leitungRows,
          notizen: notes,
        );

      case 'LÜ':
        return await PdfMiniKit.lSteckbrief(fields: fields, notes: notes);

      case 'SK':
        return await PdfMiniKit.skSteckbrief(fields: fields, notes: notes);

      case 'KANAL':
        return await PdfMiniKit.divSteckbrief(
          fields: fields,
          notes: notes,
          title: 'KANAL – Steckbrief',
        );

      case 'DIV':
      default:
        return await PdfMiniKit.divSteckbrief(fields: fields, notes: notes);
    }
  }

  // -------------------- Helpers --------------------

  static bool _rfActive(Map<String, dynamic> meta) {
    final schaeden = meta['schaeden'];
    
    // Handle both List<dynamic> and String formats
    if (schaeden is List) {
      final hasRF = schaeden.map((e) => e.toString().trim()).contains('Keine Rückenfreiheit');
      if (hasRF) return true;
    } else if (schaeden is String) {
      // If stored as CSV string, split and check
      final hasRF = schaeden.split(',').map((e) => e.trim()).contains('Keine Rückenfreiheit');
      if (hasRF) return true;
    }
    
    // Fallback: RF aktivieren, wenn RF-Maßfelder gefüllt sind (wie beim manuellen Eingeben)
    const rfKeys = [
      'st1Hoehe', 'st1Rf', 'st2Hoehe', 'st2Rf',
      'mAusgleich', 'mKonusAnf', 'mKonusEnd', 'mBerme', 'mSolltiefe',
    ];
    final hasRfFields = rfKeys.any((k) {
      final v = meta[k];
      return v != null && v.toString().trim().isNotEmpty;
    });
    return hasRfFields;
  }

  static List<String> _augmentEsSchaeden(List<dynamic> schaeden) {
    final list = schaeden.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    if (list.contains('1. Steigeisen entfernen') && list.contains('Leiter einbauen')) {
      list.add('Leiter einbau möglich');
    }
    return list;
  }

  static String _metaTitel(Map<String, dynamic> meta) {
    final typ = (meta['typ'] as String?) ?? 'DIV';
    final bool keinBefund = meta['keinBefund'] == true;
    final List<dynamic> schaedenListRaw = (meta['schaeden'] as List<dynamic>?) ?? const [];
    final schaeden = typ == 'ES'
      ? _augmentEsSchaeden(schaedenListRaw)
      : schaedenListRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();

    if (keinBefund) return 'Kein Befund';

    if (schaeden.isNotEmpty) {
      return schaeden.join(', ');
    }

    // Typ-spezifische Titel
    if (typ == 'G' || typ == 'VS') {
      // Im Gesamtbericht: nur Hinweis, was noch gebraucht wird.
      final missing = <String>[];
      final wasser = (meta['wasserstand'] ?? meta['wasser_cm'] ?? '').toString().trim();
      final tiefe = (meta['grubentiefe'] ?? meta['tiefe_cm'] ?? '').toString().trim();
      final anschlussJa = meta['anschlussJa'] == true;
      final anschlussRaw = (meta['anschluss'] ?? '').toString().trim().toLowerCase();
      final hasAnschlussValue = anschlussJa || anschlussRaw == 'ja' || anschlussRaw == 'nein';
      final anschlussIstJa = anschlussJa || anschlussRaw == 'ja';
      final teller = (meta['teller'] ?? '').toString().trim();

      if (wasser.isEmpty) missing.add('Wasserstand');
      if (tiefe.isEmpty) missing.add('Grubentiefe');
      if (!hasAnschlussValue) missing.add('Anschluss');
      // Überlauf nur relevant, wenn Anschluss = ja
      if (anschlussIstJa && teller.isEmpty) missing.add('Überlauf');

      if (missing.isNotEmpty) return 'Noch benötigt: ${missing.join(', ')}';
      return '—';
    }
    if (typ == 'DIV') {
      final t = (meta['titel'] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }

    return '—';
  }

  static String _deckelart(Map<String, dynamic> meta) {
    // SSK: aus sskTyp oder gruppe/auspraegung ableiten
    final sskTyp = (meta['sskTyp'] ?? meta['Deckelart'] ?? '').toString().trim();
    if (sskTyp.isNotEmpty) return sskTyp;
    final typ = (meta['typ'] as String?) ?? '';
    if (typ == 'SSK') {
      final gruppe = (meta['gruppe'] ?? '').toString().trim();
      final auspr = (meta['auspraegung'] ?? '').toString().trim();
      if (gruppe.isNotEmpty && auspr.isNotEmpty) {
        if (gruppe == 'SSK Münchner Modell') return 'Münchner Modell - $auspr';
        if (auspr.toLowerCase().startsWith('bemerkung:')) {
          final txt = auspr.substring('Bemerkung:'.length).trim();
          return 'Weitere Hersteller - ${txt.isEmpty ? 'Bemerkung' : txt}';
        }
        return 'Weitere Hersteller - $auspr';
      }
    }
    // VS/ES/Grube: Deckel/Deckelart falls vorhanden
    if (typ == 'VS' || typ == 'G' || typ == 'ES') {
      final deckel = (meta['deckel'] ?? meta['deckelart'] ?? '').toString().trim();
      if (deckel.isNotEmpty) return deckel;
    }
    // Lüftung: Alt/Neu als Deckelart anzeigen
    if (typ == 'LÜ') {
      final art = (meta['art'] ?? meta['typ_detail'] ?? '').toString().trim();
      if (art.isNotEmpty) return art;
    }
    // SK: ggf. deckelart vorhanden, sonst leer
    final deckel = (meta['deckel'] ?? meta['deckelart'] ?? '').toString().trim();
    if (deckel.isNotEmpty) return deckel;
    return '';
  }

  static String _aufbau(Map<String, dynamic> meta) {
    final typ = (meta['typ'] as String?) ?? '';
    if (typ == 'SSK') {
      final gruppe = (meta['gruppe'] ?? '').toString().trim();
      final auspr = (meta['auspraegung'] ?? '').toString().trim();
      if (gruppe.isNotEmpty && auspr.isNotEmpty) {
        if (gruppe == 'SSK Münchner Modell') return 'Münchner Modell - $auspr';
        if (auspr.toLowerCase().startsWith('bemerkung:')) {
          final txt = auspr.substring('Bemerkung:'.length).trim();
          return txt.isEmpty ? 'Bemerkung' : txt;
        }
        return auspr;
      }
    }
    if (typ == 'ES') {
      // Für Gesamt-PDF soll der Zugang (Seiteneinstieg/Direkteinstieg) angezeigt werden
      final eingang = (meta['eingang'] ?? meta['Eingang'] ?? '').toString().trim();
      if (eingang.isNotEmpty) return eingang;
      final einsteigart = (meta['einsteigart'] ?? '').toString().trim();
      if (einsteigart.isNotEmpty) return einsteigart;
    }
    if (typ == 'VS' || typ == 'G') {
      final grubentyp = (meta['grubentyp'] ?? meta['grubenart'] ?? '').toString().trim();
      if (grubentyp.isNotEmpty) return grubentyp;
    }
    if (typ == 'LÜ') {
      // Aufbau/Eingang = Alt/Neu; bei Neu bleibt KL separat
      final art = (meta['art'] ?? meta['typ_detail'] ?? '').toString().trim();
      if (art.isNotEmpty) return art;
    }
    if (typ == 'SK') {
      final td = (meta['typ_detail'] ?? '').toString().trim();
      if (td.isNotEmpty) return td;
    }
    final titel = (meta['titel'] ?? '').toString().trim();
    if (titel.isNotEmpty) return titel;
    return '';
  }

  static String _mediaHint(Map<String, dynamic> meta) {
    final fotos = (meta['mediaFotos'] as List<dynamic>?)?.length ?? 0;
    final videos = (meta['mediaVideos'] as List<dynamic>?)?.length ?? 0;
    final audios = (meta['mediaAudios'] as List<dynamic>?)?.length ?? 0;
    final types = <String>[];
    if (fotos > 0) types.add('Foto');
    if (videos > 0) types.add('Video');
    if (audios > 0) types.add('Audio');
    if (types.isEmpty) return '';
    return types.join(' + ');
  }

  static String _mergeBemerkung(String bemerkung, String mediaHint) {
    if (mediaHint.isEmpty) return bemerkung;
    if (bemerkung.isEmpty) return mediaHint;
    if (bemerkung.contains('Medien:')) return bemerkung; // doppelt vermeiden
    return '$bemerkung | $mediaHint';
  }

  static String _csvJoin(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(', ');
    }
    return (value ?? '').toString().trim();
  }

  static String _csvLine(List<String> values) {
    return values.map(_csvEscape).join(';');
  }

  static String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }


  /// Gruppiert Positionen nach Abteilung.
  /// Unterstützt neue 312/313 Abteilungen und alte Kurznamen
  static Map<String, List<PlannedPosition>> _groupPositionsByAbteilung(
      List<PlannedPosition> positions) {
    final groups = <String, List<PlannedPosition>>{};

    // Positionen nach ihren Abteilungen verteilen
    for (final pos in positions) {
      final meta = pos.meta;
      if (meta == null) continue;

      // Neue 312/313 Struktur: einzelnes 'abteilung' Feld
      final abteilungSingle = (meta['abteilung'] as String?)?.trim();
      if (abteilungSingle != null && abteilungSingle.isNotEmpty) {
        if (!groups.containsKey(abteilungSingle)) {
          groups[abteilungSingle] = <PlannedPosition>[];
        }
        groups[abteilungSingle]!.add(pos);
      }

      // Fallback: 'abteilungen' Liste (Plural) - für neue 312/313 Struktur
      final abteilungenRaw = meta['abteilungen'] as List<dynamic>?;
      if (abteilungenRaw != null && abteilungenRaw.isNotEmpty) {
        for (final ab in abteilungenRaw) {
          final abStr = ab.toString().trim();
          if (abStr.isEmpty) continue;
          
          // Neue 312/313 Abteilungen direkt verwenden
          if (abStr.startsWith('312') || abStr.startsWith('313')) {
            if (!groups.containsKey(abStr)) {
              groups[abStr] = <PlannedPosition>[];
            }
            groups[abStr]!.add(pos);
            continue;
          }
          
          // Fallback für alte Kurznamen (falls noch vorhanden)
          String? key;
          if (abStr.startsWith('Maurer') || abStr == 'M') {
            key = 'M';
          } else if (abStr.startsWith('Schlosser') || abStr == 'S') {
            key = 'S';
          } else if (abStr.startsWith('Baukontrollmeister') || abStr == 'BAUKO') {
            key = 'BAUKO';
          } else if (abStr == 'NIS') {
            key = 'NIS';
          } else if (abStr.startsWith('Reinigung') || abStr == 'R') {
            key = 'R';
          }

          if (key != null) {
            if (!groups.containsKey(key)) {
              groups[key] = <PlannedPosition>[];
            }
            groups[key]!.add(pos);
          }
        }
      }
    }

    // Leere Gruppen entfernen
    groups.removeWhere((_, positions) => positions.isEmpty);

    return groups;
  }

  static Future<Uint8List?> _decodeDataUrl(String dataUrl) async {
    // Handle data URLs (data:image/png;base64,...)
    final idx = dataUrl.indexOf(',');
    if (idx != -1) {
      final base64Part = dataUrl.substring(idx + 1);
      try {
        return Uint8List.fromList(base64Decode(base64Part));
      } catch (_) {
        return null;
      }
    }
    
    // Handle asset file paths (App/ES/ES_Bild.png) - for test data
    if (dataUrl.startsWith('App/')) {
      try {
        // rootBundle.load automatically adds 'assets/' prefix, so use path as-is
        final ByteData data = await rootBundle.load(dataUrl);
        debugPrint('[_decodeDataUrl] Loaded asset: $dataUrl (${data.lengthInBytes} bytes)');
        return data.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }
    
    return null;
  }

  /// Generiert vorgefertigte Emails für jede Abteilung
  static void _generateAbteilungEmails(
    Archive archive,
    String mainFolder,
    Map<String, List<PlannedPosition>> abteilungsMap,
    String? erfasser,
    {
    required String evnr,
    required String? strasse,
  }
  ) {
    final informed = abteilungsMap.keys.toList()..sort();
    for (final abteilung in abteilungsMap.keys) {
      final positions = abteilungsMap[abteilung] ?? [];
      if (positions.isEmpty) continue;

      // Email-Inhalt generieren
      final emailContent = _buildAbteilungEmailContent(
        abteilung,
        positions,
        erfasser,
        ordnerLink: '$mainFolder/Schriftverkehr',
        evnr: evnr,
        strasse: strasse,
      );
      final emailBytes = utf8.encode(emailContent);

      // Dateiname: Abteilung.txt (z.B. 312_IZ_AR.txt)
      final fileName = '${abteilung.replaceAll(' ', '_')}.txt';
      archive.addFile(ArchiveFile(
        '$mainFolder/Schriftverkehr/Vorlagen/$fileName',
        emailBytes.length,
        emailBytes,
      ));
    }

    if (informed.isNotEmpty) {
      final emailContent = _buildBauKoAbschlussEmail(
        erfasser: erfasser,
        ordnerLink: '$mainFolder/Schriftverkehr',
        abteilungen: informed,
        evnr: evnr,
        strasse: strasse,
      );
      final emailBytes = utf8.encode(emailContent);
      archive.addFile(ArchiveFile(
        '$mainFolder/Schriftverkehr/Vorlagen/BauKo_Abschluss.txt',
        emailBytes.length,
        emailBytes,
      ));
    }
  }

  /// Erstellt den Inhalt einer Abteilungs-Email
  static String _buildAbteilungEmailContent(
    String abteilung,
    List<PlannedPosition> positions,
    String? erfasser, {
    required String ordnerLink,
    required String evnr,
    required String? strasse,
  }
  ) {
    final buffer = StringBuffer();
    final str = (strasse ?? 'Strasse').trim();

    buffer.writeln('Betreff: EVNr $evnr - $str');
    buffer.writeln();

    buffer.writeln('Hallo zusammen,');
    buffer.writeln();
    buffer.writeln('im Rahmen der Erfassung sind mir folgende Punkte aufgefallen:');
    buffer.writeln();
    for (final pos in positions) {
      final posNum = (pos.positionsnummer ?? '').trim().isNotEmpty
          ? (pos.positionsnummer ?? '').trim()
          : pos.index.toString();

      String objektart = 'DIV';
      String beobachtung = '—';

      if (pos.meta != null) {
        final meta = pos.meta!;
        final typ = (meta['typ'] as String?) ?? 'DIV';
        objektart = _objektartLabel(typ);

        final keinBefund = meta['keinBefund'] == true;
        final schaedenListRaw = (meta['schaeden'] as List<dynamic>?) ?? const [];
        final schaeden = schaedenListRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
        if (keinBefund) {
          beobachtung = 'Kein Befund';
        } else if (schaeden.isNotEmpty) {
          beobachtung = schaeden.join(', ');
        } else {
          final titel = (meta['titel'] ?? '').toString().trim();
          beobachtung = titel.isNotEmpty ? titel : '—';
        }
      } else if (pos.entry != null) {
        final entry = pos.entry!;
        objektart = _objektartFromEntry(entry.type);
        beobachtung = entry.summaryShort;
      }

      buffer.writeln('- **$posNum ($objektart):** $beobachtung');
    }
    buffer.writeln();
    buffer.writeln('Weitere Unterlagen und Details sind im folgenden Ordner abgelegt:');
    buffer.writeln('**$ordnerLink**');
    buffer.writeln();
    buffer.writeln('Viele Grüße');
    buffer.writeln();
    buffer.writeln('**${erfasser ?? '{ERFASSER_NAME}'}**');
    buffer.writeln(abteilung.isNotEmpty ? abteilung : '{ABTEILUNG}');
    buffer.writeln('{FIRMA}');
    buffer.writeln('Tel.: {TELEFON}');
    buffer.writeln('E-Mail: {E_MAIL}');

    return buffer.toString();
  }

  static String _buildBauKoAbschlussEmail({
    required List<String> abteilungen,
    required String ordnerLink,
    String? erfasser,
    required String evnr,
    required String? strasse,
  }) {
    final buffer = StringBuffer();
    final str = (strasse ?? 'Strasse').trim();
    buffer.writeln('Betreff: EVNr $evnr - $str');
    buffer.writeln();
    buffer.writeln('Hallo BauKo,');
    buffer.writeln();
    buffer.writeln('die Abteilungen wurden informiert. Folgende Stellen wurden angeschrieben:');
    buffer.writeln();
    for (final a in abteilungen) {
      buffer.writeln('- $a');
    }
    buffer.writeln();
    buffer.writeln('Weitere Unterlagen und Details sind im folgenden Ordner abgelegt:');
    buffer.writeln('**$ordnerLink**');
    buffer.writeln();
    buffer.writeln('Viele Gruesse');
    buffer.writeln();
    buffer.writeln('**${erfasser ?? '{ERFASSER_NAME}'}**');
    buffer.writeln('{ABTEILUNG}');
    buffer.writeln('{FIRMA}');
    buffer.writeln('Tel.: {TELEFON}');
    buffer.writeln('E-Mail: {E_MAIL}');
    return buffer.toString();
  }

  static String _objektartLabel(String typ) {
    switch (typ) {
      case 'ES':
        return 'Einsteigschacht';
      case 'VS':
        return 'Verteilschacht';
      case 'G':
        return 'Grube';
      case 'LÜ':
        return 'Lueftung';
      case 'SSK':
        return 'SSK';
      case 'SK':
        return 'Schieberkasten';
      case 'DIV':
      default:
        return 'DIV';
    }
  }

  /// Prüft, ob das RF-Aufmaßblatt generiert werden soll
  /// Bedingung: Typ ist ES (Einstiegschacht) und Schäden enthalten "Keine Rückenfreiheit"
  static Future<bool> _shouldAddRfAufmass(Map<String, dynamic> meta) async {
    final typ = (meta['typ'] as String?)?.toUpperCase() ?? '';
    if (typ != 'ES') return false; // Nur für Einstiegsschächte

    final schaeden = <String>[];
    final raw = meta['schaeden'];
    if (raw is List) {
      schaeden.addAll(raw.map((e) => e.toString().trim()));
    } else if (raw is String) {
      schaeden.addAll(raw.split(',').map((e) => e.trim()));
    }

    // Nur bei exakt gesetztem Schaden "Keine Rückenfreiheit".
    return schaeden.contains('Keine Rückenfreiheit');
  }

  /// VG-Formular nur erzeugen, wenn die relevanten Felder vorhanden sind.
  static bool _shouldCreateVsDocx(Map<String, dynamic> meta) {
    final tiefe = (meta['tiefe_cm'] ?? '').toString().trim();
    final wasser = (meta['wasser_cm'] ?? '').toString().trim();
    final anschlussJa = meta['anschlussJa'] == true;
    final anschlussNein = meta['anschlussJa'] == false;
    final teller = (meta['teller'] ?? '').toString().trim();

    if (tiefe.isEmpty || wasser.isEmpty) return false;
    if (!anschlussJa && !anschlussNein) return false;
    if (anschlussJa && teller.isEmpty) return false;
    return true;
  }

  static String _objektartFromEntry(EntryType type) {
    switch (type) {
      case EntryType.einsteigschacht:
        return 'Einsteigschacht';
      case EntryType.grube:
        return 'Grube';
      case EntryType.lueftung:
        return 'Lueftung';
      case EntryType.ssk:
        return 'SSK';
      case EntryType.schieberkappe:
        return 'Schieberkappe';
      case EntryType.kanal:
        return 'Kanal';
      case EntryType.sonstige:
        return 'Sonstiges';
      case EntryType.div:
        return 'DIV';
    }
  }
}


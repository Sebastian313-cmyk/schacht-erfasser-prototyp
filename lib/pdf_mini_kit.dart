import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfMiniKit {
  static final DateFormat _dfDate = DateFormat('dd.MM.yyyy HH:mm');

  static Future<pw.ThemeData> _theme() async {
    try {
      final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
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

  /// Datum/Zeit aus ISO (z.B. 2025-01-01T12:34:56.000) in dd.MM.yyyy HH:mm.
  /// Wenn kein ISO: Wert unverändert.
  static String _formatMaybeIso(String value) {
    final t = value.trim();
    if (t.isEmpty || t == '—' || t == '-') return '—';
    if (!t.contains('T')) return t;
    try {
      final dt = DateTime.tryParse(t);
      if (dt == null) return t;
      return _dfDate.format(dt);
    } catch (_) {
      return t;
    }
  }

  // (entfernt: ungenutzte Helper)

  static Future<Uint8List> divSteckbrief({
    required Map<String, String> fields,
    List<String>? notes,
    String title = 'DIV – Sonstiges – Steckbrief',
  }) async {
    final evnr = fields['EVNr'] ?? '—';
    final posNr = fields['Positionsnummer'] ?? '—';
    final idNr = fields['ID-Nummer'];
    final strasse = fields['Straße'] ?? '—';
    final erfasser = fields['Erfasser:in'] ?? '—';
    final datumZeit = _formatMaybeIso(fields['Datum/Zeit'] ?? '—');
    final wetter = fields['Wetter'] ?? '—';
    final gps = fields['GPS'] ?? '—';

    final details = Map<String, String>.from(fields);
    details.removeWhere((k, v) => ['EVNr', 'Positionsnummer', 'ID-Nummer', 'Straße', 'Erfasser:in', 'Datum/Zeit', 'Wetter', 'GPS'].contains(k));

    final doc = pw.Document(theme: await _theme());
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _headerSection(
              title: title,
              evnr: evnr,
              posNr: posNr,
              idNr: idNr,
              strasse: strasse,
              erfasser: erfasser,
              datumZeit: datumZeit,
              wetter: wetter,
              gps: gps,
            ),
            pw.Text('Vor-Ort-Befund', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _detailsTable(details),
            if (notes != null && notes.isNotEmpty) _notes(notes),
          ],
        ),
      ),
    );
    return doc.save();
  }
  /// Erstellt ein Steckbrief-PDF für Einsteig (ES)
  static Future<List<int>> einsteigSteckbrief({
    required Map<String, String> fields,
    List<String>? notes,
  }) async {
    // Leite an die ES-spezifische Implementierung weiter
    final data = await PdfMiniKit.esSteckbrief(fields: fields, notes: notes);
    return data;
  }

  /// Steckbrief-PDF für Grube (minimal, analog zu anderen Modulen)
  static Future<List<int>> grubenSteckbrief({
    required Map<String, String> fields,
    List<String>? notes,
  }) async {
    // Verwende die bereits vorhandene gSteckbrief-Implementierung.
    final data = await PdfMiniKit.gSteckbrief(fields: fields, notes: notes);
    return data;
  }
  static Future<Uint8List> skSteckbrief({
    required Map<String, String> fields,
    List<String>? notes,
  }) async {
    final evnr = fields['EVNr'] ?? '—';
    final posNr = fields['Positionsnummer'] ?? '—';
    final idNr = fields['ID-Nummer'];
    final strasse = fields['Straße'] ?? '—';
    final erfasser = fields['Erfasser:in'] ?? '—';
    final datumZeit = fields['Datum/Zeit'] ?? '—';
    final wetter = fields['Wetter'] ?? '—';
    final gps = fields['GPS'] ?? '—';

    final details = Map<String, String>.from(fields);
    details.removeWhere((k, v) => ['EVNr', 'Positionsnummer', 'ID-Nummer', 'Straße', 'Erfasser:in', 'Datum/Zeit', 'Wetter', 'GPS'].contains(k));

    final doc = pw.Document(theme: await _theme());
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _headerSection(
              title: 'SK - Schieberkappen - Steckbrief',
              evnr: evnr,
              posNr: posNr,
              idNr: idNr,
              strasse: strasse,
              erfasser: erfasser,
              datumZeit: datumZeit,
              wetter: wetter,
              gps: gps,
            ),
            pw.Text('Vor-Ort-Befund', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _detailsTable(details),
            if (notes != null && notes.isNotEmpty) _notes(notes),
          ],
        ),
      ),
    );
    return doc.save();
  }
  static Future<Uint8List> gSteckbrief({
    required Map<String, String> fields,
    List<String>? notes,
  }) async {
    bool filled(String? v) {
      final t = (v ?? '').trim();
      return t.isNotEmpty && t != '—' && t != '-';
    }

    void putIfFilled(Map<String, String> m, String k, String? v) {
      if (filled(v)) m[k] = v!.trim();
    }

    String? findFirst(Map<String, String> map, List<String> keys) {
      for (final k in keys) {
        final v = map[k];
        if (filled(v)) return v!.trim();
      }
      return null;
    }

    String? cmFromPossible(Map<String, String> map, String cmKey, String humanCmKey, String mKey) {
      // Prefer normalized cmKey, fallback to human-readable cm, then to meters (convert)
      final a = findFirst(map, [cmKey, humanCmKey]);
      if (filled(a)) return a;
      final mVal = findFirst(map, [mKey]);
      if (mVal != null) {
        final n = num.tryParse(mVal.replaceAll(',', '.'));
        if (n != null) {
          final cm = (n * 100);
          // Format: if integer, no decimals, else up to 2
          if (cm % 1 == 0) return cm.toInt().toString();
          return cm.toStringAsFixed(2);
        }
      }
      return null;
    }

    final evnr = fields['EVNr'] ?? '—';
    final posNr = fields['Positionsnummer'] ?? '—';
    final idNr = fields['ID-Nummer'];
    final strasse = fields['Straße'] ?? '—';
    final erfasser = fields['Erfasser:in'] ?? '—';
    final datumZeit = fields['Datum/Zeit'] ?? '—';
    final wetter = fields['Wetter'] ?? '—';
    final gps = fields['GPS'] ?? '—';

    // Reihenfolge wie Screen
    // orderedKeys list removed (we build fields explicitly for robustness)

    final details = <String, String>{};
    putIfFilled(details, 'Positionsnummer', posNr);
    if (filled(idNr)) details['ID-Nummer'] = idNr!;

    // First add basic fields (robust mit Synonymen)
    putIfFilled(details, 'Verfügbarkeit', findFirst(fields, ['Verfügbarkeit', 'verfuegbarkeit']));
    putIfFilled(details, 'Status vor Ort', findFirst(fields, ['Status vor Ort', 'statusVorOrt']));
    putIfFilled(details, 'Grubenart', findFirst(fields, ['Grubenart', 'Grubentyp', 'grubentyp']));
    putIfFilled(details, 'Deckelart', findFirst(fields, ['Deckelart', 'Deckel', 'deckel']));
    putIfFilled(details, 'KL', findFirst(fields, ['KL', 'kl']));
    putIfFilled(details, 'Schäden', findFirst(fields, ['Schäden', 'schaeden']));

    // Tiefe (cm)
    final tiefe = cmFromPossible(fields, 'tiefe_cm', 'Grubentiefe (cm)', 'tiefe_m');
    if (filled(tiefe)) details['Grubentiefe (cm)'] = tiefe!;

    // Wasserstand (cm)
    final wasser = cmFromPossible(fields, 'wasser_cm', 'Wasserstand (cm)', 'wasser_m');
    if (filled(wasser)) details['Wasserstand (cm)'] = wasser!;

    // Rest
    putIfFilled(details, 'Anschluss am Kanal', findFirst(fields, ['anschluss', 'Anschluss am Kanal']));
    putIfFilled(details, 'Überlauf', findFirst(fields, ['teller', 'Teller', 'Überlauf']));
    putIfFilled(details, 'Bemerkung', findFirst(fields, ['Bemerkung', 'bemerkung', 'Bemerkung']));

    final doc = pw.Document(theme: await _theme());
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _headerSection(
              title: 'G - Grube - Steckbrief',
              evnr: evnr,
              posNr: posNr,
              idNr: idNr,
              strasse: strasse,
              erfasser: erfasser,
              datumZeit: datumZeit,
              wetter: wetter,
              gps: gps,
            ),
            pw.Text('Vor-Ort-Befund', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            if (details.isEmpty) pw.Text('—') else _detailsTable(details),
            if (notes != null && notes.isNotEmpty) _notes(notes),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> gGesamtGruben({
    required String evnr,
    required List<Map<String, String>> rows,
  }) async {
    pw.Widget tableG(List<Map<String, String>> data) {
      final header = pw.TableRow(children: [
        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Wasserstand (cm)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Grubentiefe (cm)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Anschluss', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Überlauf', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Art', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      ]);
      final dataRows = data
          .map((r) => pw.TableRow(children: [
                pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(r['wasser_cm']?.replaceAll('.', ',') ?? r['wasser_m']?.replaceAll('.', ',') ?? '')),
                pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(r['tiefe_cm']?.replaceAll('.', ',') ?? r['tiefe_m']?.replaceAll('.', ',') ?? '')),
                pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(r['anschluss'] ?? '')),
                pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(r['teller'] ?? '')),
                pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(r['art'] ?? '')),
              ]))
          .toList();
      return pw.Table(border: pw.TableBorder.all(width: 0.5), children: [header, ...dataRows]);
    }

    final doc = pw.Document(theme: await _theme());
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('G - Gruben - Gesamtblatt (EVNr: $evnr)',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            tableG(rows),
          ],
        ),
      ),
    );
    return doc.save();
  }
  static Future<Uint8List> lSteckbrief({
    required Map<String, String> fields,
    List<String>? notes,
  }) async {
    final evnr = fields['EVNr'] ?? '—';
    final posNr = fields['Positionsnummer'] ?? '—';
    final idNr = fields['ID-Nummer'];
    final strasse = fields['Straße'] ?? '—';
    final erfasser = fields['Erfasser:in'] ?? '—';
    final datumZeit = fields['Datum/Zeit'] ?? '—';
    final wetter = fields['Wetter'] ?? '—';
    final gps = fields['GPS'] ?? '—';

    final details = Map<String, String>.from(fields);
    details.removeWhere((k, v) => ['EVNr', 'Positionsnummer', 'ID-Nummer', 'Straße', 'Erfasser:in', 'Datum/Zeit', 'Wetter', 'GPS'].contains(k));

    final doc = pw.Document(theme: await _theme());
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _headerSection(
              title: 'L - Lüftung - Steckbrief',
              evnr: evnr,
              posNr: posNr,
              idNr: idNr,
              strasse: strasse,
              erfasser: erfasser,
              datumZeit: datumZeit,
              wetter: wetter,
              gps: gps,
            ),
            pw.Text('Vor-Ort-Befund', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _detailsTable(details),
            if (notes != null && notes.isNotEmpty) _notes(notes),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> sskSteckbrief({
    required Map<String, String> felder,
    required List<Map<String, String>> leitungRows,
    List<String>? notizen,
  }) async {
    // Extrahiere Kopfzeilen-Daten
    final evnr = felder['EVNr'] ?? '—';
    final posNr = felder['Positionsnummer'] ?? '—';
    final idNr = felder['ID-Nummer'];
    final strasse = felder['Straße'] ?? '—';
    final erfasser = felder['Erfasser:in'] ?? '—';
    final datumZeit = felder['Datum/Zeit'] ?? '—';
    final wetter = felder['Wetter'] ?? '—';
    final gps = felder['GPS'] ?? '—';

    // Vor-Ort-Details (alles außer Kopfzeilen-Infos)
    final details = Map<String, String>.from(felder);
    details.removeWhere((k, v) => ['EVNr', 'Positionsnummer', 'ID-Nummer', 'Straße', 'Erfasser:in', 'Datum/Zeit', 'Wetter', 'GPS'].contains(k));
    // Sicherstellen: Schäden wird angezeigt (Fallback auf 'schaeden')
    if (!(details.containsKey('Schäden') && (details['Schäden'] ?? '').trim().isNotEmpty)) {
      final s = (felder['Schäden'] ?? felder['schaeden'] ?? '').trim();
      if (s.isNotEmpty && s != '—' && s != '-') {
        details['Schäden'] = s;
      }
    }
    // Schäden-Text durch konkrete Leitungsschäden mit Meterangaben ergänzen (z.B. "1m Scherbe, 3m Riss")
    final schadenText = (details['Schäden'] ?? '').trim();
    final pairs = <String>[];
    for (final r in leitungRows) {
      final m = (r['meter'] ?? '').toString().trim();
      final art = (r['art'] ?? '').toString().trim();
      if (m.isEmpty || art.isEmpty) continue;
      final mStr = m.endsWith('m') ? m : '${m}m';
      pairs.add('$mStr $art');
    }
    if (pairs.isNotEmpty) {
      final summary = pairs.join(', ');
      if (schadenText.isEmpty || schadenText == '—' || schadenText == '-') {
        // Nur Leitungsschäden vorhanden -> direkt anzeigen
        details['Schäden'] = summary;
      } else if (schadenText.contains('Leitung kaputt')) {
        // Ersetze "Leitung kaputt" durch die konkrete Auflistung
        final replaced = schadenText.replaceFirst(RegExp(r'Leitung kaputt(\s*\(.*?\))?'), summary);
        details['Schäden'] = replaced;
      } else {
        // An bestehenden Schadenstext anhängen
        details['Schäden'] = '$schadenText | $summary';
      }
    }

    final doc = pw.Document(theme: await _theme());
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _headerSection(
              title: 'Straßensinkkasten - Steckbrief',
              evnr: evnr,
              posNr: posNr,
              idNr: idNr,
              strasse: strasse,
              erfasser: erfasser,
              datumZeit: datumZeit,
              wetter: wetter,
              gps: gps,
            ),
            pw.Text('Vor-Ort-Befund', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _detailsTable(details),
            if (leitungRows.isNotEmpty) _leitungTable(leitungRows),
            if (notizen != null && notizen.isNotEmpty) _notes(notizen),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> esSteckbrief({
    required Map<String, String> fields,
    bool rf = false,
    List<String>? notes,
  }) async {
    bool filledEs(String? v) {
      final t = (v ?? '').trim();
      return t.isNotEmpty && t != '—' && t != '-';
    }

    void putIfFilled(Map<String, String> m, String k, String? v) {
      if (filledEs(v)) m[k] = v!.trim();
    }

    // Kopf
    final evnr = fields['EVNr'] ?? '—';
    final posNr = fields['Positionsnummer'] ?? '—';
    final idNr = fields['ID-Nummer'];
    final strasse = fields['Straße'] ?? '—';
    final erfasser = fields['Erfasser:in'] ?? '—';
    final datumZeit = fields['Datum/Zeit'] ?? '—';
    final wetter = fields['Wetter'] ?? '—';
    final gps = fields['GPS'] ?? '—';

    // Steigeisen / RF
    final st1Hoehe = fields['1. Steigeisen – Steighöhe'];
    final st1Rf = fields['1. Steigeisen – Rückenfreiheit'];
    final st2Hoehe = fields['2. Steigeisen – Steighöhe'];
    final st2Rf = fields['2. Steigeisen – Rückenfreiheit'];

    // Tabelle: zuerst Ident
    final detailsForTable = <String, String>{};
    putIfFilled(detailsForTable, 'Positionsnummer', posNr);
    putIfFilled(detailsForTable, 'ID-Nummer', idNr);

    // Helpers: Maße immer in cm darstellen (ohne Komma-Zwang). Wenn bereits "cm" drin ist, lassen.
    String cm(String v) {
      final t = v.trim();
      if (t.isEmpty) return t;
      if (t.toLowerCase().contains('cm')) return t;
      return '$t cm';
    }

    void putIfFilledCm(String key, String? v) {
      if (filledEs(v)) {
        detailsForTable[key] = cm(v!);
      }
    }

    // 1:1 Reihenfolge wie Screen (nur gefüllte Felder)
    // Verfügbarkeit / Status
    putIfFilled(detailsForTable, 'Verfügbarkeit', fields['Verfügbarkeit']);
    putIfFilled(detailsForTable, 'Status vor Ort', fields['Status vor Ort']);

    // Zugang / Einsteig
    putIfFilled(detailsForTable, 'Eingang', fields['Eingang']);
    putIfFilled(detailsForTable, 'Einsteigart', fields['Einsteigart']);
    // Steigeisen-Stand (Alt/Neu) anzeigen, wenn Einsteigart = Steigeisen
    putIfFilled(detailsForTable, 'Steigeisen (Stand)', fields['steigeisenStand']);
    putIfFilled(detailsForTable, 'Deckelart', fields['Deckelart']);
    putIfFilled(detailsForTable, 'KL', fields['KL']);

    // Schäden
    putIfFilled(detailsForTable, 'Schäden', fields['Schäden']);

    // Objektattribute
    putIfFilled(detailsForTable, 'Schacht Durchmesser', fields['Schacht Durchmesser']);
    putIfFilled(detailsForTable, 'Kanalprofil', fields['Kanalprofil']);

    // Örtlichkeit
    putIfFilled(detailsForTable, 'Örtlichkeit', fields['Örtlichkeit']);
    putIfFilled(detailsForTable, 'Örtlichkeit – Bemerkung', fields['Örtlichkeit – Bemerkung']);

    // Oberfläche
    putIfFilled(detailsForTable, 'Oberflächenart', fields['Oberflächenart']);
    putIfFilled(detailsForTable, 'Oberfläche – Bemerkung', fields['Oberfläche – Bemerkung']);

    // Schachtkopfdaten
    putIfFilled(detailsForTable, 'Schachtkopfdaten', fields['Schachtkopfdaten']);
    putIfFilled(detailsForTable, 'Übergangsplatte (Höhe)', fields['Übergangsplatte (Höhe)']);

    // Maße (nur bei RF aktiv am Screen – aber PDF zeigt nur was gefüllt ist)
    putIfFilledCm('815', fields['815'] ?? fields['Ausgleichsringe']);

    // Steigeisen-Block innerhalb Maße
    final showSt = rf || filledEs(st1Hoehe) || filledEs(st1Rf) || filledEs(st2Hoehe) || filledEs(st2Rf);
    if (showSt) {
      final s1 = [
        if (filledEs(st1Hoehe)) 'Höhe ${cm(st1Hoehe!)}',
        if (filledEs(st1Rf)) 'RF ${cm(st1Rf!)}',
      ].join(' | ');

      final s2 = [
        if (filledEs(st2Hoehe)) 'Höhe ${cm(st2Hoehe!)}',
        if (filledEs(st2Rf)) 'RF ${cm(st2Rf!)}',
      ].join(' | ');

      if (s1.isNotEmpty) detailsForTable['1. Steigeisen'] = s1;
      if (s2.isNotEmpty) detailsForTable['2. Steigeisen'] = s2;
    }

    putIfFilledCm('Konusanfang', fields['Konusanfang']);
    putIfFilledCm('Konusende', fields['Konusende']);
    putIfFilledCm('Berme', fields['Berme']);
    putIfFilledCm('Solltiefe', fields['Solltiefe']);

    // Bemerkung
    putIfFilled(detailsForTable, 'Bemerkung', fields['Bemerkung']);

    final doc = pw.Document(theme: await _theme());
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _headerSection(
              title: 'Einsteigschacht – Steckbrief',
              evnr: evnr,
              posNr: posNr,
              idNr: idNr,
              strasse: strasse,
              erfasser: erfasser,
              datumZeit: datumZeit,
              wetter: wetter,
              gps: gps,
            ),

            pw.Text('Vor-Ort-Befund',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),

            if (detailsForTable.isEmpty)
              pw.Text('—')
            else
              _detailsTable(detailsForTable),

            if (rf) ...[
              pw.SizedBox(height: 14),
                pw.Text('Hinweis: Keine Rückenfreiheit (Maße in cm siehe oben).',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],

            if (notes != null && notes.isNotEmpty) _notes(notes),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _leitungTable(List<Map<String, String>> rows) {
    if (rows.isEmpty) return pw.Container();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),
        pw.Text('Leitungsschäden', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {0: pw.FixedColumnWidth(80), 1: pw.FlexColumnWidth()},
          children: [
            pw.TableRow(children: [
              pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Länge (m)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Art', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ]),
            ...rows.map((e) => pw.TableRow(children: [
              pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(e['meter'] ?? '')),
              pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(e['art'] ?? '')),
            ])),
          ],
        ),
      ],
    );
  }

  

  /// Kopfzeile: kompakt ohne ID (geht in Tabelle), nur EVNr/Straße/Erfasser/Datum/Zeit/Wetter
  static pw.Widget _headerSection({
    required String title,
    required String evnr,
    required String posNr,
    String? idNr,
    required String strasse,
    required String erfasser,
    required String datumZeit,
    required String wetter,
    String? gps,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),

        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1),
            color: PdfColor.fromInt(0xFFE3F2FD),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('EVNr: $evnr', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Straße: $strasse', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Erfasser: $erfasser', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Datum/Zeit: $datumZeit', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Wetter: $wetter', style: const pw.TextStyle(fontSize: 10)),
              if (gps != null && gps.trim().isNotEmpty && gps != '—')
                pw.Text('GPS: $gps', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  /// Details-Tabelle (nur Vor-Ort-Daten: Schaden, Verfügbarkeit, Status, Bemerkung, etc.)
  static pw.Widget _detailsTable(Map<String, String> details) {
    final rows = details.entries
        .map((e) => pw.TableRow(children: [
              pw.Padding(
                  padding: pw.EdgeInsets.all(6),
                  child: pw.Text(e.key,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text(e.value)),
            ]))
        .toList();
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      children: rows,
      columnWidths: {0: pw.FixedColumnWidth(190)},
    );
  }

  

  static pw.Widget _notes(List<String> notes) {
    // Parse media notes (emoji-based or text) and render icons+text when possible
    int fotos = 0;
    int videos = 0;
    final other = <String>[];

    final reCam = RegExp(r'📷\s*(\d+)|Fotos?:\s*(\d+)', multiLine: false);
    final reVid = RegExp(r'🎥\s*(\d+)|Videos?:\s*(\d+)', multiLine: false);

    for (final n in notes) {
      final m1 = reCam.firstMatch(n);
      final m2 = reVid.firstMatch(n);
      if (m1 != null) {
        final v = int.tryParse(m1.group(1) ?? m1.group(2) ?? '0') ?? 0;
        fotos += v;
        continue;
      }
      if (m2 != null) {
        final v = int.tryParse(m2.group(1) ?? m2.group(2) ?? '0') ?? 0;
        videos += v;
        continue;
      }
      other.add(n);
    }

    final children = <pw.Widget>[];
    children.add(pw.SizedBox(height: 12));
    children.add(pw.Text('Notizen', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
    children.add(pw.SizedBox(height: 6));

    if (fotos > 0 || videos > 0) {
      final parts = <String>[];
      if (fotos > 0) parts.add('Fotos: $fotos');
      if (videos > 0) parts.add('Videos: $videos');
      children.add(pw.Text(parts.join(' | '), style: const pw.TextStyle(fontSize: 10)));
      if (other.isNotEmpty) children.add(pw.SizedBox(height: 6));
    }

    for (final o in other) {
      children.add(pw.Bullet(text: o));
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children);
  }
}

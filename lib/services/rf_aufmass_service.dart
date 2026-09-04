import 'dart:ui' show Rect;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service zum Erstellen des ausgefüllten Aufmaßblatts für Einstiegsschächte.
///
/// Wichtig:
/// - Nutzt das Original-Template 1:1 als Basis.
/// - Zeichnet nur die Werte aus der Erfassung an feste Positionen.
class RfAufmassService {
  static final DateFormat _dfDate = DateFormat('dd.MM.yyyy HH:mm');

  /// Hauptmethod: Erstellt das befüllte Aufmaßblatt
  /// 
  /// Parameter:
  /// - [evnr] - Erfassungsversionsnummer
  /// - [posNr] - Positionsnummer
  /// - [strasse] - Straße
  /// - [erfasser] - Name des Erfassers
  /// - [zeit] - Erfassungszeitpunkt
  /// - [meta] - Die Meta-JSON mit allen Erfassungsdaten
  static Future<Uint8List> buildRfAufmaessPdf({
    required String evnr,
    required String posNr,
    required String? strasse,
    required String? erfasser,
    required DateTime? zeit,
    required Map<String, dynamic> meta,
  }) async {
    try {
      final templateData = await rootBundle.load('assets/App/Formulare/Erfassungsblatt_Einstiegsschachte.pdf');
      final document = PdfDocument(inputBytes: templateData.buffer.asUint8List());
      final page = document.pages[0];

      final String idNr = (meta['idNr'] as String?)?.trim() ?? '';
      final String durchmesser = (meta['durchmesser'] as String?)?.trim() ?? '';
      final String kanalprofil = (meta['kanalprofil'] as String?)?.trim() ?? '';
      final String oertlBem = (meta['oertlBem'] as String?)?.trim() ?? '';
      final String obflBem = (meta['obflBem'] as String?)?.trim() ?? '';
      final String st1Hoehe = (meta['st1Hoehe'] as String?)?.trim() ?? '';
      final String st1Rf = (meta['st1Rf'] as String?)?.trim() ?? '';
      final String st2Hoehe = (meta['st2Hoehe'] as String?)?.trim() ?? '';
      final String st2Rf = (meta['st2Rf'] as String?)?.trim() ?? '';
      final String uebergangsBem = (meta['uebergangsBem'] as String?)?.trim() ?? '';
      final String sonstigeTypen = (meta['sonstigeTypen'] as String?)?.trim() ?? '';
      final String mAusgleich = (meta['mAusgleich'] as String?)?.trim() ?? '';
      final String mKonusAnf = (meta['mKonusAnf'] as String?)?.trim() ?? '';
      final String mKonusMid = (meta['mKonusMid'] as String?)?.trim() ?? '';
      final String mKonusEnd = (meta['mKonusEnd'] as String?)?.trim() ?? '';
      final String mBerme = (meta['mBerme'] as String?)?.trim() ?? '';
      final String mSolltiefe = (meta['mSolltiefe'] as String?)?.trim() ?? '';
      final String bemerkung = (meta['bemerkung'] as String?)?.trim() ?? '';
      final String einsteigart = (meta['einsteigart'] as String?)?.trim() ?? '';
      final String steigeisenStand = (meta['steigeisenStand'] as String?)?.trim() ?? '';
      final String deckel = (meta['deckel'] as String?)?.trim() ?? '';
      final String zeitStr = zeit != null ? _dfDate.format(zeit) : '';
      final Set<String> oertlichkeit = _toSet(meta['oertlichkeit']);
      final Set<String> oberflaeche = _toSet(meta['oberflaeche']);
      final Set<String> schachtkopf = _toSet(meta['schachtkopf']);

      // Lokale Helper für platzgenaues Zeichnen.
      final PdfFont font9 = PdfStandardFont(PdfFontFamily.helvetica, 9);
      final PdfFont font8 = PdfStandardFont(PdfFontFamily.helvetica, 8);
      final PdfFont font10 = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
      final double h = page.size.height;

      void drawAt({
        required double x,
        required double yFromBottom,
        required String value,
        double width = 180,
        PdfFont? font,
      }) {
        final v = value.trim();
        if (v.isEmpty) return;
        final yTop = h - yFromBottom - 10;
        page.graphics.drawString(
          v,
          font ?? font9,
          bounds: Rect.fromLTWH(x, yTop, width, 12),
          brush: PdfBrushes.black,
          format: PdfStringFormat(
            alignment: PdfTextAlignment.left,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
      }

      void checkAt({required double x, required double yFromBottom}) {
        drawAt(x: x, yFromBottom: yFromBottom, value: 'X', width: 12, font: font10);
      }

      bool has(Set<String> values, String token) {
        final needle = _norm(token);
        for (final item in values) {
          if (_norm(item).contains(needle)) return true;
        }
        return false;
      }

      String stripBemerkungPrefix(String value) {
        const p = 'Bemerkung:';
        if (value.startsWith(p)) return value.substring(p.length).trim();
        return value;
      }

      // Kopfbereich
      drawAt(x: 205, yFromBottom: 739.66, value: '$evnr/$posNr', width: 220);
      drawAt(x: 160, yFromBottom: 698.98, value: strasse ?? '', width: 230);
      drawAt(x: 160, yFromBottom: 685.42, value: idNr, width: 160);
      drawAt(x: 205, yFromBottom: 658.30, value: durchmesser, width: 160);
      drawAt(x: 205, yFromBottom: 644.40, value: kanalprofil, width: 160);
      drawAt(x: 395, yFromBottom: 73.22, value: zeitStr.split(' ').first, width: 120, font: font8);

      // Notizfeld (links)
      drawAt(x: 95, yFromBottom: 631.18, value: bemerkung, width: 230, font: font8);

      // Örtlichkeit (ankreuzen wie in der App)
      if (has(oertlichkeit, 'Hauptstraße')) checkAt(x: 418, yFromBottom: 699.0);
      if (has(oertlichkeit, 'Nebenstraße')) checkAt(x: 418, yFromBottom: 685.4);
      if (has(oertlichkeit, 'Kreuzung')) checkAt(x: 418, yFromBottom: 671.8);
      if (has(oertlichkeit, 'Einbahnstraße')) checkAt(x: 552, yFromBottom: 685.4);
      if (has(oertlichkeit, 'Geh-/Radweg') || has(oertlichkeit, 'Geh/Radweg')) checkAt(x: 552, yFromBottom: 671.8);
      drawAt(x: 555, yFromBottom: 699.0, value: oertlBem, width: 110, font: font8);

      // Oberfläche (ankreuzen wie in der App)
      if (has(oberflaeche, 'Asphalt')) checkAt(x: 418, yFromBottom: 631.0);
      if (has(oberflaeche, 'teerhaltig') || has(oberflaeche, 'Teerhaltig')) checkAt(x: 552, yFromBottom: 631.0);
      if (has(oberflaeche, 'Kleinstein')) checkAt(x: 418, yFromBottom: 617.4);
      if (has(oberflaeche, 'Großstein') || has(oberflaeche, 'Grossstein')) checkAt(x: 552, yFromBottom: 617.4);
      if (has(oberflaeche, 'Kupla')) checkAt(x: 418, yFromBottom: 603.8);

      final sonstigeOberflaeche = <String>[];
      for (final v in oberflaeche) {
        final n = _norm(v);
        final known = n.contains('asphalt') ||
            n.contains('teerhaltig') ||
            n.contains('kleinstein') ||
            n.contains('grossstein') ||
            n.contains('großstein') ||
            n.contains('kupla');
        if (!known) sonstigeOberflaeche.add(v);
      }
      final surfaceOtherText = [
        if (sonstigeOberflaeche.isNotEmpty) sonstigeOberflaeche.join(', '),
        if (obflBem.isNotEmpty) obflBem,
      ].join(' - ');
      drawAt(x: 510, yFromBottom: 603.8, value: surfaceOtherText, width: 125, font: font8);

      // Schachtkopf: Deckelart auf Mannloch/Begu/Sonstige abbilden
      final normalizedDeckel = _norm(deckel);
      final isMannloch = normalizedDeckel.contains('mannloch');
      final isBegu = normalizedDeckel == 'dn' || normalizedDeckel.contains('dn ') || normalizedDeckel.contains('begu') || normalizedDeckel.contains('625');
      if (isMannloch) {
        checkAt(x: 418, yFromBottom: 563.3);
      } else if (isBegu) {
        checkAt(x: 552, yFromBottom: 563.3);
      } else if (deckel.isNotEmpty) {
        drawAt(x: 475, yFromBottom: 549.8, value: stripBemerkungPrefix(deckel), width: 160, font: font8);
      }

      // Schachtkopfdaten aus App-Chips
      if (has(schachtkopf, 'Ausgleichsringe')) checkAt(x: 418, yFromBottom: 536.2);
      if (has(schachtkopf, 'Übergangsplatte')) {
        checkAt(x: 418, yFromBottom: 522.7);
        drawAt(x: 510, yFromBottom: 522.7, value: uebergangsBem, width: 125, font: font8);
      }
      if (has(schachtkopf, 'Konus DN 625')) checkAt(x: 418, yFromBottom: 509.1);
      if (has(schachtkopf, 'Konus DN 700')) checkAt(x: 418, yFromBottom: 495.6);
      if (has(schachtkopf, 'Sonstige Typen')) {
        drawAt(x: 450, yFromBottom: 482.0, value: sonstigeTypen, width: 185, font: font8);
      }

      // Einsteigart (Steigeisen alt/neu, Leiter, Sonstige)
      if (_norm(einsteigart).contains('leiter')) {
        checkAt(x: 552, yFromBottom: 468.4);
      }
      if (_norm(einsteigart).contains('steigeisen')) {
        if (_norm(steigeisenStand).contains('alt')) {
          checkAt(x: 418, yFromBottom: 468.4);
        } else if (_norm(steigeisenStand).contains('neu')) {
          checkAt(x: 418, yFromBottom: 454.9);
        } else {
          // Fallback: wenn kein Stand gesetzt, beide möglich markieren
          checkAt(x: 418, yFromBottom: 468.4);
        }
      }
      if (!_norm(einsteigart).contains('leiter') && !_norm(einsteigart).contains('steigeisen') && einsteigart.isNotEmpty) {
        drawAt(x: 450, yFromBottom: 441.3, value: einsteigart, width: 185, font: font8);
      }

      // Maße/Skizze-Bereich
      drawAt(x: 206, yFromBottom: 400.0, value: durchmesser, width: 100); // DN Ø Einstieg Maß
      drawAt(x: 550, yFromBottom: 386.0, value: mKonusAnf, width: 70); // Konusanfang
      drawAt(x: 368, yFromBottom: 336.0, value: mKonusMid, width: 70); // Konus-Mitte
      drawAt(x: 186, yFromBottom: 286.0, value: mKonusEnd, width: 90); // Konusende
      drawAt(x: 220, yFromBottom: 191.0, value: durchmesser, width: 120); // Schachtdurchmesser in Skizze
      drawAt(x: 418, yFromBottom: 118.0, value: mBerme, width: 65); // Berme
      drawAt(x: 330, yFromBottom: 94.0, value: mSolltiefe, width: 75); // Solltiefe

      // Schachtkopf-Aufmaß (rechte Liste)
      drawAt(x: 510, yFromBottom: 536.23, value: mAusgleich, width: 90);

      // Steigeisen-Aufmaß
      drawAt(
        x: 550,
        yFromBottom: 341.0,
        value: 'H: ${st1Hoehe.isEmpty ? '-' : st1Hoehe}  RF: ${st1Rf.isEmpty ? '-' : st1Rf}',
        width: 95,
      );
      drawAt(
        x: 504,
        yFromBottom: 286.0,
        value: 'H: ${st2Hoehe.isEmpty ? '-' : st2Hoehe}  RF: ${st2Rf.isEmpty ? '-' : st2Rf}',
        width: 140,
      );

      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();
      return bytes;
    } catch (e) {
      debugPrint('❌ Fehler beim Erstellen des RF-Aufmaßblatts: $e');
      rethrow;
    }
  }

  static Set<String> _toSet(dynamic v) {
    if (v == null) return <String>{};
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    }
    if (v is String && v.trim().isNotEmpty) {
      return v
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }

  static String _norm(String value) {
    return value
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .trim();
  }
}

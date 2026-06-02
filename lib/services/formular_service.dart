// ======================= lib/services/formular_service.dart =======================
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show FlutterError, debugPrint, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'web_download.dart';

/// Lädt ein Formular aus den Assets und öffnet es mit der Standard-App des Geräts.
/// Gibt den Pfad zurück, unter dem die Datei gespeichert wurde, oder null bei Fehler.
class FormularService {
  static const String _assetBase = 'assets/App/Formulare';
  static const String _esTemplateFileName = 'Erfassungsblatt für Einsteigschächte.docx';
  static const String _esTemplateLegacyFileName = 'Erfassungsblatt für Einsteigschächte Vorgefertigt.docx';
  static const String _vsTemplateFileName = 'Erfassung_Sickergruben.docx';

  /// Öffnet das Erfassungsblatt für Einstiegsschächte.
  /// [replacements] ist eine geordnete Liste von (Schluessel, Wert)-Paaren.
  /// Bevorzugt werden Platzhalter wie {{auftragsnummer}} ersetzt.
  /// Legacy-Fallback: Labels wie "Auftragsnummer:" werden weiterhin unterstützt.
  static Future<String?> openEinsteigschaechte({
    List<(String, String)> replacements = const <(String, String)>[],
  }) => _openFormular(
      fileName: _esTemplateFileName,
      replacements: replacements,
    );

  /// Öffnet das Erfassungsblatt für Sickergruben.
  static Future<String?> openSickergruben({
    List<(String, String)> replacements = const <(String, String)>[],
  }) => _openFormular(
      fileName: _vsTemplateFileName,
      replacements: replacements,
    );

  /// Öffnet ES-Formular direkt aus einem gespeicherten ES-Metaobjekt
  /// und verwendet ausschließlich Platzhalter-Schlüssel.
  static Future<String?> openEinsteigschaechteFromMeta(Map<String, dynamic> meta) {
    return openEinsteigschaechte(
      replacements: _buildEsPlaceholderReplacements(meta),
    );
  }

  /// Öffnet VS/Sickergruben-Formular direkt aus einem gespeicherten VS-Metaobjekt
  /// und verwendet ausschließlich Platzhalter-Schlüssel.
  static Future<String?> openSickergrubenFromMeta(Map<String, dynamic> meta) {
    return openSickergruben(
      replacements: _buildVsPlaceholderReplacements(meta),
    );
  }

  static Future<String?> _openFormular({
    required String fileName,
    List<(String, String)> replacements = const <(String, String)>[],
  }) async {
    try {
      final bytes = await _buildFormularBytes(
        fileName: fileName,
        replacements: replacements,
      );

      final valid = _validateDocxBytes(bytes, context: fileName);
      if (!valid) {
        debugPrint('[FormularService] DOCX-Validierung fehlgeschlagen: $fileName');
        return null;
      }

      // Auf Web sind Datei-IO und file://-Launch nicht verlässlich nutzbar.
      if (kIsWeb) {
        final outName = _buildOutputFileName(
          templateFileName: fileName,
          replacements: replacements,
        );
        try {
          downloadBytesWeb(Uint8List.fromList(bytes), outName);
          debugPrint('[FormularService] Web: DOCX Download gestartet: $outName');
          return outName;
        } catch (e) {
          debugPrint('[FormularService] Web: DOCX Download fehlgeschlagen: $e');
        }

        // Rückfall: bisheriges Verhalten (PDF öffnen), falls Download nicht klappt.
        final pdfName = _webPdfForDocx(fileName);
        if (pdfName != null) {
          final webUri = Uri.parse('/$_assetBase/$pdfName');
          final opened = await launchUrl(
            webUri,
            webOnlyWindowName: '_blank',
          );
          if (opened) {
            debugPrint('[FormularService] Web-Fallback: PDF geoeffnet: $webUri');
            return webUri.toString();
          }
        }
        debugPrint('[FormularService] Web erkannt: Formular konnte nicht geoeffnet werden.');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final outName = _buildOutputFileName(
        templateFileName: fileName,
        replacements: replacements,
      );
      final file = File('${tempDir.path}/$outName');
      await file.writeAsBytes(bytes, flush: true);

      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }

      debugPrint('[FormularService] Formular bereit: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('[FormularService] Fehler beim Öffnen von $fileName: $e');
      return null;
    }
  }

  static Future<Uint8List?> buildEinsteigschaechteDocxBytesFromMeta(Map<String, dynamic> meta) async {
    try {
      final reps = _buildEsPlaceholderReplacements(meta);
      return await _buildFormularBytes(
        fileName: _esTemplateFileName,
        replacements: reps,
      );
    } catch (e) {
      debugPrint('[FormularService] Fehler beim Erstellen ES-DOCX aus Meta: $e');
      return null;
    }
  }

  static Future<Uint8List?> buildSickergrubenDocxBytesFromMeta(Map<String, dynamic> meta) async {
    try {
      final reps = _buildVsPlaceholderReplacements(meta);
      return await _buildFormularBytes(
        fileName: _vsTemplateFileName,
        replacements: reps,
      );
    } catch (e) {
      debugPrint('[FormularService] Fehler beim Erstellen VS-DOCX aus Meta: $e');
      return null;
    }
  }

  static Future<Uint8List> _buildFormularBytes({
    required String fileName,
    required List<(String, String)> replacements,
  }) async {
    final byteData = await _loadTemplateBytes(fileName);
    var bytes = byteData.buffer.asUint8List();

    if (replacements.isNotEmpty) {
      bytes = Uint8List.fromList(
        _applyReplacementsInDocx(
          bytes,
          replacements,
          templateFileName: fileName,
        ),
      );
    }
    return bytes;
  }

  static String? _webPdfForDocx(String fileName) {
    switch (fileName) {
      case _esTemplateFileName:
      case _esTemplateLegacyFileName:
        return 'Erfassungsblatt für Einsteigschächte vorgefertig.pdf';
      case _vsTemplateFileName:
        return 'Erfassung_Sickergruben.pdf';
      default:
        return null;
    }
  }

  static Future<ByteData> _loadTemplateBytes(String fileName) async {
    for (final assetPath in _templateAssetPaths(fileName)) {
      try {
        return await rootBundle.load(assetPath);
      } catch (_) {
        continue;
      }
    }
    throw FlutterError('Template nicht gefunden: $fileName');
  }

  static List<String> _templateAssetPaths(String fileName) {
    switch (fileName) {
      case _esTemplateFileName:
        return const [
          'assets/App/ES/Erfassungsblatt für Einsteigschächte.docx',
          'assets/App/Formulare/Erfassungsblatt für Einsteigschächte Vorgefertigt.docx',
          'assets/App/Formulare/Erfassungsblatt_Einsteigschaechte.docx',
        ];
      case _esTemplateLegacyFileName:
        return const [
          'assets/App/ES/Erfassungsblatt für Einsteigschächte.docx',
          'assets/App/Formulare/Erfassungsblatt für Einsteigschächte Vorgefertigt.docx',
          'assets/App/Formulare/Erfassungsblatt_Einsteigschaechte.docx',
        ];
      case _vsTemplateFileName:
        return const [
          'assets/App/ES/Erfassung_Sickergruben.docx',
          'assets/App/Formulare/Erfassung_Sickergruben.docx',
          'assets/App/Grube/Erfassung_Sickergruben_Valdiert(1).docx',
        ];
      default:
        return ['$_assetBase/$fileName'];
    }
  }

  static List<int> _applyReplacementsInDocx(
    List<int> bytes,
    List<(String, String)> replacements,
    {String? templateFileName}
  ) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    var documentXmlIndex = -1;

    for (var i = 0; i < archive.files.length; i++) {
      final file = archive.files[i];
      if (!file.isFile) continue;
      if (file.name == 'word/document.xml') {
        documentXmlIndex = i;
        break;
      }
    }

    if (documentXmlIndex < 0) {
      return bytes;
    }

    final documentXmlFile = archive.files[documentXmlIndex];

    final original = utf8.decode(documentXmlFile.content as List<int>, allowMalformed: true);
    // Bekannte aufgeteilte Textruns zusammenführen, damit Labels gefunden werden.
    var updated = _fixKnownSplitRuns(original);

    debugPrint('[FormularService][DOCX] replacements=${replacements.length}');

    final occurrenceByLabel = <String, int>{};
    for (final (label, value) in replacements) {
      final l = label.trim();
      if (l.isEmpty) continue;

      // Doppelte Labels werden über ihre Dokument-Reihenfolge adressiert.
      final occurrence = (occurrenceByLabel[l] ?? 0) + 1;
      occurrenceByLabel[l] = occurrence;
        final validationNumber = _isEsTemplate(templateFileName)
            ? _esValidationNumberFor(l, occurrence)
            : null;

      final normalizedValue = _normalizeDocxValue(value);

      // 1) Primär: Platzhalter-Ersetzung (auch bei leerem Wert, damit Tokens verschwinden)
      final placeholderBefore = updated;
      updated = _replacePlaceholderValue(
        updated,
        l,
        normalizedValue,
        occurrence: occurrence,
        templateFileName: templateFileName,
      );
      final placeholderApplied = updated != placeholderBefore;

      // 2) Legacy-Fallback: Label-basierte Einfügung nur für nicht-leere Werte
      if (placeholderApplied) {
        debugPrint(
          '[FormularService][DOCX][PH]${validationNumber == null ? '' : ' num=$validationNumber'} key="$l" occurrence=$occurrence applied=true value="${_shortForLog(normalizedValue)}"',
        );
        continue;
      }

      if (normalizedValue.isEmpty) {
        debugPrint(
          '[FormularService][DOCX] skip${validationNumber == null ? '' : ' num=$validationNumber'} key="$l" occurrence=$occurrence (leer)',
        );
        continue;
      }

      final before = updated;

      updated = _replaceAfterLabel(
        updated,
        l,
        normalizedValue,
        occurrence: occurrence,
      );

      // 3) Legacy-Template-Fallback: Placeholder-Key -> altes Label mappen
      //    (falls die Vorlage noch keine {{...}}-Tokens enthält).
      if (updated == before && templateFileName != null) {
        final legacyCandidates = _legacyLabelCandidatesForKey(
          l,
          templateFileName,
        );
        for (final (legacyLabel, legacyOccurrence) in legacyCandidates) {
          final legacyBefore = updated;
          updated = _replaceAfterLabel(
            updated,
            legacyLabel,
            normalizedValue,
            occurrence: legacyOccurrence,
          );
          if (updated != legacyBefore) {
            break;
          }
        }
      }

      final applied = updated != before;
      debugPrint(
        '[FormularService][DOCX]${validationNumber == null ? '' : ' num=$validationNumber'} label="$l" occurrence=$occurrence applied=$applied value="${_shortForLog(normalizedValue)}"',
      );
      if (!applied) {
        debugPrint(
          '[FormularService][DOCX][WARN]${validationNumber == null ? '' : ' num=$validationNumber'} key/label nicht gefunden: "$l" (occurrence=$occurrence)',
        );
      }
    }

    // Sicherstellen, dass nach dem Export keine Platzhalter sichtbar bleiben.
    updated = updated.replaceAll(RegExp(r'\{\{[^{}]+\}\}'), '');

    if (_isEsTemplate(templateFileName)) {
      updated = _applyEinsteigMeasureTextboxFallback(updated, replacements);
    }

    final patchedArchive = Archive();
    for (var i = 0; i < archive.files.length; i++) {
      final file = archive.files[i];
      if (i == documentXmlIndex) {
        final updatedXmlBytes = utf8.encode(updated);
        patchedArchive.addFile(
          ArchiveFile(
            documentXmlFile.name,
            updatedXmlBytes.length,
            updatedXmlBytes,
          ),
        );
      } else {
        patchedArchive.addFile(file);
      }
    }

    final encoded = ZipEncoder().encode(patchedArchive);
    if (!_validateDocxBytes(Uint8List.fromList(encoded), context: 'patched-docx')) {
      debugPrint('[FormularService][DOCX][ERROR] Gepatchte DOCX ist ungueltig, verwende Originalbytes');
      return bytes;
    }
    return encoded;
  }

  /// Führt bekannte aufgeteilte Textruns in diesem DOCX zusammen,
  /// damit Labels per Stringsuche gefunden werden können.
  /// Manche Labels werden von Word über mehrere w:t-Runs verteilt
  /// (z. B. durch Rechtschreibprüfungs-Markierungen).
  static String _fixKnownSplitRuns(String xml) {
    // Muster: TEXT1 + run-unterbrechung + TEXT2
    // wird zu TEXT1TEXT2 zusammengefasst (inkl. Schließen/Öffnen der Runs).
    const inter =
        r'</w:t>(?:(?!</w:p>|</w:tc>|<w:t).)*<w:t[^>]*>';

    String merge(String src, String a, String b) {
      return src.replaceAll(
        RegExp('${RegExp.escape(a)}$inter${RegExp.escape(b)}', dotAll: true),
        '$a$b',
      );
    }

    xml = merge(xml, 'G', 'rünfläche:'); // „Grünfläche:" split
    xml = merge(xml, 'Kupla', ':');       // „Kupla:" split
    xml = merge(xml, 'Sonstige', ':');    // „Sonstige:" split (mehrfach)
    xml = merge(xml, '1.', 'R');          // „1.RF" Schritt 1: 1. + R
    xml = merge(xml, '1.R', 'F');         // „1.RF" Schritt 2: 1.R + F
    xml = merge(xml, '1.', 'SH');         // „1.SH" split
    xml = merge(xml, '2.', 'SH');         // „2.SH" split
    xml = merge(xml, '2.', 'RF');         // „2.RF" split
    return xml;
  }

  static String _replaceAfterLabel(
    String xml,
    String label,
    String value, {
    required int occurrence,
  }) {
    if (label.isEmpty || value.trim().isEmpty) return xml;

    String tryReplace(String source, String token) {
      if (token.isEmpty) return source;
      return _insertFormattedValueAfterToken(
        source,
        token,
        value,
        occurrence: occurrence,
      );
    }

    // 1) Exakter Versuch
    var updated = tryReplace(xml, label);
    if (!identical(updated, xml) && updated != xml) return updated;

    // 2) Normalisierte Varianten (Leerzeichen / Doppelpunkt)
    final normalized = label.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized != label) {
      updated = tryReplace(xml, normalized);
      if (!identical(updated, xml) && updated != xml) return updated;
    }

    final withoutSpaceBeforeColon = normalized.replaceAll(' :', ':');
    if (withoutSpaceBeforeColon != normalized) {
      updated = tryReplace(xml, withoutSpaceBeforeColon);
      if (!identical(updated, xml) && updated != xml) return updated;
    }

    // 3) Fallback: Präfix bis Doppelpunkt (oder kompletter Text),
    //    damit auch Labels funktionieren, die im DOCX intern aufgeteilt sind.
    final colonIndex = normalized.indexOf(':');
    final prefix = colonIndex >= 0 ? normalized.substring(0, colonIndex).trim() : normalized;
    if (prefix.isNotEmpty) {
      updated = tryReplace(xml, '$prefix:');
      if (!identical(updated, xml) && updated != xml) return updated;
      updated = tryReplace(xml, prefix);
      if (!identical(updated, xml) && updated != xml) return updated;
    }

    return xml;
  }

  static String _replacePlaceholderValue(
    String xml,
    String keyOrLabel,
    String value, {
    required int occurrence,
    String? templateFileName,
  }) {
    final candidates = _placeholderCandidatesFor(
      keyOrLabel,
      occurrence,
      templateFileName: templateFileName,
    );
    if (candidates.isEmpty) return xml;

    var updated = xml;
    for (final candidate in candidates) {
      final token = '{{${candidate.trim()}}}';
      final before = updated;
      updated = _replacePlaceholderTokenInRuns(updated, token, value);
      if (updated != before) return updated;
    }
    return xml;
  }

  static String _replacePlaceholderTokenInRuns(String xml, String token, String value) {
    final escapedToken = RegExp.escape(token);
    final runPattern = RegExp(
      '<w:r[^>]*>.*?<w:t[^>]*>\\s*$escapedToken\\s*</w:t>.*?</w:r>',
      dotAll: true,
    );

    final match = runPattern.firstMatch(xml);
    if (match != null) {
      final replacement = value.isEmpty
          ? '<w:r><w:t></w:t></w:r>'
          : _styledRun(value);
      return xml.replaceRange(match.start, match.end, replacement);
    }

    // Fallback für nicht-standardisierte Runs.
    if (xml.contains(token)) {
      return xml.replaceAll(token, _escapeXml(value));
    }
    return xml;
  }

  static String _styledRun(String value) {
    final escaped = _escapeXml(value);
    return '<w:r><w:rPr>'
        '<w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>'
        '<w:b/><w:bCs/><w:color w:val="FF0000"/>'
        '<w:sz w:val="22"/><w:szCs w:val="22"/>'
        '</w:rPr><w:t xml:space="preserve">$escaped</w:t></w:r>';
  }

  static List<String> _placeholderCandidatesFor(
    String keyOrLabel,
    int occurrence, {
    String? templateFileName,
  }) {
    final raw = keyOrLabel.trim();
    if (raw.isEmpty) return const [];

    final out = <String>[];

    // Bereits als {{token}} übergeben.
    final direct = RegExp(r'^\{\{\s*([^{}]+?)\s*\}\}$').firstMatch(raw);
    if (direct != null) {
      out.add(direct.group(1)!.trim());
    }

    // Template-spezifische Legacy-Label-Mappings.
    final mapKey = '$raw#$occurrence';
    if (_isEsTemplate(templateFileName)) {
      final mapped = _esPlaceholderMap[mapKey];
      if (mapped != null) out.add(mapped);
    }
    if (_isVsTemplate(templateFileName)) {
      final mapped = _sickergrubenPlaceholderMap[mapKey];
      if (mapped != null) out.add(mapped);
    }

    // Generischer Fallback: Label -> snake_case.
    final generic = _toPlaceholderKey(raw);
    if (generic.isNotEmpty) out.add(generic);

    // Reihenfolge beibehalten, Duplikate entfernen.
    final unique = <String>[];
    for (final e in out) {
      if (!unique.contains(e)) unique.add(e);
    }
    return unique;
  }

  static String _toPlaceholderKey(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(':', '');
    s = s
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    return s;
  }

  static List<(String, int)> _legacyLabelCandidatesForKey(
    String key,
    String templateFileName,
  ) {
    if (_isEsTemplate(templateFileName)) {
      return _esLegacyByPlaceholder[key] ?? const <(String, int)>[];
    }
    if (_isVsTemplate(templateFileName)) {
      return _vsLegacyByPlaceholder[key] ?? const <(String, int)>[];
    }
    return const <(String, int)>[];
  }

  static bool _isEsTemplate(String? fileName) {
    return fileName == _esTemplateFileName || fileName == _esTemplateLegacyFileName;
  }

  static bool _isVsTemplate(String? fileName) {
    return fileName == _vsTemplateFileName;
  }

  static const Map<String, List<(String, int)>> _esLegacyByPlaceholder = {
    'auftragsnummer': [('Auftragsnummer:', 1)],
    'datum': [('Datum:', 1)],
    'name': [('Name:', 1)],
    'strasse': [('Straße:', 1)],
    'schachtnummer': [('Schachtnummer:', 1)],
    'schachtdurchmesser': [('Schachtdurchmesser:', 1)],
    'kanalprofil': [('Kanalprofil:', 1)],
    'hauptstrasse': [('Hauptstraße:', 1)],
    'nebenstrasse': [('Nebenstraße:', 1)],
    'spuren': [('Spuren:', 1)],
    'kreuzung': [('Kreuzung:', 1)],
    'baustellensicherung': [('Baustellensicherung:', 1)],
    'einbahnstrasse': [('Einbahnstraße:', 1)],
    'geh_radweg': [('Geh / Radweg:', 1)],
    'asphalt': [('Asphalt:', 1)],
    'teerhaltig': [('Teerhaltig:', 1)],
    'grossstein': [('Großstein:', 1)],
    'kleinstein': [('Kleinstein:', 1)],
    'kupla': [('Kupla:', 1)],
    'oberflaeche_sonstige': [('Sonstige:', 2)],
    'gruenflaeche': [('Grünfläche:', 1)],
    'baum_in_der_naehe': [('Baum in der Nähe:', 1)],
    'baum_zusatz': [('Foto!!', 1)],
    'mannloch': [('Mannloch:', 1)],
    'begu_dn_625': [('Begu DN 625:', 1)],
    'schachtkopf_sonstige': [('Sonstige:', 1)],
    'ausgleichsringe': [('Ausgleichsringe:', 1)],
    'uebergangsplatte': [('Übergangsplatte:', 1)],
    'konus_dn_625_ohne_versatz': [('Konus DN  625 o. Versatz', 1)],
    'konus_dn_700_mit_versatz': [('Konus DN 700 m. Versatz', 1)],
    'steigeisen_alt': [('Steigeisen alt:', 1)],
    'steigeisen_neu': [('Steigeisen neu:', 1)],
    'leiter': [('Leiter, nur ankreuzen, wenn da', 1)],
    'sonstige': [('Sonstige:', 3)],
    'konusanfang': [('KE', 1)],
    'steighoehe_1_steigeisen': [('1.SH', 1)],
    'steighoehe_2_steigeisen': [('2.SH', 1)],
    'mass_815': [('815', 1)],
    'rueckenfreiheit_1_steigeisen': [('1.RF', 1)],
    'konusende': [('Konusende', 1)],
    'rueckenfreiheit_2_steigeisen': [('2.RF', 1)],
    'schachtdurchmesser_skizze': [('Schachtdurchmesser:', 2)],
    'berme': [('Berme', 1)],
    'solltiefe': [('Solltiefe', 1)],
  };

  static const Map<String, List<(String, int)>> _vsLegacyByPlaceholder = {
    'auftragsnummer': [('Auftragsnummer:', 1)],
    'datum': [('Datum:', 1)],
    'name': [('Name:', 1)],
    'strasse': [('Straße:', 1)],
    'witterung_sonne': [('Sonne', 1)],
    'witterung_regen': [('Regen', 1)],
    'witterung_letzter_niederschlag': [('letzter Niederschlag', 1)],
    'grubenart_kb_schacht': [('KB-Schacht', 1)],
    'grubenart_din': [('DIN', 1)],
    'grubenart_gemauert': [('Gemauert', 1)],
    'grubentiefe_cm': [('Grubentiefe in cm', 1)],
    'wasserstand_ja': [('Wasserstand JA', 1)],
    'wasserstand_nein': [('Wasserstand NEIN', 1)],
    'wasserstand_cm': [('Wasserstand in cm', 1)],
    'baujahr': [('Baujahr wenn bekannt', 1)],
    'anschluss_vorhanden_ja': [('Vorhanden JA', 1)],
    'anschluss_vorhanden_nein': [('Vorhanden NEIN', 1)],
    'anschluss_offen_ja': [('Offen JA', 1)],
    'anschluss_offen_nein': [('Offen NEIN', 1)],
    'filtersand_ja': [('Filtersand JA', 1)],
    'filtersand_nein': [('Filtersand NEIN', 1)],
    'filtersand_locker': [('locker', 1)],
    'filtersand_sickerfaehig': [('sickerfähig', 1)],
    'filtersand_fest': [('fest', 1)],
    'filtersand_lehmig': [('lehmig', 1)],
  };

  static const Map<String, String> _esPlaceholderMap = {
    'Auftragsnummer:#1': 'auftragsnummer',
    'Datum:#1': 'datum',
    'Name:#1': 'name',
    'Straße:#1': 'strasse',
    'Schachtnummer:#1': 'schachtnummer',
    'Schachtdurchmesser:#1': 'schachtdurchmesser',
    'Kanalprofil:#1': 'kanalprofil',
    'Hauptstraße:#1': 'hauptstrasse',
    'Nebenstraße:#1': 'nebenstrasse',
    'Spuren:#1': 'spuren',
    'Kreuzung:#1': 'kreuzung',
    'Baustellensicherung:#1': 'baustellensicherung',
    'Einbahnstraße:#1': 'einbahnstrasse',
    'Geh / Radweg:#1': 'geh_radweg',
    'Asphalt:#1': 'asphalt',
    'Teerhaltig:#1': 'teerhaltig',
    'Großstein:#1': 'grossstein',
    'Kleinstein:#1': 'kleinstein',
    'Kupla:#1': 'kupla',
    'Sonstige:#2': 'oberflaeche_sonstige',
    'Grünfläche:#1': 'gruenflaeche',
    'Baum in der Nähe:#1': 'baum_in_der_naehe',
    'Foto!!#1': 'baum_zusatz',
    'Mannloch:#1': 'mannloch',
    'Begu DN 625:#1': 'begu_dn_625',
    'Sonstige:#1': 'schachtkopf_sonstige',
    'Ausgleichsringe:#1': 'ausgleichsringe',
    'Übergangsplatte:#1': 'uebergangsplatte',
    'Konus DN  625 o. Versatz#1': 'konus_dn_625_ohne_versatz',
    'Konus DN 700 m. Versatz#1': 'konus_dn_700_mit_versatz',
    'Steigeisen alt:#1': 'steigeisen_alt',
    'Steigeisen neu:#1': 'steigeisen_neu',
    'Leiter, nur ankreuzen, wenn da#1': 'leiter',
    'Sonstige:#3': 'sonstige',
    'Schachtdurchmesser:#2': 'schachtdurchmesser_skizze',
    'KE#1': 'konusanfang',
    '1.SH#1': 'steighoehe_1_steigeisen',
    '2.SH#1': 'steighoehe_2_steigeisen',
    '815#1': 'mass_815',
    '1.RF#1': 'rueckenfreiheit_1_steigeisen',
    'Konusende#1': 'konusende',
    '2.RF#1': 'rueckenfreiheit_2_steigeisen',
    'Berme#1': 'berme',
    'Solltiefe#1': 'solltiefe',
  };

  static const Map<String, String> _sickergrubenPlaceholderMap = {
    'Auftragsnummer:#1': 'auftragsnummer',
    'Datum:#1': 'datum',
    'Name:#1': 'name',
    'Straße:#1': 'strasse',
    'Grubentiefe in cm:#1': 'grubentiefe_cm',
    'Wasserstand JA:#1': 'wasserstand_ja',
    'Wasserstand NEIN:#1': 'wasserstand_nein',
    'Wasserstand in cm:#1': 'wasserstand_cm',
    'Baujahr wenn bekannt:#1': 'baujahr',
  };

  static String _insertFormattedValueAfterToken(
    String source,
    String token,
    String value, {
    required int occurrence,
  }) {
    final tokenIndex = _indexOfOccurrence(source, token, occurrence);
    if (tokenIndex < 0) return source;

    final closeTagIndex = source.indexOf('</w:t>', tokenIndex);
    if (closeTagIndex < 0) return source;

    final escapedValue = _escapeXml(value);
    final valueTextNode = '<w:t xml:space="preserve"> $escapedValue</w:t>';

    // Bereits eingefuegt? Dann idempotent bleiben.
    final lookaheadStart = closeTagIndex + '</w:t>'.length;
    final lookaheadEnd = (lookaheadStart + 500).clamp(0, source.length);
    final lookahead = source.substring(lookaheadStart, lookaheadEnd);
    if (lookahead.contains(valueTextNode)) {
      return source;
    }

    const styledRunPrefix =
        '</w:r><w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>'
        '<w:b/><w:bCs/><w:color w:val="FF0000"/><w:sz w:val="22"/><w:szCs w:val="22"/>'
        '</w:rPr>';
    const styledRunSuffix = '</w:r><w:r>';

    final insertion = '$styledRunPrefix$valueTextNode$styledRunSuffix';
    final insertAt = closeTagIndex + '</w:t>'.length;
    return source.replaceRange(insertAt, insertAt, insertion);
  }

  static int _indexOfOccurrence(String source, String token, int occurrence) {
    if (occurrence <= 0 || token.isEmpty) return -1;

    var fromIndex = 0;
    var currentOccurrence = 0;
    while (true) {
      final index = source.indexOf(token, fromIndex);
      if (index < 0) return -1;

      currentOccurrence++;
      if (currentOccurrence == occurrence) return index;
      fromIndex = index + token.length;
    }
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _normalizeDocxValue(String value) {
    return value
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
  }

  static String _shortForLog(String value) {
    if (value.length <= 80) return value;
    return '${value.substring(0, 80)}...';
  }

  static List<(String, String)> _buildEsPlaceholderReplacements(Map<String, dynamic> meta) {
    final evnr = _metaString(meta, 'evnr');
    final pos = _metaString(meta, 'posNr');
    final zeitIso = _metaString(meta, 'zeitIso');
    final oertlichkeit = _toStringSet(meta['oertlichkeit'])
      .map((e) => _normalizeUmlauts(e).toLowerCase())
      .toSet();
    final oberflaeche = _toStringSet(meta['oberflaeche'])
      .map((e) => _normalizeUmlauts(e).toLowerCase())
      .toSet();
    final schachtkopf = _toStringSet(meta['schachtkopf'])
      .map((e) => _normalizeUmlauts(e).toLowerCase())
      .toSet();

    final deckel = _normalizeUmlauts(_metaString(meta, 'deckel')).toLowerCase();
    final einsteigart = _normalizeUmlauts(_metaString(meta, 'einsteigart')).toLowerCase();
    final steigeisenStand = _normalizeUmlauts(_metaString(meta, 'steigeisenStand')).toLowerCase();

    String x(bool selected) => selected ? 'X' : '';

    return <(String, String)>[
      ('auftragsnummer', [evnr, pos].where((e) => e.isNotEmpty).join('/')),
      ('datum', _formatDateForDocx(zeitIso)),
      ('name', _metaString(meta, 'erfasser')),
      ('strasse', _metaString(meta, 'strasse')),
      ('schachtnummer', pos),
      ('schachtdurchmesser', _metaString(meta, 'durchmesser')),
      ('kanalprofil', _metaString(meta, 'kanalprofil')),

      ('hauptstrasse', x(oertlichkeit.contains('hauptstrasse'))),
      ('nebenstrasse', x(oertlichkeit.contains('nebenstrasse'))),
      ('spuren', x(oertlichkeit.contains('spuren'))),
      ('kreuzung', x(oertlichkeit.contains('kreuzung'))),
      ('baustellensicherung', x(oertlichkeit.contains('baustellensicherung'))),
      ('einbahnstrasse', x(oertlichkeit.contains('einbahnstrasse'))),
      ('geh_radweg', x(oertlichkeit.contains('geh-/radweg'))),

      ('asphalt', x(oberflaeche.contains('asphalt'))),
      ('teerhaltig', x(oberflaeche.contains('teerhaltig'))),
      ('grossstein', x(oberflaeche.contains('grossstein'))),
      ('kleinstein', x(oberflaeche.contains('kleinstein'))),
      ('kupla', x(oberflaeche.contains('kupla'))),
      ('oberflaeche_sonstige', x(oberflaeche.contains('sonstige'))),
      ('gruenflaeche', x(oberflaeche.contains('gruenflaeche'))),
      ('baum_in_der_naehe', x(oberflaeche.contains('baum in der naehe'))),
      ('baum_zusatz', _metaString(meta, 'obflBem')),

      ('mannloch', x(deckel.startsWith('mannloch'))),
      ('begu_dn_625', x(deckel.startsWith('begu dn 625'))),
      ('schachtkopf_sonstige', x(deckel.startsWith('bemerkung:'))),
      ('ausgleichsringe', x(schachtkopf.contains('ausgleichsringe'))),
      ('uebergangsplatte', x(schachtkopf.contains('uebergangsplatte (hoehe)'))),
      ('konus_dn_625_ohne_versatz', x(schachtkopf.contains('konus dn 625 o. versatz'))),
      ('konus_dn_700_mit_versatz', x(schachtkopf.contains('konus dn 700 m. versatz'))),
      ('steigeisen_alt', x(einsteigart == 'steigeisen' && steigeisenStand == 'alt')),
      ('steigeisen_neu', x(einsteigart == 'steigeisen' && steigeisenStand == 'neu')),
      ('leiter', x(einsteigart == 'leiter')),
      ('sonstige', x(einsteigart.isNotEmpty && einsteigart != 'leiter' && einsteigart != 'steigeisen')),

      ('konusanfang', _metaString(meta, 'mKonusAnf')),
      ('steighoehe_1_steigeisen', _metaString(meta, 'st1Hoehe')),
      ('steighoehe_2_steigeisen', _metaString(meta, 'st2Hoehe')),
      ('mass_815', _metaString(meta, 'mAusgleich')),
      ('rueckenfreiheit_1_steigeisen', _metaString(meta, 'st1Rf')),
      ('konusende', _metaString(meta, 'mKonusEnd')),
      ('rueckenfreiheit_2_steigeisen', _metaString(meta, 'st2Rf')),
      ('schachtdurchmesser_skizze', _metaString(meta, 'durchmesser')),
      ('berme', _metaString(meta, 'mBerme')),
      ('solltiefe', _metaString(meta, 'mSolltiefe')),
    ];
  }

  static List<(String, String)> _buildVsPlaceholderReplacements(Map<String, dynamic> meta) {
    final evnr = _metaString(meta, 'evnr');
    final pos = _metaString(meta, 'posNr');
    final zeitIso = _metaString(meta, 'zeitIso');
    final wetter = _normalizeUmlauts(_metaString(meta, 'wetter')).toLowerCase();
    final grubenart = _normalizeUmlauts(_metaString(meta, 'grubentyp')).toLowerCase();
    final wasserText = _metaString(meta, 'wasser_cm');
    final wasser = double.tryParse(wasserText.replaceAll(',', '.')) ?? 0;
    final anschlussJa = meta['anschlussJa'] == true;
    final anschlussNein = meta['anschlussJa'] == false;
    final teller = _normalizeUmlauts(_metaString(meta, 'teller')).toLowerCase();
    final filtersandJa = meta['filtersandJa'] == true;
    final filtersandNein = meta['filtersandJa'] == false;
    final filtersandEig = _toStringSet(meta['filtersandEigensch'])
      .map((e) => _normalizeUmlauts(e).toLowerCase())
      .toSet();

    String x(bool selected) => selected ? 'X' : '';

    return <(String, String)>[
      ('auftragsnummer', [evnr, pos].where((e) => e.isNotEmpty).join('/')),
      ('datum', _formatDateForDocx(zeitIso)),
      ('name', _metaString(meta, 'erfasser')),
      ('strasse', _metaString(meta, 'strasse')),

      ('witterung_sonne', x(wetter == 'klar')),
      ('witterung_regen', x(wetter == 'regen')),
      ('witterung_letzter_niederschlag', ''),

      ('grubenart_kb_schacht', x(grubenart == 'kb-schacht')),
      ('grubenart_din', x(grubenart == 'din')),
      ('grubenart_gemauert', x(grubenart == 'gemauert')),

      ('grubentiefe_cm', _metaString(meta, 'tiefe_cm')),

      ('wasserstand_ja', x(wasser > 0)),
      ('wasserstand_nein', x(wasser <= 0)),
      ('wasserstand_cm', wasserText),
      ('baujahr', _metaString(meta, 'baujahr')),

      ('anschluss_vorhanden_ja', x(anschlussJa)),
      ('anschluss_vorhanden_nein', x(anschlussNein)),
      ('anschluss_offen_ja', x(teller == 'offen')),
      ('anschluss_offen_nein', x(teller == 'nicht offen')),

      ('filtersand_ja', x(filtersandJa)),
      ('filtersand_nein', x(filtersandNein)),
      ('filtersand_locker', x(filtersandEig.contains('locker'))),
      ('filtersand_sickerfaehig', x(filtersandEig.contains('sickerfaehig'))),
      ('filtersand_fest', x(filtersandEig.contains('fest'))),
      ('filtersand_lehmig', x(filtersandEig.contains('lehmig'))),
    ];
  }

  static String _normalizeUmlauts(String input) {
    return input
        .replaceAll('Ä', 'Ae')
        .replaceAll('Ö', 'Oe')
        .replaceAll('Ü', 'Ue')
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
  }

  static String _metaString(Map<String, dynamic> meta, String key) {
    final v = meta[key];
    if (v == null) return '';
    if (v is String) return v.trim();
    return v.toString().trim();
  }

  static Set<String> _toStringSet(dynamic v) {
    if (v == null) return <String>{};
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    }
    if (v is String) {
      return v
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }

  static String _formatDateForDocx(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  static String _applyEinsteigMeasureTextboxFallback(
    String xml,
    List<(String, String)> replacements,
  ) {
    // Referenz aus der validierten Word-Datei.
    // Feld 19 wird aus Schachtdurchmesser (6.1) gespiegelt, Feld 20 aus Berme.
    final fallback = <(String number, String shapeId, String label)>[
      ('11', '_x0000_s1028', 'Schachtdurchmesser:'),
      ('12', '_x0000_s1029', 'KE'),
      ('13', '_x0000_s1032', '1.SH'),
      ('14', '_x0000_s1031', '2.SH'),
      ('15', '_x0000_s1036', '815'),
      ('16', '_x0000_s1034', '1.RF'),
      ('17', '_x0000_s1035', 'Konusende'),
      ('18', '_x0000_s1033', '2.RF'),
      ('19', '_x0000_s1037', 'Schachtdurchmesser:'),
      ('20', '_x0000_s1030', 'Berme'),
      ('21', '_x0000_s1038', 'Solltiefe'),
    ];

    var updated = xml;
    for (final (number, shapeId, label) in fallback) {
      final value = _findReplacementValue(replacements, label);
      if (value.isEmpty) continue;
      final before = updated;
      updated = _setTextboxShapeValue(updated, shapeId, value);
      final applied = updated != before;
      debugPrint(
        '[FormularService][DOCX][TB] num=$number label="$label" shape=$shapeId applied=$applied value="${_shortForLog(value)}"',
      );
    }

    return updated;
  }

  static String _findReplacementValue(
    List<(String, String)> replacements,
    String label,
  ) {
    for (final (l, v) in replacements) {
      if (l.trim() != label) continue;
      final n = _normalizeDocxValue(v);
      if (n.isNotEmpty) return n;
    }
    return '';
  }

  static String _setTextboxShapeValue(String xml, String shapeId, String value) {
    final shapePattern = RegExp(
      '(<v:shape[^>]*id="${RegExp.escape(shapeId)}"[^>]*>.*?<w:txbxContent>)(.*?)(</w:txbxContent>.*?</v:shape>)',
      dotAll: true,
    );
    final shapeMatch = shapePattern.firstMatch(xml);
    if (shapeMatch == null) return xml;

    final prefix = shapeMatch.group(1)!;
    final content = shapeMatch.group(2)!;
    final suffix = shapeMatch.group(3)!;

    final escaped = _escapeXml(value);
    final tPattern = RegExp(r'<w:t([^>]*)>.*?</w:t>', dotAll: true);
    final String replacedContent;
    if (tPattern.hasMatch(content)) {
      replacedContent = content.replaceFirstMapped(
        tPattern,
        (m) => '<w:t${m.group(1) ?? ''}>$escaped</w:t>',
      );
    } else {
      // Leere Textboxen in der Vorlage haben kein w:t; dann neuen formatierten Lauf einsetzen.
      replacedContent =
          '<w:p><w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>'
          '<w:b/><w:bCs/><w:color w:val="FF0000"/><w:sz w:val="22"/><w:szCs w:val="22"/>'
          '</w:rPr><w:t>$escaped</w:t></w:r></w:p>';
    }

    final fullOld = shapeMatch.group(0)!;
    final fullNew = '$prefix$replacedContent$suffix';
    return xml.replaceFirst(fullOld, fullNew);
  }

  static String _buildOutputFileName({
    required String templateFileName,
    required List<(String, String)> replacements,
  }) {
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    if (_isEsTemplate(templateFileName)) {
      String evnr = 'EVNR';
      String pos = 'POSITION';

      for (final (label, value) in replacements) {
        if (label.trim() != 'Auftragsnummer:') continue;
        final parts = value.split('/').map((e) => e.trim()).toList();
        if (parts.isNotEmpty && parts.first.isNotEmpty) {
          evnr = parts.first;
        }
        if (parts.length > 1 && parts[1].isNotEmpty) {
          pos = parts[1];
        }
        break;
      }

      final safeEvnr = _safeFilePart(evnr);
      final safePos = _safeFilePart(pos);
      return 'Erfassungsblatt_Einsteigschacht_${safeEvnr}_${safePos}_$ts.docx';
    }

    final ext = templateFileName.contains('.')
        ? templateFileName.substring(templateFileName.lastIndexOf('.'))
        : '';
    final base = templateFileName.contains('.')
        ? templateFileName.substring(0, templateFileName.lastIndexOf('.'))
        : templateFileName;
    return '${_safeFilePart(base)}_$ts$ext';
  }

  static String _safeFilePart(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'WERT' : cleaned;
  }

  static bool _validateDocxBytes(Uint8List bytes, {String? context}) {
    try {
      final decoded = ZipDecoder().decodeBytes(bytes, verify: true);
      final xmlFile = decoded.files.where((f) => f.isFile && f.name == 'word/document.xml').firstOrNull;
      if (xmlFile == null) {
        debugPrint('[FormularService][DOCX][VALIDATE] word/document.xml fehlt ${context == null ? '' : '(ctx=$context)'}');
        return false;
      }

      final content = xmlFile.content;
      utf8.decode(content, allowMalformed: true);
      return true;
    } catch (e) {
      debugPrint('[FormularService][DOCX][VALIDATE] Fehler ${context == null ? '' : '(ctx=$context)'}: $e');
      return false;
    }
  }

  static String? _esValidationNumberFor(String label, int occurrence) {
    final key = '$label#$occurrence';
    const map = <String, String>{
      'Auftragsnummer:#1': '1/2',
      'Datum:#1': '3',
      'Name:#1': '4',
      'Straße:#1': '5',
      'Schachtnummer:#1': '6',
      'Schachtdurchmesser:#1': '6.1',
      'Kanalprofil:#1': '6.2',
      'Hauptstraße:#1': '7',
      'Nebenstraße:#1': '7.1',
      'Spuren:#1': '7.2',
      'Kreuzung:#1': '7.3',
      'Baustellensicherung:#1': '7.4',
      'Einbahnstraße:#1': '7.5',
      'Geh / Radweg:#1': '7.6',
      'Asphalt:#1': '8',
      'Teerhaltig:#1': '8.1',
      'Großstein:#1': '8.2',
      'Kleinstein:#1': '8.3',
      'Kupla:#1': '8.4',
      'Sonstige:#2': '8.5',
      'Grünfläche:#1': '8.6',
      'Baum in der Nähe:#1': '8.7',
      'Foto!!#1': '8.7.1',
      'Mannloch:#1': '9',
      'Begu DN 625:#1': '9.1',
      'Sonstige:#1': '9.2',
      'Ausgleichsringe:#1': '9.3',
      'Übergangsplatte:#1': '9.4',
      'Konus DN  625 o. Versatz#1': '9.5',
      'Konus DN 700 m. Versatz#1': '9.6',
      'Steigeisen alt:#1': '9.7',
      'Steigeisen neu:#1': '9.8',
      'Leiter, nur ankreuzen, wenn da#1': '9.9',
      'Sonstige:#3': '10',
      'Schachtdurchmesser:#2': '11',
      'KE#1': '12',
      '1.SH#1': '13',
      '2.SH#1': '14',
      '815#1': '15',
      '1.RF#1': '16',
      'Konusende#1': '17',
      '2.RF#1': '18',
      'Berme#1': '20',
      'Solltiefe#1': '21',
    };
    return map[key];
  }
}

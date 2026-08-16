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
  static const String _esTemplateFileName =
      'Erfassungsblatt für Einsteigschächte.docx';
  static const String _esTemplateLegacyFileName =
      'Erfassungsblatt für Einsteigschächte Vorgefertigt.docx';
  static const String _vsTemplateFileName = 'Erfassung_Sickergruben.docx';

  /// Öffnet das Erfassungsblatt für Einstiegsschächte.
  /// [replacements] ist eine geordnete Liste von (Platzhalter-Schluessel, Wert)-Paaren.
  /// Es werden ausschliesslich eindeutige Platzhalter wie {{evnr}} ersetzt.
  static Future<String?> openEinsteigschaechte({
    List<(String, String)> replacements = const <(String, String)>[],
  }) =>
      _openFormular(fileName: _esTemplateFileName, replacements: replacements);

  /// Öffnet das Erfassungsblatt für Sickergruben.
  static Future<String?> openSickergruben({
    List<(String, String)> replacements = const <(String, String)>[],
  }) =>
      _openFormular(fileName: _vsTemplateFileName, replacements: replacements);

  /// Öffnet ES-Formular direkt aus einem gespeicherten ES-Metaobjekt
  /// und verwendet ausschließlich Platzhalter-Schlüssel.
  static Future<String?> openEinsteigschaechteFromMeta(
    Map<String, dynamic> meta,
  ) {
    return openEinsteigschaechte(
      replacements: _buildEsPlaceholderReplacements(meta),
    );
  }

  /// Öffnet VG/Sickergruben-Formular direkt aus einem gespeicherten VG-Metaobjekt
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
        debugPrint(
          '[FormularService] DOCX-Validierung fehlgeschlagen: $fileName',
        );
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
          debugPrint(
            '[FormularService] Web: DOCX Download gestartet: $outName',
          );
          return outName;
        } catch (e) {
          debugPrint('[FormularService] Web: DOCX Download fehlgeschlagen: $e');
        }

        // Rückfall: bisheriges Verhalten (PDF öffnen), falls Download nicht klappt.
        final pdfName = _webPdfForDocx(fileName);
        if (pdfName != null) {
          final webUri = Uri.parse('/$_assetBase/$pdfName');
          final opened = await launchUrl(webUri, webOnlyWindowName: '_blank');
          if (opened) {
            debugPrint(
              '[FormularService] Web-Fallback: PDF geoeffnet: $webUri',
            );
            return webUri.toString();
          }
        }
        debugPrint(
          '[FormularService] Web erkannt: Formular konnte nicht geoeffnet werden.',
        );
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

  static Future<Uint8List?> buildEinsteigschaechteDocxBytesFromMeta(
    Map<String, dynamic> meta,
  ) async {
    try {
      final reps = _buildEsPlaceholderReplacements(meta);
      return await _buildFormularBytes(
        fileName: _esTemplateFileName,
        replacements: reps,
      );
    } catch (e) {
      debugPrint(
        '[FormularService] Fehler beim Erstellen ES-DOCX aus Meta: $e',
      );
      return null;
    }
  }

  static Future<Uint8List?> buildSickergrubenDocxBytesFromMeta(
    Map<String, dynamic> meta,
  ) async {
    try {
      final reps = _buildVsPlaceholderReplacements(meta);
      return await _buildFormularBytes(
        fileName: _vsTemplateFileName,
        replacements: reps,
      );
    } catch (e) {
      debugPrint(
        '[FormularService] Fehler beim Erstellen VG-DOCX aus Meta: $e',
      );
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
    List<(String, String)> replacements, {
    String? templateFileName,
  }) {
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

    final original = utf8.decode(
      documentXmlFile.content as List<int>,
      allowMalformed: true,
    );
    var updated = original;

    debugPrint('[FormularService][DOCX] replacements=${replacements.length}');

    for (final (key, value) in replacements) {
      final placeholderKey = key.trim();
      if (placeholderKey.isEmpty) continue;

      final normalizedValue = _normalizeDocxValue(value);
      final before = updated;
      updated = _replacePlaceholderValue(
        updated,
        placeholderKey,
        normalizedValue,
      );
      if (updated != before) {
        debugPrint(
          '[FormularService][DOCX][PH] key="$placeholderKey" applied=true value="${_shortForLog(normalizedValue)}"',
        );
      }
    }

    // Nicht passende oder leere Objektart-Felder bleiben im Formular leer.
    updated = updated.replaceAll(RegExp(r'\{\{[^{}]+\}\}'), '');

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
    if (!_validateDocxBytes(
      Uint8List.fromList(encoded),
      context: 'patched-docx',
    )) {
      debugPrint(
        '[FormularService][DOCX][ERROR] Gepatchte DOCX ist ungueltig, verwende Originalbytes',
      );
      return bytes;
    }
    return encoded;
  }

  static String _replacePlaceholderValue(
    String xml,
    String keyOrLabel,
    String value,
  ) {
    final candidates = _placeholderCandidatesFor(keyOrLabel);
    if (candidates.isEmpty) return xml;

    var updated = xml;
    for (final candidate in candidates) {
      final token = '{{${candidate.trim()}}}';
      updated = _replacePlaceholderTokenInRuns(updated, token, value);
    }
    return updated;
  }

  static String _replacePlaceholderTokenInRuns(
    String xml,
    String token,
    String value,
  ) {
    final escapedToken = RegExp.escape(token);
    final escapedValue = _escapeXml(value);
    final textNodePattern = RegExp(
      r'(<w:t\b[^>]*>)\s*' + escapedToken + r'\s*(</w:t>)',
      dotAll: true,
    );

    final replacedTextNodes = xml.replaceAllMapped(textNodePattern, (match) {
      return '${match.group(1)}$escapedValue${match.group(2)}';
    });
    if (replacedTextNodes != xml) return replacedTextNodes;

    if (xml.contains(token)) {
      return xml.replaceAll(token, escapedValue);
    }
    return xml;
  }

  static List<String> _placeholderCandidatesFor(String keyOrLabel) {
    final raw = keyOrLabel.trim();
    if (raw.isEmpty) return const [];

    final direct = RegExp(r'^\{\{\s*([^{}]+?)\s*\}\}$').firstMatch(raw);
    final key = direct == null ? raw : direct.group(1)!.trim();
    return key.isEmpty ? const [] : <String>[key];
  }

  static bool _isEsTemplate(String? fileName) {
    return fileName == _esTemplateFileName ||
        fileName == _esTemplateLegacyFileName;
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

  static List<(String, String)> _buildEsPlaceholderReplacements(
    Map<String, dynamic> meta,
  ) {
    final evnr = _metaString(meta, 'evnr');
    final pos = _metaString(meta, 'posNr');
    final idNr = _metaString(meta, 'idNr');
    final zeitIso = _metaString(meta, 'zeitIso');
    final datum = _formatDateForDocx(zeitIso);
    final datumZeit = _formatDateTimeForDocx(zeitIso);
    final evnrPosition = [evnr, pos].where((e) => e.isNotEmpty).join('/');

    final oertlichkeit = _toStringSet(
      meta['oertlichkeit'],
    ).map((e) => _normalizeUmlauts(e).toLowerCase()).toSet();
    final oberflaeche = _toStringSet(
      meta['oberflaeche'],
    ).map((e) => _normalizeUmlauts(e).toLowerCase()).toSet();
    final schachtkopf = _toStringSet(
      meta['schachtkopf'],
    ).map((e) => _normalizeUmlauts(e).toLowerCase()).toSet();

    final deckelRaw = _metaString(meta, 'deckel');
    final deckel = _normalizeUmlauts(deckelRaw).toLowerCase();
    final einsteigartRaw = _metaString(meta, 'einsteigart');
    final einsteigart = _normalizeUmlauts(einsteigartRaw).toLowerCase();
    final steigeisenStand = _normalizeUmlauts(
      _metaString(meta, 'steigeisenStand'),
    ).toLowerCase();
    final durchmesser = _metaString(meta, 'durchmesser');
    final durchmesserMm = _formatSchachtdurchmesserMm(durchmesser);
    final durchmesserCm = _formatSchachtdurchmesserCm(durchmesser);
    final baumInDerNaehe = oberflaeche.contains('baum in der naehe');
    final baumZusatz = _baumZusatz(meta, baumInDerNaehe);
    final deckelMannloch = deckel.startsWith('mannloch');
    final deckelBeguDn625 = deckel.startsWith('begu dn 625');
    final deckelSonstige =
        deckel.isNotEmpty && !deckelMannloch && !deckelBeguDn625;
    final massSchachtkopf = _schachtkopfMassForDocx(meta, deckel);

    String x(bool selected) => selected ? 'X' : '';

    final replacements = <(String, String)>[];
    void add(Iterable<String> keys, String value) =>
        _addPlaceholderAliases(replacements, keys, value);

    add(['evnr'], evnr);
    add(['positionsnummer', 'es_positionsnummer'], pos);
    add(['evnr_position', 'auftragsnummer'], evnrPosition);
    add(['id_nr', 'schachtnummer', 'es_id_nr', 'es_schachtnummer'], idNr);
    add(['objekt', 'es_objekt'], 'Einstiegschacht');
    add(['datum_zeit'], datumZeit);
    add(['datum'], datum);
    add(['erfasser', 'name'], _metaString(meta, 'erfasser'));
    add(['strasse'], _metaString(meta, 'strasse'));
    add(['wetter'], _metaString(meta, 'wetter'));
    add(['gps_breitengrad', 'es_gps_breitengrad'], _gpsCoordinate(meta, 'lat'));
    add(['gps_laengengrad', 'es_gps_laengengrad'], _gpsCoordinate(meta, 'lon'));
    add([
      'verfuegbarkeit',
      'es_verfuegbarkeit',
    ], _joinMetaText(meta['verfuegbarkeit']));
    add([
      'status_vor_ort',
      'es_status_vor_ort',
    ], _joinMetaText(meta['statusVorOrt']));
    add(
      ['abteilung', 'es_abteilung'],
      _joinMetaText(
        meta['abteilungen'] ?? meta['abteilung'] ?? meta['abteilungsMarker'],
      ),
    );
    add(['schaeden', 'es_schaeden'], _schaedenText(meta));
    add(['bemerkung', 'es_bemerkung'], _metaString(meta, 'bemerkung'));

    add(['es_eingangsart'], _metaString(meta, 'eingang'));
    add(['es_einsteigart'], einsteigartRaw);
    add(['es_deckelart'], deckelRaw);
    add(['es_kl'], _metaString(meta, 'kl'));
    add(['schachtdurchmesser', 'es_schachtdurchmesser'], durchmesserMm);
    add(['kanalprofil', 'es_kanalprofil'], _metaString(meta, 'kanalprofil'));
    add(['es_schachtkopfart'], x(schachtkopf.isNotEmpty));
    add(['es_oertlichkeit'], x(oertlichkeit.isNotEmpty));
    add(['es_bemerkung_oertlichkeit'], _metaString(meta, 'oertlBem'));
    add(['es_oberflaechenart'], x(oberflaeche.isNotEmpty));
    add(['es_bemerkung_oberflaeche'], _metaString(meta, 'obflBem'));

    add([
      'oertlichkeit_hauptstrasse',
      'hauptstrasse',
      'es_oertlichkeit_hauptstrasse',
    ], x(oertlichkeit.contains('hauptstrasse')));
    add([
      'oertlichkeit_nebenstrasse',
      'nebenstrasse',
      'es_oertlichkeit_nebenstrasse',
    ], x(oertlichkeit.contains('nebenstrasse')));
    add([
      'oertlichkeit_spuren',
      'spuren',
      'es_oertlichkeit_spuren',
    ], x(oertlichkeit.contains('spuren')));
    add([
      'oertlichkeit_kreuzung',
      'kreuzung',
      'es_oertlichkeit_kreuzung',
    ], x(oertlichkeit.contains('kreuzung')));
    add([
      'oertlichkeit_baustellensicherung',
      'baustellensicherung',
      'es_oertlichkeit_baustellensicherung',
    ], x(oertlichkeit.contains('baustellensicherung')));
    add([
      'oertlichkeit_einbahnstrasse',
      'einbahnstrasse',
      'es_oertlichkeit_einbahnstrasse',
    ], x(oertlichkeit.contains('einbahnstrasse')));
    add([
      'oertlichkeit_geh_radweg',
      'geh_radweg',
      'es_oertlichkeit_geh_radweg',
    ], x(oertlichkeit.contains('geh-/radweg')));

    add([
      'oberflaeche_asphalt',
      'asphalt',
      'es_oberflaeche_asphalt',
    ], x(oberflaeche.contains('asphalt')));
    add([
      'oberflaeche_teerhaltig',
      'teerhaltig',
      'es_oberflaeche_teerhaltig',
    ], x(oberflaeche.contains('teerhaltig')));
    add([
      'oberflaeche_grossstein',
      'grossstein',
      'es_oberflaeche_grossstein',
    ], x(oberflaeche.contains('grossstein')));
    add([
      'oberflaeche_kleinstein',
      'kleinstein',
      'es_oberflaeche_kleinstein',
    ], x(oberflaeche.contains('kleinstein')));
    add([
      'oberflaeche_kupla',
      'kupla',
      'es_oberflaeche_kupla',
    ], x(oberflaeche.contains('kupla')));
    add([
      'oberflaeche_sonstige',
      'es_oberflaeche_sonstige',
    ], x(oberflaeche.contains('sonstige')));
    add([
      'oberflaeche_gruenflaeche',
      'gruenflaeche',
      'es_oberflaeche_gruenflaeche',
    ], x(oberflaeche.contains('gruenflaeche')));
    add(['baum_in_der_naehe', 'es_baum_in_der_naehe'], x(baumInDerNaehe));
    add(['baum_zusatz', 'es_baum_zusatz'], baumZusatz);

    add([
      'schachtkopf_mannloch',
      'mannloch',
      'es_schachtkopf_mannloch',
    ], deckelMannloch ? 'Mann' : '');
    add([
      'schachtkopf_begu_dn_625',
      'begu_dn_625',
      'es_schachtkopf_begu_dn_625',
    ], deckelBeguDn625 ? '62,5' : '');
    add(['schachtkopf_sonstige', 'es_schachtkopf_sonstige'], x(deckelSonstige));
    add([
      'schachtkopf_ausgleichsringe',
      'ausgleichsringe',
      'es_schachtkopf_ausgleichsringe',
    ], x(schachtkopf.contains('ausgleichsringe')));
    add([
      'schachtkopf_uebergangsplatte',
      'uebergangsplatte',
      'es_schachtkopf_uebergangsplatte',
    ], x(schachtkopf.contains('uebergangsplatte (hoehe)')));
    add([
      'konus_dn_625_ohne_versatz',
      'es_schachtkopf_konus_dn_625_ohne_versatz',
    ], x(schachtkopf.contains('konus dn 625 o. versatz')));
    add([
      'konus_dn_700_mit_versatz',
      'es_schachtkopf_konus_dn_700_mit_versatz',
    ], x(schachtkopf.contains('konus dn 700 m. versatz')));
    add([
      'steigeisen_alt',
      'es_steigeisen_alt',
    ], x(einsteigart == 'steigeisen' && steigeisenStand == 'alt'));
    add([
      'steigeisen_neu',
      'es_steigeisen_neu',
    ], x(einsteigart == 'steigeisen' && steigeisenStand == 'neu'));
    add([
      'leiter_vorhanden',
      'leiter',
      'es_leiter',
    ], x(einsteigart == 'leiter'));
    add(
      ['sonstige', 'es_sonstige'],
      x(
        einsteigart.isNotEmpty &&
            einsteigart != 'leiter' &&
            einsteigart != 'steigeisen',
      ),
    );

    add(['mass_schachtkopf', 'es_mass_schachtkopf'], massSchachtkopf);
    add(['konusanfang', 'es_konusanfang'], _metaString(meta, 'mKonusAnf'));
    add([
      'steigeisen_1_steighoehe',
      'steighoehe_1_steigeisen',
      'es_steigeisen_1_steighoehe',
    ], _metaString(meta, 'st1Hoehe'));
    add([
      'steigeisen_2_steighoehe',
      'steighoehe_2_steigeisen',
      'es_steigeisen_2_steighoehe',
    ], _metaString(meta, 'st2Hoehe'));
    add(['mass_815', 'es_mass_815'], '');
    add([
      'steigeisen_1_rueckenfreiheit',
      'rueckenfreiheit_1_steigeisen',
      'es_steigeisen_1_rueckenfreiheit',
    ], _metaString(meta, 'st1Rf'));
    add(['konusende', 'es_konusende'], _metaString(meta, 'mKonusEnd'));
    add([
      'steigeisen_2_rueckenfreiheit',
      'rueckenfreiheit_2_steigeisen',
      'es_steigeisen_2_rueckenfreiheit',
    ], _metaString(meta, 'st2Rf'));
    add([
      'schachtdurchmesser_skizze',
      'es_schachtdurchmesser_skizze',
    ], durchmesserCm);
    add(['berme', 'es_berme'], _metaString(meta, 'mBerme'));
    add(['solltiefe', 'es_solltiefe'], _metaString(meta, 'mSolltiefe'));

    return replacements;
  }

  static List<(String, String)> _buildVsPlaceholderReplacements(
    Map<String, dynamic> meta,
  ) {
    final evnr = _metaString(meta, 'evnr');
    final pos = _metaString(meta, 'posNr');
    final zeitIso = _metaString(meta, 'zeitIso');
    final datum = _formatDateForDocx(zeitIso);
    final datumZeit = _formatDateTimeForDocx(zeitIso);
    final wetterRaw = _metaString(meta, 'wetter');
    final wetter = _normalizeUmlauts(wetterRaw).toLowerCase();
    final grubenartRaw = _metaString(meta, 'grubentyp');
    final grubenart = _normalizeUmlauts(grubenartRaw).toLowerCase();
    final wasserText = _metaString(meta, 'wasser_cm');
    final wasser = double.tryParse(wasserText.replaceAll(',', '.')) ?? 0;
    final anschlussJa = meta['anschlussJa'] == true;
    final anschlussNein = meta['anschlussJa'] == false;
    final teller = _normalizeUmlauts(_metaString(meta, 'teller')).toLowerCase();
    final filtersandJa = meta['filtersandJa'] == true;
    final filtersandNein = meta['filtersandJa'] == false;
    final filtersandEig = _toStringSet(
      meta['filtersandEigensch'],
    ).map((e) => _normalizeUmlauts(e).toLowerCase()).toSet();

    String x(bool selected) => selected ? 'X' : '';

    final replacements = <(String, String)>[];
    void add(Iterable<String> keys, String value) =>
        _addPlaceholderAliases(replacements, keys, value);

    add(['evnr', 'auftragsnummer'], evnr);
    add(['positionsnummer', 'sg_positionsnummer'], pos);
    add(['id_nr', 'sg_id_nr'], _metaString(meta, 'idNr'));
    add(['objekt', 'sg_objekt'], 'Sickergrube / Versitzgrube');
    add(['datum_zeit'], datumZeit);
    add(['datum'], datum);
    add(['erfasser', 'name'], _metaString(meta, 'erfasser'));
    add(['strasse'], _metaString(meta, 'strasse'));
    add(['wetter'], wetterRaw);
    add(['gps_breitengrad', 'sg_gps_breitengrad'], _gpsCoordinate(meta, 'lat'));
    add(['gps_laengengrad', 'sg_gps_laengengrad'], _gpsCoordinate(meta, 'lon'));
    add([
      'verfuegbarkeit',
      'sg_verfuegbarkeit',
    ], _joinMetaText(meta['verfuegbarkeit']));
    add([
      'status_vor_ort',
      'sg_status_vor_ort',
    ], _joinMetaText(meta['statusVorOrt']));
    add(
      ['abteilung', 'sg_abteilung'],
      _joinMetaText(
        meta['abteilungen'] ?? meta['abteilung'] ?? meta['abteilungsMarker'],
      ),
    );
    add(['schaeden', 'sg_schaeden'], _schaedenText(meta));
    add(['bemerkung', 'sg_bemerkung'], _metaString(meta, 'bemerkung'));

    add(['sg_grubenart'], grubenartRaw);
    add(['sg_deckelart'], _metaString(meta, 'deckel'));
    add(['sg_kl'], _metaString(meta, 'kl'));
    add(['baujahr', 'sg_baujahr'], _metaString(meta, 'baujahr'));

    add([
      'witterung_sonne',
      'sg_witterung_sonne',
    ], x(wetter == 'klar' || wetter == 'sonne'));
    add(['witterung_regen', 'sg_witterung_regen'], x(wetter == 'regen'));
    add([
      'witterung_letzter_niederschlag',
      'sg_witterung_letzter_niederschlag',
    ], _metaString(meta, 'letzterNiederschlag'));

    add([
      'grubenart_kb_schacht',
      'sg_grubenart_kb_schacht',
    ], x(grubenart == 'kb-schacht'));
    add(['grubenart_din', 'sg_grubenart_din'], x(grubenart == 'din'));
    add([
      'grubenart_gemauert',
      'sg_grubenart_gemauert',
    ], x(grubenart == 'gemauert'));

    add(['grubentiefe_cm', 'sg_grubentiefe_cm'], _metaString(meta, 'tiefe_cm'));
    add(['wasserstand_ja', 'sg_wasserstand_ja'], x(wasser > 0));
    add(['wasserstand_nein', 'sg_wasserstand_nein'], x(wasser <= 0));
    add(['wasserstand_cm', 'sg_wasserstand_cm'], wasser > 0 ? wasserText : '');
    add([
      'anschluss_vorhanden_ja',
      'sg_anschluss_vorhanden_ja',
    ], x(anschlussJa));
    add([
      'anschluss_vorhanden_nein',
      'sg_anschluss_vorhanden_nein',
    ], x(anschlussNein));
    add([
      'anschluss_offen_ja',
      'sg_anschluss_offen_ja',
    ], x(anschlussJa && teller == 'offen'));
    add([
      'anschluss_offen_nein',
      'sg_anschluss_offen_nein',
    ], x(anschlussJa && teller == 'nicht offen'));
    add(['filtersand_ja', 'sg_filtersand_ja'], x(filtersandJa));
    add(['filtersand_nein', 'sg_filtersand_nein'], x(filtersandNein));
    add([
      'filtersand_locker',
      'sg_filtersand_locker',
    ], x(filtersandEig.contains('locker')));
    add([
      'filtersand_sickerfaehig',
      'sg_filtersand_sickerfaehig',
    ], x(filtersandEig.contains('sickerfaehig')));
    add([
      'filtersand_fest',
      'sg_filtersand_fest',
    ], x(filtersandEig.contains('fest')));
    add([
      'filtersand_lehmig',
      'sg_filtersand_lehmig',
    ], x(filtersandEig.contains('lehmig')));

    return replacements;
  }

  static void _addPlaceholderAliases(
    List<(String, String)> replacements,
    Iterable<String> keys,
    String value,
  ) {
    final normalizedValue = _normalizeDocxValue(value);
    for (final key in keys) {
      final normalizedKey = key.trim();
      if (normalizedKey.isEmpty) continue;
      replacements.add((normalizedKey, normalizedValue));
    }
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String _joinMetaText(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';
      return trimmed
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
    }
    return value.toString().trim();
  }

  static String _schaedenText(Map<String, dynamic> meta) {
    final schaeden = _joinMetaText(meta['schaeden']);
    if (schaeden.isNotEmpty) return schaeden;
    return meta['keinBefund'] == true ? 'Kein Befund' : '';
  }

  static String _schachtkopfMassForDocx(
    Map<String, dynamic> meta,
    String deckel,
  ) {
    if (deckel.startsWith('begu dn 625')) return '62,5';
    if (deckel.startsWith('mannloch')) return '';

    final saved = _firstNonEmpty([
      _metaString(meta, 'mass_schachtkopf'),
      _metaString(meta, 'mSchachtkopf'),
    ]);
    if (saved.isNotEmpty) return _normalizeMassCm(saved);
    if (deckel.isNotEmpty) return '80';
    return '';
  }

  static String _formatSchachtdurchmesserMm(String value) {
    final number = _toDouble(value);
    if (number == null) return value.trim();
    final mm = number >= 500 ? number : number * 10;
    return _formatMeasurement(mm);
  }

  static String _formatSchachtdurchmesserCm(String value) {
    final number = _toDouble(value);
    if (number == null) return value.trim();
    final cm = number >= 500 ? number / 10 : number;
    return _formatMeasurement(cm);
  }

  static String _normalizeMassCm(String value) {
    final number = _toDouble(value);
    if (number == null) return value.trim();
    return _formatMeasurement(number);
  }

  static String _formatMeasurement(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value
        .toStringAsFixed(1)
        .replaceAll('.', ',')
        .replaceFirst(RegExp(r',0$'), '');
  }

  static String _baumZusatz(Map<String, dynamic> meta, bool baumInDerNaehe) {
    if (!baumInDerNaehe) return '';
    return _metaString(meta, 'obflBem');
  }

  static String _gpsCoordinate(Map<String, dynamic> meta, String key) {
    final rawGps = meta['gps'];
    dynamic raw;
    if (rawGps is Map) {
      raw = key == 'lat'
          ? rawGps['lat'] ?? rawGps['latitude'] ?? rawGps['gpsLat']
          : rawGps['lon'] ?? rawGps['lng'] ?? rawGps['gpsLon'];
    } else {
      raw = key == 'lat'
          ? meta['gpsLat'] ?? meta['lat']
          : meta['gpsLon'] ?? meta['lon'] ?? meta['lng'];
    }
    final value = _toDouble(raw);
    return value == null ? '' : value.toStringAsFixed(6);
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  static String _formatDateTimeForDocx(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  static String _normalizeUmlauts(String input) {
    return input
        .replaceAll('\u00c4', 'Ae')
        .replaceAll('\u00d6', 'Oe')
        .replaceAll('\u00dc', 'Ue')
        .replaceAll('\u00e4', 'ae')
        .replaceAll('\u00f6', 'oe')
        .replaceAll('\u00fc', 'ue')
        .replaceAll('\u00df', 'ss')
        .replaceAll('Ã„', 'Ae')
        .replaceAll('Ã–', 'Oe')
        .replaceAll('Ãœ', 'Ue')
        .replaceAll('Ã¤', 'ae')
        .replaceAll('Ã¶', 'oe')
        .replaceAll('Ã¼', 'ue')
        .replaceAll('ÃŸ', 'ss');
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
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
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

  static String _buildOutputFileName({
    required String templateFileName,
    required List<(String, String)> replacements,
  }) {
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    if (_isEsTemplate(templateFileName)) {
      String evnr = 'EVNR';
      String pos = 'POSITION';

      for (final (label, value) in replacements) {
        final key = label.trim();
        if (key == 'evnr' && value.trim().isNotEmpty) {
          evnr = value.trim();
        }
        if ((key == 'positionsnummer' || key == 'es_positionsnummer') &&
            value.trim().isNotEmpty) {
          pos = value.trim();
        }
        if ((key == 'evnr_position' || key == 'auftragsnummer') &&
            value.contains('/')) {
          final parts = value.split('/').map((e) => e.trim()).toList();
          if (parts.isNotEmpty && parts.first.isNotEmpty) {
            evnr = parts.first;
          }
          if (parts.length > 1 && parts[1].isNotEmpty) {
            pos = parts[1];
          }
        }
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
      final xmlFile = decoded.files
          .where((f) => f.isFile && f.name == 'word/document.xml')
          .firstOrNull;
      if (xmlFile == null) {
        debugPrint(
          '[FormularService][DOCX][VALIDATE] word/document.xml fehlt ${context == null ? '' : '(ctx=$context)'}',
        );
        return false;
      }

      final content = xmlFile.content;
      utf8.decode(content, allowMalformed: true);
      return true;
    } catch (e) {
      debugPrint(
        '[FormularService][DOCX][VALIDATE] Fehler ${context == null ? '' : '(ctx=$context)'}: $e',
      );
      return false;
    }
  }
}

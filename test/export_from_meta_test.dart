// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:erfasser_app/services/export_service.dart';
import 'package:erfasser_app/services/speicher_service.dart';
import 'test_data/current_meta_samples.dart';
// entfernt: ungenutzte Importe

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Export from meta', () {
    test('buildEinzelPdfFromMeta returns PDF bytes', () async {
      final meta = buildCurrentVsMeta();

      final bytes = await ExportService.buildEinzelPdfFromMeta(
        meta: meta,
        erfasser: 'Tester',
        wetter: 'Sonne',
      );
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(10));
    });

    test('Lüftung metaToFields includes Deckelart, Aufbau, KL when Neu', () {
      final meta = {
        'typ': 'LÜ',
        'evnr': 'E00004',
        'posNr': '1',
        'strasse': 'Luftstr',
        'zeitIso': DateTime.now().toIso8601String(),
        'abteilung': '312_IZ AR',
        'art': 'Neu',
        'kl': 'D',
        'schaeden': [],
        'keinBefund': true,
        'verfuegbarkeit': [],
      };

      final fields = SpeicherService.metaToFields(meta, erfasser: 'TestErf');

      // Debug output
      print('LÜ fields: $fields');

      expect(
        fields['Deckelart'],
        equals('Neu'),
        reason: 'Deckelart should be "Neu"',
      );
      expect(fields['Aufbau'], equals('Neu'), reason: 'Aufbau should be "Neu"');
      expect(fields['KL'], equals('D'), reason: 'KL should be "D"');
      expect(
        fields.containsKey('Schäden'),
        isTrue,
        reason: 'Schäden should be in fields',
      );
    });

    test('buildGesamtPdfFromMetas creates gesamtbericht PDF', () async {
      final metas = <Map<String, dynamic>>[buildCurrentVsMeta()];

      final bytes = await ExportService.buildGesamtPdfFromMetas(
        evnr: 'E00001',
        metas: metas,
        erfasser: 'Tester',
        strasse: 'Teststraße',
      );
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(100));
    });

    test('buildCsvFromMetas creates csv with expected columns and values', () {
      final bytes = ExportService.buildCsvFromMetas(
        evnr: 'E00005',
        strasse: 'Csvstraße',
        metas: [
          {
            'typ': 'DIV',
            'evnr': 'E00005',
            'posNr': '4',
            'strasse': 'Csvstraße',
            'statusVorOrt': ['Kontrolliert'],
            'verfuegbarkeit': ['Verfügbar'],
            'schaeden': ['Deckel beschädigt'],
            'bemerkung': 'Testeintrag',
            'abteilungen': ['312 Ost'],
            'mediaFotos': ['data:image/jpeg;base64,AA=='],
            'mediaVideos': <String>[],
            'mediaAudios': <String>[],
            'mediaPdfs': <String>[],
          },
        ],
      );

      final csv = utf8.decode(bytes);
      expect(csv, contains('"EVNr";"Straße";"Position";"Objekt"'));
      expect(csv, contains('"E00005";"Csvstraße";"4";"DIV"'));
      expect(csv, contains('"Deckel beschädigt"'));
    });

    test('buildCsvFromMetas writes VG instead of VS for grube object code', () {
      final bytes = ExportService.buildCsvFromMetas(
        evnr: 'E00006',
        strasse: 'Grubenstraße',
        metas: [buildCurrentVsMeta()],
      );

      final csv = utf8.decode(bytes);
      expect(csv, contains('"E00006";"Musterstrasse 2";"2a";"VG"'));
      expect(csv, isNot(contains('"VS"')));
    });

    test('media are properly detected in meta', () async {
      final imageData = base64Encode([1, 2, 3, 4, 5]);
      final meta = {
        'typ': 'DIV',
        'evnr': 'E00002',
        'posNr': '1',
        'strasse': 'Mediast',
        'abteilung': '313_BU',
        'mediaFotos': ['data:image/jpeg;base64,$imageData'],
        'mediaVideos': ['data:video/mp4;base64,$imageData'],
        'verfuegbarkeit': [],
      };

      final bytes = await ExportService.buildEinzelPdfFromMeta(meta: meta);
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(10));
    });

    test('grube with meter values generates steckbrief', () async {
      final meta = buildCurrentVsMeta()
        ..addAll({
          'tiefe_m': '1.2',
          'wasser_m': '0.1',
          'verfuegbarkeit': ['Ergänzen'],
          'verfuegbarkeit_ergaenzen': 'Laengere Bearbeitung erforderlich',
        });

      final bytes = await ExportService.buildEinzelPdfFromMeta(meta: meta);
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(10));
    });

    test('VG metaToFields includes grube and anschluss steckbrief details', () {
      final fields = SpeicherService.metaToFields(buildCurrentVsMeta());

      expect(fields['Grubentiefe (cm)'], equals('120'));
      expect(fields['Wasserstand (cm)'], equals('45'));
      expect(fields['Anschluss am Kanal'], equals('Ja'));
      expect(fields['Überlauf'], equals('offen'));
      expect(fields['Filtersand'], equals('Ja'));
      expect(fields['Filtersand Eigenschaften'], contains('locker'));
      expect(fields['Filtersand Eigenschaften'], contains('sickerfaehig'));
    });

    test('VG alias is handled as sickergrube in steckbrief export', () async {
      final meta = buildCurrentVsMeta()..['typ'] = 'VG';

      final fields = SpeicherService.metaToFields(meta);
      expect(fields['Grubentiefe (cm)'], equals('120'));
      expect(fields['Anschluss am Kanal'], equals('Ja'));

      final bytes = await ExportService.buildEinzelPdfFromMeta(meta: meta);
      expect(bytes.length, greaterThan(10));
    });

    test('ES adds no supplemental ladder-installation text', () {
      final meta = <String, dynamic>{
        'typ': 'ES',
        'evnr': 'E00007',
        'posNr': '1',
        'strasse': 'Teststrasse',
        'schaeden': ['1. Steigeisen entfernen', 'Leiter einbauen'],
        'keinBefund': false,
        'verfuegbarkeit': <String>[],
      };

      final fields = SpeicherService.metaToFields(meta);
      expect(
        fields['Schäden'],
        equals('1. Steigeisen entfernen, Leiter einbauen'),
      );
      expect(fields['Schäden'], isNot(contains('Leiter einbau möglich')));

      final csv = utf8.decode(
        ExportService.buildCsvFromMetas(
          evnr: 'E00007',
          strasse: 'Teststrasse',
          metas: [meta],
        ),
      );
      expect(csv, isNot(contains('Leiter einbau möglich')));
    });

    test('media description includes media and file counts', () {
      final description = ExportService.mediaDescriptionFromMeta({
        'mediaFotos': ['foto-1.jpg', 'foto-2.jpg'],
        'mediaVideos': ['video.mp4'],
        'mediaAudios': ['audio.mp3'],
        'mediaPdfs': ['plan.pdf', 'liste.xlsx'],
      });

      expect(description, contains('2 Fotos'));
      expect(description, contains('1 Video'));
      expect(description, contains('1 Audio-Datei'));
      expect(description, contains('1 PDF-Datei'));
      expect(description, contains('1 Office-Datei'));
    });

    test('media bindings are not counted twice', () {
      final description = ExportService.mediaDescriptionFromMeta({
        'mediaFotos': ['foto.jpg'],
        'mediaBindings': [
          {'kind': 'foto', 'value': 'foto.jpg'},
        ],
      });

      expect(description, contains('1 Foto'));
      expect(description, isNot(contains('2 Fotos')));
    });
  });
}

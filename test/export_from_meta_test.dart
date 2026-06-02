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

      final bytes = await ExportService.buildEinzelPdfFromMeta(meta: meta, erfasser: 'Tester', wetter: 'Sonne');
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
      
      expect(fields['Deckelart'], equals('Neu'), reason: 'Deckelart should be "Neu"');
      expect(fields['Aufbau'], equals('Neu'), reason: 'Aufbau should be "Neu"');
      expect(fields['KL'], equals('D'), reason: 'KL should be "D"');
      expect(fields.containsKey('Schäden'), isTrue, reason: 'Schäden should be in fields');
    });

    test('buildGesamtPdfFromMetas creates gesamtbericht PDF', () async {
      final metas = <Map<String, dynamic>>[
        buildCurrentVsMeta(),
      ];

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
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
// Test uses meta-based export; direkte Model-Imports nicht benötigt
import 'package:erfasser_app/services/export_service.dart';
import 'package:erfasser_app/services/export_plan_service.dart';
import 'test_data/current_meta_samples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExportService.buildZipFromPlanMeta structure', () {
    test('Generates expected folder and files via plan', () async {
      // Erzeuge test-Metas mit neuem 312/313 Prinzip
      final metas = <Map<String, dynamic>>[
        buildCurrentSskMeta(posNr: '1')
          ..addAll({
            'evnr': 'E00001',
            'strasse': 'Musterstrasse',
            'storageKey': '1',
            'abteilungen': ['312_Ost'],
          }),
        buildCurrentSskMeta(posNr: '2')
          ..addAll({
            'evnr': 'E00001',
            'strasse': 'Musterstrasse',
            'storageKey': '2',
            'abteilungen': ['313_TU'],
          }),
      ];

      // Build ExportPlan first
      final plan = buildExportPlanFromMeta(
        evnr: 'E00001',
        strasse: 'Musterstrasse',
        metas: metas,
        fotosPerEntry: [[], []],
        videosPerEntry: [[], []],
      );

      // Export via Plan
      final zipBytes = await ExportService.buildZipFromPlanMeta(
        plan,
        metas,
        erfasser: 'Test',
        wetter: 'Sonne',
      );

      final archive = ZipDecoder().decodeBytes(zipBytes);
      final names = archive.files.map((f) => f.name).toList()..sort();

      // Check for expected files in new structure
      expect(names, anyElement(contains('Erfassungen/Gesamt_Bericht.pdf')));
      expect(names, anyElement(contains('Erfassungen/1/Steckbrief.pdf')));
      expect(names, anyElement(contains('Erfassungen/2/Steckbrief.pdf')));
      expect(names, anyElement(contains('Aufträge/312_Ost/1/Steckbrief.pdf')));
      expect(names, anyElement(contains('Aufträge/313_TU/2/Steckbrief.pdf')));
      expect(names, anyElement(contains('Schriftverkehr/Vorlagen/')));
      expect(names, anyElement(contains('EV Ordner/README.txt')));
      expect(names, anyElement(contains('NIS/README.txt')));
    });
  });
}

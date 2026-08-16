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
        buildCurrentSskMeta(posNr: '1/3')..addAll({
          'evnr': 'E00001',
          'strasse': 'Musterstraße 7',
          'storageKey': '1-3',
          'abteilungen': ['312_Ost'],
        }),
        buildCurrentSskMeta(posNr: '2')..addAll({
          'evnr': 'E00001',
          'strasse': 'Musterstraße 7',
          'storageKey': '2',
          'abteilungen': ['313_TU'],
        }),
      ];

      // Build ExportPlan first
      final plan = buildExportPlanFromMeta(
        evnr: 'E00001',
        strasse: 'Musterstraße 7',
        metas: metas,
        fotosPerEntry: [
          ['data:image/jpeg;base64,AQID'],
          [],
        ],
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

      const root = 'E00001_Musterstraße_7';
      final topLevelFolders = names
          .map((name) => name.split('/'))
          .where((parts) => parts.length >= 2 && parts.first == root)
          .map((parts) => parts[1])
          .toSet();
      expect(
        topLevelFolders,
        equals({'EV', 'NIS', 'Schriftverkehr', 'Aufträge', 'Erfassung'}),
      );

      expect(names, contains('$root/EV/erfassungen.json'));
      expect(names, contains('$root/EV/README.txt'));
      expect(names, contains('$root/NIS/README.txt'));
      expect(names, contains('$root/Schriftverkehr/README.txt'));
      expect(names, anyElement(startsWith('$root/Schriftverkehr/Vorlagen/')));

      expect(names, contains('$root/Erfassung/Gesamt_Bericht.pdf'));
      expect(names, contains('$root/Erfassung/1-3/Steckbrief.pdf'));
      expect(names, contains('$root/Erfassung/1-3/Medien/Fotos/foto_1.jpg'));
      expect(names, contains('$root/Erfassung/2/Steckbrief.pdf'));

      expect(
        names,
        contains('$root/Aufträge/312_Ost/Gesamt_Bericht_312_Ost.pdf'),
      );
      expect(
        names,
        contains('$root/Aufträge/312_Ost/1-3/Bericht_Position_1-3.pdf'),
      );
      expect(
        names,
        contains('$root/Aufträge/312_Ost/1-3/Medien/Fotos/foto_1.jpg'),
      );
      expect(
        names,
        contains('$root/Aufträge/313_TU/Gesamt_Bericht_313_TU.pdf'),
      );
      expect(names, contains('$root/Aufträge/313_TU/2/Bericht_Position_2.pdf'));
    });
  });
}

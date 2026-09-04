import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:erfasser_app/services/import_export_service.dart';
import 'package:erfasser_app/services/speicher_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('exportiereDaten schreibt Medien als Dateien ins ZIP', () async {
    final fotoDataUrl = 'data:image/jpeg;base64,${base64Encode(Uint8List.fromList([1, 2, 3, 4]))}';
    final pdfDataUrl = 'data:application/pdf;base64,${base64Encode(Uint8List.fromList([5, 6, 7, 8]))}';

    await SpeicherService.upsertEntry(
      'obj_E123_Teststrasse_1_DIV',
      {
        'typ': 'DIV',
        'evnr': 'E123',
        'strasse': 'Teststrasse',
        'posNr': '1',
        'mediaFotos': [fotoDataUrl],
        'mediaPdfs': [pdfDataUrl],
      },
    );

    final zipBytes = await ImportExportService.exportiereDaten(
      evnrs: const ['E123'],
      strasse: 'Teststrasse',
    );

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final names = archive.files.where((f) => f.isFile).map((f) => f.name.replaceAll('\\', '/')).toList();

    expect(names, contains('erfassungen.json'));
    expect(names.any((name) => name.contains('medien/E123/1/fotos/')), isTrue);
    expect(names.any((name) => name.contains('medien/E123/1/pdfs/')), isTrue);
  });

  test('importiereDaten rekonstruiert dateibasierte Medienreferenzen als Data URLs', () async {
    final archive = Archive();
    final eintrag = {
      'typ': 'DIV',
      'evnr': 'E456',
      'strasse': 'Importweg',
      'posNr': '7',
      'mediaFotos': ['medien/E456/7/fotos/DIV_obj_1.jpg'],
      'mediaPdfs': ['medien/E456/7/pdfs/DIV_obj_1.pdf'],
    };

    final erfassungen = jsonEncode({
      'E456': [eintrag],
    });

    archive.addFile(ArchiveFile('erfassungen.json', erfassungen.length, utf8.encode(erfassungen)));
    archive.addFile(ArchiveFile('medien/E456/7/fotos/DIV_obj_1.jpg', 4, Uint8List.fromList([1, 2, 3, 4])));
    archive.addFile(ArchiveFile('medien/E456/7/pdfs/DIV_obj_1.pdf', 4, Uint8List.fromList([5, 6, 7, 8])));

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));

    final result = await ImportExportService.importiereDaten(zipBytes);
    expect(result, (1, 1));

    final geladen = await SpeicherService.ladeEintraegeFuerEvNr('E456', strasse: 'Importweg');
    expect(geladen, hasLength(1));

    final mediaFotos = (geladen.first['mediaFotos'] as List<dynamic>?)?.cast<String>() ?? const <String>[];
    final mediaPdfs = (geladen.first['mediaPdfs'] as List<dynamic>?)?.cast<String>() ?? const <String>[];

    expect(mediaFotos, hasLength(1));
    expect(mediaFotos.first.startsWith('data:image/jpeg;base64,'), isTrue);
    expect(mediaPdfs, hasLength(1));
    expect(mediaPdfs.first.startsWith('data:application/pdf;base64,'), isTrue);
  });
}
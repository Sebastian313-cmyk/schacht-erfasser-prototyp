import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:erfasser_app/services/formular_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data/current_meta_samples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FormularService DOCX placeholder filling', () {
    test('fills Einstiegschacht template only through placeholders', () async {
      final meta = buildCurrentEsMeta(withRf: true, withBaumInDerNaehe: true)
        ..addAll({
          'zeitIso': '2026-05-15T08:30:00',
          'oertlichkeit': ['Hauptstrasse', 'Geh-/Radweg'],
          'oberflaeche': ['Asphalt', 'Baum in der N\u00e4he'],
          'deckel': 'Begu DN 625',
          'schachtkopf': [
            'Ausgleichsringe',
            '\u00dcbergangsplatte (H\u00f6he)',
            'Konus DN 625 o. Versatz',
          ],
          'einsteigart': 'Steigeisen',
          'steigeisenStand': 'alt',
          'mSchachtkopf': 'DN 625',
          'mKonusAnf': '25',
          'mKonusEnd': '75',
          'mAusgleich': '815',
          'mBerme': '20',
          'mSolltiefe': '350',
        });

      final bytes =
          await FormularService.buildEinsteigschaechteDocxBytesFromMeta(meta);
      expect(bytes, isNotNull);

      final xml = _documentXml(bytes!);
      final text = _visibleText(xml);

      expect(xml, isNot(contains('{{')));
      expect(xml, isNot(contains('}}')));
      expect(xml, isNot(contains('{{sg_')));
      expect(text, contains('E90001/1'));
      expect(text, contains('15.05.2026'));
      expect(text, contains('Tester'));
      expect(text, contains('Musterstrasse 1'));
      expect(text, contains('12345678'));
      expect(text, contains('DN 1000'));
      expect(text, contains('Kreisprofil'));
      expect(text, contains('1,20m / D35cm'));
      expect(text, isNot(contains('Foto vorhanden')));
      expect(text, contains('62,5'));
      expect(text, contains('350'));
      expect(_filledXCount(xml), greaterThanOrEqualTo(5));
    });

    test('fills VG/Sickergrube template only through placeholders', () async {
      final meta = buildCurrentVsMeta()
        ..addAll({
          'zeitIso': '2026-05-16T10:45:00',
          'baujahr': '1998',
          'letzterNiederschlag': '14.05.2026',
        });

      final bytes = await FormularService.buildSickergrubenDocxBytesFromMeta(
        meta,
      );
      expect(bytes, isNotNull);

      final xml = _documentXml(bytes!);
      final text = _visibleText(xml);

      expect(xml, isNot(contains('{{')));
      expect(xml, isNot(contains('}}')));
      expect(xml, isNot(contains('{{es_')));
      expect(text, contains('E90002'));
      expect(text, contains('16.05.2026'));
      expect(text, contains('Tester'));
      expect(text, contains('Musterstrasse 2'));
      expect(text, contains('120'));
      expect(text, contains('45'));
      expect(text, contains('1998'));
      expect(text, contains('14.05.2026'));
      expect(_filledXCount(xml), greaterThanOrEqualTo(7));
    });

    test('fills DIN and Gemauert grubenart checkboxes', () async {
      final neutralMeta = buildCurrentVsMeta()
        ..addAll({
          'grubentyp': 'Absetzschacht',
          'wetter': 'bedeckt',
          'wasser_cm': '',
          'anschlussJa': null,
          'filtersandJa': null,
          'filtersandEigensch': <String>[],
        });
      final neutralXml = _documentXml(
        (await FormularService.buildSickergrubenDocxBytesFromMeta(
          neutralMeta,
        ))!,
      );
      final neutralXCount = _filledXCount(neutralXml);

      for (final grubenart in ['DIN', 'Gemauert']) {
        final meta = Map<String, dynamic>.from(neutralMeta)
          ..['grubentyp'] = grubenart;
        final xml = _documentXml(
          (await FormularService.buildSickergrubenDocxBytesFromMeta(meta))!,
        );

        expect(_visibleText(xml), contains(grubenart));
        expect(_filledXCount(xml), neutralXCount + 1);
      }
    });
  });
}

String _documentXml(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final file = archive.files.singleWhere(
    (file) => file.isFile && file.name == 'word/document.xml',
  );
  return utf8.decode(file.content as List<int>);
}

String _visibleText(String xml) {
  final buffer = StringBuffer();
  for (final match in RegExp(
    r'<w:t[^>]*>(.*?)</w:t>',
    dotAll: true,
  ).allMatches(xml)) {
    buffer.write(_decodeXml(match.group(1) ?? ''));
    buffer.write(' ');
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _decodeXml(String value) {
  return value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}

int _filledXCount(String xml) {
  return RegExp(r'<w:t[^>]*>\s*X\s*</w:t>').allMatches(xml).length;
}

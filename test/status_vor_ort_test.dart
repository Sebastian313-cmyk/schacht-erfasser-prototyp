import 'package:erfasser_app/constants/options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Status vor Ort', () {
    test('speichert Überbaut-Detail als einen Listeneintrag', () {
      final result = buildStatusVorOrtItems(
        {'zugeparkt', 'überbaut'},
        ueberbautText: 'Asphalt, teilweise',
      );

      expect(result, ['zugeparkt', 'überbaut: Asphalt, teilweise']);
    });

    test('stellt Auswahl und Detail aus gespeicherter Liste wieder her', () {
      final stored = ['Verkehr', 'überbaut: Pflaster'];

      expect(parseStatusVorOrtSelection(stored), {'Verkehr', 'überbaut'});
      expect(extractUeberbautText(stored), 'Pflaster');
    });

    test('liest auch den bisherigen kommagetrennten Text', () {
      const stored = 'zugewachsen, überbaut: Asphalt';

      expect(parseStatusVorOrtSelection(stored), {'zugewachsen', 'überbaut'});
      expect(extractUeberbautText(stored), 'Asphalt');
    });
  });
}

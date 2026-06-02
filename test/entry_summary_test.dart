import 'package:flutter_test/flutter_test.dart';
import 'package:erfasser_app/models/ssk_entry.dart';
import 'package:erfasser_app/models/enums.dart';
import 'package:erfasser_app/models/base_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EntrySummary Extension', () {
    test('SSK summary with title', () {
      final e = SskEntry(
        id: '1',
        evnr: 'EV1',
        positionsnummer: '1',
        titel: 'Deckel beschädigt',
        leitungsverlauf: 'Nord -> Süd',
        rinnenzustand: 'verschlammt',
        einlaufzustand: 'verstopft',
        statusVorOrtLabel: 'Austausch erforderlich',
        notizen: 'Foto gemacht',
        spezial: 'Statik prüfen',
      );
      expect(e.summaryShort, 'Deckel beschädigt');
      expect(
        e.summaryDetail,
        contains('Leitungsverlauf: Nord -> Süd'),
      );
      expect(e.summaryDetail, contains('Rinnenzustand: verschlammt'));
      expect(e.summaryDetail, contains('Einlaufzustand: verstopft'));
      expect(e.summaryDetail, contains('Notiz: Foto gemacht'));
      expect(e.summaryDetail, contains('Spezial: Statik prüfen'));
    });

    test('SSK summary without title falls back to parts', () {
      final e = SskEntry(
        id: '2',
        evnr: 'EV1',
        positionsnummer: '2',
        statusVorOrtLabel: 'Kontrolle',
        leitungsverlauf: 'Ost -> West',
        rinnenzustand: 'frei',
      );
      expect(e.summaryShort.startsWith('Kontrolle | Leitungsverlauf: Ost -> West'), isTrue);
      expect(e.summaryShort.contains('Rinne: frei'), isTrue);
    });

    test('Other type fallback to title or ohne Titel', () {
      final other = BaseEntry(id: 'x', type: EntryType.grube, evnr: 'EV1', titel: null);
      expect(other.summaryShort, 'ohne Titel');
      final titled = BaseEntry(id: 'y', type: EntryType.grube, evnr: 'EV1', titel: 'Grube 7');
      expect(titled.summaryShort, 'Grube 7');
    });
  });
}

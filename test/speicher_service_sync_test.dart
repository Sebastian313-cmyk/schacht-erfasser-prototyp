import 'package:erfasser_app/services/speicher_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('upsertEntry marks local changes as pending and increments sync version', () async {
    const key = 'obj_E900_Testweg_1_DIV';

    await SpeicherService.upsertEntry(key, {
      'typ': 'DIV',
      'evnr': 'E900',
      'strasse': 'Testweg',
      'posNr': '1',
    });

    var entries = await SpeicherService.ladeEintraegeFuerEvNr('E900', strasse: 'Testweg');
    expect(entries, hasLength(1));
    expect(entries.first['syncStatus'], 'pending');
    expect(entries.first['syncVersion'], 1);
    expect((entries.first['lastLocalChangeAt'] as String?)?.isNotEmpty, isTrue);

    await SpeicherService.updateEntry(key, {
      ...entries.first,
      'bemerkung': 'aktualisiert',
    });

    entries = await SpeicherService.ladeEintraegeFuerEvNr('E900', strasse: 'Testweg');
    expect(entries, hasLength(1));
    expect(entries.first['syncStatus'], 'pending');
    expect(entries.first['syncVersion'], 2);
    expect(entries.first['bemerkung'], 'aktualisiert');
  });
}
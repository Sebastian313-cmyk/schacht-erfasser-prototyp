import 'package:erfasser_app/services/speicher_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('upsertEntry keeps stable media binding ids and tracks removed media', () async {
    const key = 'obj_E901_Testweg_2_DIV';
    const fotoA = 'data:image/jpeg;base64,AAA=';
    const fotoB = 'data:image/jpeg;base64,BBB=';
    const audioA = 'data:audio/webm;base64,CCC=';

    await SpeicherService.upsertEntry(key, {
      'typ': 'DIV',
      'evnr': 'E901',
      'strasse': 'Testweg',
      'posNr': '2',
      'mediaFotos': [fotoA, fotoB],
      'mediaAudios': [audioA],
    });

    var entries = await SpeicherService.ladeEintraegeFuerEvNr('E901', strasse: 'Testweg');
    expect(entries, hasLength(1));

    final initial = entries.first;
    final initialBindings = (initial['mediaBindings'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(initialBindings, hasLength(3));
    expect(initial['deletedMediaBindingIds'], isEmpty);

    final fotoABinding = initialBindings.firstWhere((binding) => binding['value'] == fotoA);
    final fotoBBinding = initialBindings.firstWhere((binding) => binding['value'] == fotoB);
    final audioBinding = initialBindings.firstWhere((binding) => binding['value'] == audioA);

    await SpeicherService.updateEntry(key, {
      ...initial,
      'mediaFotos': [fotoA],
      'mediaAudios': [audioA],
    });

    entries = await SpeicherService.ladeEintraegeFuerEvNr('E901', strasse: 'Testweg');
    expect(entries, hasLength(1));

    final updated = entries.first;
    final updatedBindings = (updated['mediaBindings'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(updatedBindings, hasLength(2));

    final updatedFotoABinding = updatedBindings.firstWhere((binding) => binding['value'] == fotoA);
    final updatedAudioBinding = updatedBindings.firstWhere((binding) => binding['value'] == audioA);

    expect(updatedFotoABinding['id'], fotoABinding['id']);
    expect(updatedAudioBinding['id'], audioBinding['id']);
    expect(updatedFotoABinding['objectKey'], key);
    expect(updatedAudioBinding['objectKey'], key);

    final deletedIds = (updated['deletedMediaBindingIds'] as List<dynamic>).cast<String>();
    expect(deletedIds, hasLength(1));
    expect(deletedIds, contains(fotoBBinding['id']));
    expect(deletedIds, isNot(contains(fotoABinding['id'])));
  });
}

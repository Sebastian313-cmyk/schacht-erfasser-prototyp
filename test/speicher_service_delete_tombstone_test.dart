import 'dart:convert';

import 'package:erfasser_app/services/speicher_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('deleteEntry removes object from normal load and writes tombstone for sync', () async {
    const key = 'obj_E902_Testweg_3_DIV';
    const fotoA = 'data:image/jpeg;base64,AAA=';
    const audioA = 'data:audio/webm;base64,CCC=';

    await SpeicherService.upsertEntry(key, {
      'typ': 'DIV',
      'evnr': 'E902',
      'strasse': 'Testweg',
      'posNr': '3',
      'idNr': 'ID-3',
      'mediaFotos': [fotoA],
      'mediaAudios': [audioA],
    });

    var entries = await SpeicherService.ladeEintraegeFuerEvNr('E902', strasse: 'Testweg');
    expect(entries, hasLength(1));

    final bindingIds = ((entries.first['mediaBindings'] as List<dynamic>)
            .cast<Map<String, dynamic>>())
        .map((binding) => binding['id'] as String)
        .toSet();

    await SpeicherService.deleteEntry(key);

    entries = await SpeicherService.ladeEintraegeFuerEvNr('E902', strasse: 'Testweg');
    expect(entries, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    final tombstoneJson = prefs.getString('deleted_obj_$key');
    expect(tombstoneJson, isNotNull);

    final tombstone = jsonDecode(tombstoneJson!) as Map<String, dynamic>;
    expect(tombstone['storageKey'], key);
    expect(tombstone['syncStatus'], 'pending_delete');
    expect(tombstone['evnr'], 'E902');
    expect(tombstone['strasse'], 'Testweg');
    expect(tombstone['posNr'], '3');
    expect(tombstone['idNr'], 'ID-3');
    expect((tombstone['deletedAt'] as String).isNotEmpty, isTrue);
    expect((tombstone['lastLocalChangeAt'] as String).isNotEmpty, isTrue);
    expect(tombstone['syncVersion'], 2);

    final deletedBindingIds = (tombstone['deletedMediaBindingIds'] as List<dynamic>).cast<String>().toSet();
    expect(deletedBindingIds, equals(bindingIds));
  });
}

import 'dart:convert';

import 'package:erfasser_app/services/speicher_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadPendingSyncChanges groups all pending entries by EVNr', () async {
    const key1 = 'obj_E903_Testweg_1_DIV';
    const key2 = 'obj_E903_Testweg_2_ES';
    const key3 = 'obj_E904_Otherway_1_VG';

    await SpeicherService.upsertEntry(key1, {
      'typ': 'DIV',
      'evnr': 'E903',
      'strasse': 'Testweg',
      'posNr': '1',
    });

    await SpeicherService.upsertEntry(key2, {
      'typ': 'ES',
      'evnr': 'E903',
      'strasse': 'Testweg',
      'posNr': '2',
    });

    await SpeicherService.upsertEntry(key3, {
      'typ': 'VG',
      'evnr': 'E904',
      'strasse': 'Otherway',
      'posNr': '1',
    });

    final changes = await SpeicherService.loadPendingSyncChanges();

    expect(changes, hasLength(2));
    expect(changes['E903'], hasLength(2));
    expect(changes['E904'], hasLength(1));

    final e903 = changes['E903']!;
    expect(e903.every((m) => m['syncStatus'] == 'pending'), isTrue);

    final e904 = changes['E904']!;
    expect(e904.first['syncStatus'], 'pending');
  });

  test('loadPendingSyncChanges includes pending_delete tombstones', () async {
    const key1 = 'obj_E905_Testweg_1_DIV';
    const fotoA = 'data:image/jpeg;base64,AAA=';

    await SpeicherService.upsertEntry(key1, {
      'typ': 'DIV',
      'evnr': 'E905',
      'strasse': 'Testweg',
      'posNr': '1',
      'mediaFotos': [fotoA],
    });

    var entries = await SpeicherService.ladeEintraegeFuerEvNr('E905', strasse: 'Testweg');
    expect(entries, hasLength(1));

    await SpeicherService.deleteEntry(key1);

    final changes = await SpeicherService.loadPendingSyncChanges();
    expect(changes['E905'], hasLength(1));

    final tombstone = changes['E905']!.first;
    expect(tombstone['syncStatus'], 'pending_delete');
    expect(tombstone['storageKey'], key1);
    expect((tombstone['deletedMediaBindingIds'] as List).isNotEmpty, isTrue);
  });

  test('markSyncedAndCleanup marks items as synced and removes old tombstones', () async {
    const key1 = 'obj_E906_Testweg_1_DIV';

    await SpeicherService.upsertEntry(key1, {
      'typ': 'DIV',
      'evnr': 'E906',
      'strasse': 'Testweg',
      'posNr': '1',
    });

    var changes = await SpeicherService.loadPendingSyncChanges();
    expect(changes['E906'], hasLength(1));

    await SpeicherService.markSyncedAndCleanup(syncedKeys: [key1]);

    final prefs = await SharedPreferences.getInstance();
    final updatedJson = prefs.getString(key1);
    final updated = jsonDecode(updatedJson!) as Map<String, dynamic>;
    expect(updated['syncStatus'], 'synced');
    expect((updated['lastSyncedAt'] as String).isNotEmpty, isTrue);

    changes = await SpeicherService.loadPendingSyncChanges();
    expect(changes['E906'], isNull);
  });

  test('markSyncedAndCleanup removes old tombstones beyond retention', () async {
    const key1 = 'obj_E907_Testweg_1_DIV';

    await SpeicherService.upsertEntry(key1, {
      'typ': 'DIV',
      'evnr': 'E907',
      'strasse': 'Testweg',
      'posNr': '1',
    });

    var entries = await SpeicherService.ladeEintraegeFuerEvNr('E907', strasse: 'Testweg');
    expect(entries, hasLength(1));

    await SpeicherService.deleteEntry(key1);

    final prefs = await SharedPreferences.getInstance();
    var tombstoneJson = prefs.getString('deleted_obj_$key1');
    expect(tombstoneJson, isNotNull);

    var tombstone = jsonDecode(tombstoneJson!) as Map<String, dynamic>;
    expect(tombstone['syncStatus'], 'pending_delete');

    await SpeicherService.markSyncedAndCleanup(
      syncedKeys: ['deleted_obj_$key1'],
      retentionDays: 0,
    );

    tombstoneJson = prefs.getString('deleted_obj_$key1');
    expect(tombstoneJson, isNull);
  });
}

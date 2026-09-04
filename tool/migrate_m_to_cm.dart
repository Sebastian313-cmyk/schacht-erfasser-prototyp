import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:erfasser_app/services/speicher_service.dart';

// Simple migration utility: convert tiefe_m / wasser_m -> tiefe_cm / wasser_cm
// Usage (dry-run):
//   flutter run -t tool/migrate_m_to_cm.dart -d windows --release
// To apply changes (write backups + update SharedPreferences):
//   flutter run -t tool/migrate_m_to_cm.dart -d windows --release --dart-define=APPLY=true

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final applyEnv = Platform.environment['APPLY'] ?? '';
  final applyFlag = args.contains('--apply') || applyEnv.toLowerCase() == 'true';

  debugPrint('Migration: tiefe_m/wasser_m -> tiefe_cm/wasser_cm');
  debugPrint('Mode: ${applyFlag ? 'APPLY (will update SharedPreferences and write backups)' : 'DRY-RUN (no changes)'}');

  final evList = await SpeicherService.ladeAlleEvNr();
  if (evList.isEmpty) {
    debugPrint('Keine EVNr gefunden. Abbruch.');
    return;
  }

  final backupDir = Directory('tool/migration_backup');
  if (applyFlag) {
    if (!backupDir.existsSync()) backupDir.createSync(recursive: true);
  }

  int total = 0;
  int changed = 0;

  for (final ev in evList) {
    debugPrint('\nProcessing EVNr: $ev');
    final metas = await SpeicherService.ladeEintraegeFuerEvNr(ev);
    for (final meta in metas) {
      total++;
      final storageKey = meta['storageKey'] as String? ?? '<unknown>';
      bool modified = false;

      // tiefe
      final tiefeCmRaw = (meta['tiefe_cm'] as String?)?.trim();
      final tiefeMRaw = (meta['tiefe_m'] as String?)?.trim();
      if ((tiefeCmRaw == null || tiefeCmRaw.isEmpty) && tiefeMRaw != null && tiefeMRaw.isNotEmpty) {
        final mVal = num.tryParse(tiefeMRaw.replaceAll(',', '.'));
        if (mVal != null) {
          final cm = (mVal * 100).toStringAsFixed(mVal.truncateToDouble() == mVal ? 0 : 2);
          debugPrint(' - $storageKey: converting tiefe_m=$tiefeMRaw -> tiefe_cm=$cm');
          meta['tiefe_cm'] = cm;
          modified = true;
        }
      }

      // wasser
      final wasserCmRaw = (meta['wasser_cm'] as String?)?.trim();
      final wasserMRaw = (meta['wasser_m'] as String?)?.trim();
      if ((wasserCmRaw == null || wasserCmRaw.isEmpty) && wasserMRaw != null && wasserMRaw.isNotEmpty) {
        final mVal = num.tryParse(wasserMRaw.replaceAll(',', '.'));
        if (mVal != null) {
          final cm = (mVal * 100).toStringAsFixed(mVal.truncateToDouble() == mVal ? 0 : 2);
          debugPrint(' - $storageKey: converting wasser_m=$wasserMRaw -> wasser_cm=$cm');
          meta['wasser_cm'] = cm;
          modified = true;
        }
      }

      if (modified) {
        changed++;
        if (applyFlag) {
          // write backup
          final fileNameSafe = storageKey.replaceAll(RegExp(r'[\\/:]'), '_');
          final backupFile = File('${backupDir.path}/$fileNameSafe.json');
          backupFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(meta));

          // update shared prefs
          await SpeicherService.updateEntry(storageKey, meta);
        }
      }
    }
  }

  debugPrint('\nSummary: processed=$total, modified=$changed');
  if (!applyFlag) {
    debugPrint('Dry-run complete. Re-run with --apply or set env APPLY=true to persist changes.');
  } else {
    debugPrint('Applied changes and wrote backups to ${backupDir.path}');
  }
}

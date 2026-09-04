import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const MethodChannel _exportStorageChannel =
  MethodChannel('com.example.erfasser_app/export_storage');

Future<String?> saveExportToDevice({
  required Uint8List bytes,
  required String fileName,
  required String exportFolderName,
  bool inErfassungen = false,
}) async {
  if (!Platform.isAndroid) return null;

  final relativeDir = inErfassungen
      ? 'ErfasserApp/$exportFolderName/Erfassungen'
      : 'ErfasserApp/$exportFolderName';

  // Preferred path on Android 10+: MediaStore puts files in visible Downloads.
  // Use a temp file path to avoid Binder payload limits for large exports.
  try {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);

    final savedPath = await _exportStorageChannel.invokeMethod<String>(
      'saveToDownloadsFromPath',
      <String, dynamic>{
        'fileName': fileName,
        'relativeDir': relativeDir,
        'sourcePath': tempFile.path,
      },
    );

    try {
      await tempFile.delete();
    } catch (_) {}

    if (savedPath != null && savedPath.isNotEmpty) {
      return savedPath;
    }
  } catch (_) {
    // Fallback below handles older devices/configurations.
  }

  final candidateBases = <String>[
    '/storage/emulated/0/Download',
    '/sdcard/Download',
  ];

  for (final base in candidateBases) {
    final savedPath = await _tryWrite(base, relativeDir, fileName, bytes);
    if (savedPath != null) return savedPath;
  }

  // Scoped-Storage Fallback (app-spezifischer externer Speicher).
  try {
    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      final savedPath = await _tryWrite(externalDir.path, relativeDir, fileName, bytes);
      if (savedPath != null) return savedPath;
    }
  } catch (_) {
    // Intentionally ignored: caller handles null as "not saved on device".
  }

  return null;
}

Future<int> saveZipStructureToDevice(Uint8List zipBytes) async {
  if (!Platform.isAndroid) return 0;

  final archive = ZipDecoder().decodeBytes(zipBytes, verify: false);
  final tempDir = await getTemporaryDirectory();
  var savedFiles = 0;

  for (final entry in archive.files) {
    if (!entry.isFile) continue;

    final normalized = entry.name.replaceAll('\\', '/');
    if (normalized.trim().isEmpty) continue;

    final parts = normalized.split('/').where((p) => p.trim().isNotEmpty).toList();
    if (parts.isEmpty) continue;

    final fileName = parts.last;
    final relativeDir = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : 'ErfasserApp';

    try {
      final bytes = entry.content as List<int>;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes, flush: true);

      final savedPath = await _exportStorageChannel.invokeMethod<String>(
        'saveToDownloadsFromPath',
        <String, dynamic>{
          'fileName': fileName,
          'relativeDir': relativeDir,
          'sourcePath': tempFile.path,
        },
      );

      try {
        await tempFile.delete();
      } catch (_) {}

      if (savedPath != null && savedPath.isNotEmpty) {
        savedFiles++;
      }
    } catch (_) {
      // Skip invalid entry and continue with remaining files.
    }
  }

  return savedFiles;
}

Future<String?> _tryWrite(
  String basePath,
  String relativeDir,
  String fileName,
  Uint8List bytes,
) async {
  try {
    final targetDir = Directory('$basePath/$relativeDir');
    await targetDir.create(recursive: true);

    final file = File('${targetDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

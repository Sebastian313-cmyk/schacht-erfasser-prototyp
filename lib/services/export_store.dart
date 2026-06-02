import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class ExportFile {
  final String id;
  final String fileName;
  final String mimeType;
  final String bytesBase64;
  final String? evnr;
  final DateTime createdAt;

  ExportFile({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.bytesBase64,
    required this.createdAt,
    this.evnr,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'mimeType': mimeType,
        'bytesBase64': bytesBase64,
        'evnr': evnr,
        'createdAt': createdAt.toIso8601String(),
      };

  static ExportFile? fromJson(Map<String, dynamic> m) {
    try {
      final createdAtRaw = (m['createdAt'] as String?) ?? '';
      final createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
      final id = (m['id'] as String?)?.trim();
      final fileName = (m['fileName'] as String?)?.trim();
      final mimeType = (m['mimeType'] as String?)?.trim();
      final bytesBase64 = (m['bytesBase64'] as String?)?.trim();
      if (id == null || id.isEmpty) return null;
      if (fileName == null || fileName.isEmpty) return null;
      if (mimeType == null || mimeType.isEmpty) return null;
      if (bytesBase64 == null || bytesBase64.isEmpty) return null;
      return ExportFile(
        id: id,
        fileName: fileName,
        mimeType: mimeType,
        bytesBase64: bytesBase64,
        evnr: (m['evnr'] as String?)?.trim(),
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  Uint8List bytes() => base64Decode(bytesBase64);
}

class ExportStore {
  static const _key = 'export_files_v1';

  static Future<List<ExportFile>> loadExports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <ExportFile>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ExportFile>[];
      final list = <ExportFile>[];
      for (final item in decoded) {
        if (item is Map) {
          final file = ExportFile.fromJson(item.cast<String, dynamic>());
          if (file != null) list.add(file);
        }
      }
      return list;
    } catch (_) {
      return <ExportFile>[];
    }
  }

  static Future<void> saveExport({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? evnr,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadExports();
    final now = DateTime.now();
    final file = ExportFile(
      id: '${now.microsecondsSinceEpoch}_${fileName.hashCode}',
      fileName: fileName,
      mimeType: mimeType,
      bytesBase64: base64Encode(bytes),
      evnr: evnr,
      createdAt: now,
    );
    final updated = [file, ...existing];
    final toStore = updated.map((e) => e.toJson()).toList();
    await prefs.setString(_key, jsonEncode(toStore));
  }

  static Future<void> deleteExport(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadExports();
    final updated = list.where((e) => e.id != id).toList();
    final toStore = updated.map((e) => e.toJson()).toList();
    await prefs.setString(_key, jsonEncode(toStore));
  }
}

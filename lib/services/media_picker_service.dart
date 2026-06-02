import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class MediaPickResult {
  final List<String> fotos;
  final List<String> videos;
  final List<String> pdfs;
  const MediaPickResult({this.fotos = const [], this.videos = const [], this.pdfs = const []});
}

class MediaPickerService {
  static Future<MediaPickResult> pick({required BuildContext context, required bool image}) async {
    final source = await _askSource(context);
    if (source == null) return const MediaPickResult();

    if (source == _PickSource.folder) {
      return _pickFolder();
    } else if (source == _PickSource.device || kIsWeb) {
      return _pickViaFilePicker(image: image);
    } else {
      return _pickViaCamera(image: image);
    }
  }

  /// Medien auswählen (Fotos UND Videos automatisch erkannt)
  static Future<MediaPickResult> pickMedia({required BuildContext context}) async {
    final source = await _askSource(context, isPhotoVideo: true);
    if (source == null) return const MediaPickResult();

    if (source == _PickSource.device || kIsWeb) {
      return _pickMediaFiles();
    } else {
      return _pickViaCamera(image: true);  // Camera only takes photos
    }
  }

  /// Direkt Ordner auswählen ohne Dialog (für PDF/Kanalkamera-Dateien)
  static Future<MediaPickResult> pickFolder() async {
    return _pickFolder();
  }

  static Future<_PickSource?> _askSource(BuildContext context, {bool isPhotoVideo = false}) {
    return showDialog<_PickSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Medien hinzufügen'),
        content: const Text('Woher sollen die Medien kommen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Abbrechen'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(_PickSource.device),
            child: const Text('Gerät'),
          ),
          if (!isPhotoVideo)
            FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(_PickSource.folder),
              child: const Text('Ordner'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_PickSource.camera),
            child: const Text('Kamera'),
          ),
        ],
      ),
    );
  }

  static Future<MediaPickResult> _pickViaFilePicker({required bool image}) async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: image ? FileType.image : FileType.video,
      withData: true,
    );
    if (res == null) return const MediaPickResult();

    final fotos = <String>[];
    final videos = <String>[];

    for (final f in res.files) {
      if (f.bytes == null || f.name.isEmpty) continue;
      final ext = (f.extension ?? '').toLowerCase();
      final mime = image
          ? (ext == 'png'
              ? 'image/png'
              : (ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg'))
          : (ext == 'webm' ? 'video/webm' : 'video/mp4');
      final dataUrl = 'data:$mime;base64,${base64Encode(f.bytes!)}';
      if (image) {
        fotos.add(dataUrl);
      } else {
        videos.add(dataUrl);
      }
    }

    return MediaPickResult(fotos: fotos, videos: videos);
  }

  static Future<MediaPickResult> _pickMediaFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'webm', 'mov'],
      withData: true,
    );
    if (res == null) return const MediaPickResult();

    final fotos = <String>[];
    final videos = <String>[];

    for (final f in res.files) {
      if (f.bytes == null || f.name.isEmpty) continue;
      final ext = (f.extension ?? '').toLowerCase();
      
      if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        final dataUrl = 'data:$mime;base64,${base64Encode(f.bytes!)}';
        fotos.add(dataUrl);
      } else if (['mp4', 'webm', 'mov'].contains(ext)) {
        final mime = ext == 'webm' ? 'video/webm' : (ext == 'mov' ? 'video/quicktime' : 'video/mp4');
        final dataUrl = 'data:$mime;base64,${base64Encode(f.bytes!)}';
        videos.add(dataUrl);
      }
    }

    return MediaPickResult(fotos: fotos, videos: videos);
  }

  static Future<MediaPickResult> _pickViaCamera({required bool image}) async {
    final picker = ImagePicker();

    if (image) {
      final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x == null) return const MediaPickResult();
      final bytes = await x.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      return MediaPickResult(fotos: [dataUrl]);
    } else {
      final x = await picker.pickVideo(source: ImageSource.camera);
      if (x == null) return const MediaPickResult();
      final bytes = await x.readAsBytes();
      final dataUrl = 'data:video/mp4;base64,${base64Encode(bytes)}';
      return MediaPickResult(videos: [dataUrl]);
    }
  }

  static Future<MediaPickResult> _pickFolder() async {
    // Für Web: verwende pickFiles mit allowMultiple
    if (kIsWeb) {
      return _pickFolderWeb();
    }
    
    // Für Desktop/Mobile: versuche Verzeichnis auszuwählen
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null) return const MediaPickResult();
      
      // Importiere dart:io für Desktop
      // Dies würde auf Web nicht funktionieren, daher ist es im Web-Block oben
      return const MediaPickResult();
    } catch (e) {
      debugPrint('Error picking directory: $e');
      // Fallback zu Web-Variante
      return _pickFolderWeb();
    }
  }

  static Future<MediaPickResult> _pickFolderWeb() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'webm', 'mov', 'pdf'],
      withData: true,
    );
    if (res == null) return const MediaPickResult();

    final fotos = <String>[];
    final videos = <String>[];
    final pdfs = <String>[];

    for (final f in res.files) {
      if (f.bytes == null || f.name.isEmpty) continue;
      final ext = (f.extension ?? '').toLowerCase();
      
      if (ext == 'pdf') {
        final dataUrl = 'data:application/pdf;base64,${base64Encode(f.bytes!)}';
        pdfs.add(dataUrl);
      } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        final dataUrl = 'data:$mime;base64,${base64Encode(f.bytes!)}';
        fotos.add(dataUrl);
      } else if (['mp4', 'webm', 'mov'].contains(ext)) {
        final mime = ext == 'webm' ? 'video/webm' : (ext == 'mov' ? 'video/quicktime' : 'video/mp4');
        final dataUrl = 'data:$mime;base64,${base64Encode(f.bytes!)}';
        videos.add(dataUrl);
      }
    }

    return MediaPickResult(fotos: fotos, videos: videos, pdfs: pdfs);
  }
}

enum _PickSource { device, camera, folder }

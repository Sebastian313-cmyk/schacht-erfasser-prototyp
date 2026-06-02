import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'audio_service_web.dart' if (dart.library.io) 'audio_service_stub.dart';

/// Simplified audio recording service
/// Returns base64 encoded audio data
class AudioService {
  /// Pick or record an audio file
  /// Returns base64-encoded audio data or null if cancelled
  static Future<String?> pickOrRecordAudio() async {
    try {
      if (kIsWeb) {
        // Use web implementation with recording dialog
        return await AudioServiceWeb.showRecordDialog();
      }
      
      // TODO: Implement mobile audio recording with audio recording package
      debugPrint('[AudioService] Mobile audio recording not yet implemented');
      return null;
      
    } catch (e) {
      debugPrint('[AudioService] Error: $e');
      return null;
    }
  }

  /// Show dialog for Diktat (text input) or Aufnehmen (audio recording)
  /// Returns either text data (for Diktat) or audio data (for Aufnehmen)
  static Future<String?> showAudioOptions(BuildContext context) async {
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audio hinzufügen'),
        content: const Text('Wie möchtest du vorgehen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Abbrechen'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Show text input dialog for Diktat
              final text = await _showDiktatDialog(ctx);
              if (text != null && text.isNotEmpty) {
                // Return text as a marker to indicate it's dictation
                return;
              }
            },
            child: const Text('Diktat'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Record audio
              final audio = await pickOrRecordAudio();
              if (audio != null) {
                return;
              }
            },
            child: const Text('Aufnehmen'),
          ),
        ],
      ),
    );
  }

  /// Show text input dialog for dictation
  static Future<String?> _showDiktatDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diktat eingeben'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Geben Sie Ihren Text hier ein',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}

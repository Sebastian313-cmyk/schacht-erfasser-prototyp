import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  static final stt.SpeechToText _speechToText = stt.SpeechToText();
  static bool _isInitialized = false;

  /// Initialize speech to text (call once)
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      final available = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) => debugPrint('Speech status: $status'),
      );
      _isInitialized = available;
      return available;
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      return false;
    }
  }

  /// Start listening with callback for real-time updates
  static Future<void> startListening({
    required Function(String) onResult,
  }) async {
    if (!_isInitialized) {
      final init = await initialize();
      if (!init) return;
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
          debugPrint('Recognized: ${result.recognizedWords} (final: ${result.finalResult})');
        },
        localeId: 'de_DE',
        // ignore: deprecated_member_use
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('Error listening: $e');
    }
  }

  /// Stop listening
  static Future<void> stopListening() async {
    try {
      await _speechToText.stop();
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
  }

  /// Check if speech is currently listening
  static bool get isListening => _speechToText.isListening;

  /// Check if speech is available
  static bool get isAvailable => _isInitialized;
}

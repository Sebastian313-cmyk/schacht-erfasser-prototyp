import 'package:flutter/foundation.dart';

/// Stub for non-web platforms
class AudioServiceWeb {
  static Future<String?> showRecordDialog() async {
    debugPrint('[AudioServiceWeb] Stub called - not available on this platform');
    return null;
  }
}

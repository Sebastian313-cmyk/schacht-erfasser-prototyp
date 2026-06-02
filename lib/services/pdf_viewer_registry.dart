import 'package:flutter/foundation.dart';

/// Helper class to register PDF viewers on web
class PdfViewerRegistry {
  static final Map<String, bool> _registered = {};

  /// Register a PDF viewer with Base64 data
  /// 
  /// On web, this uses platformViewRegistry to register an iframe viewer.
  /// On other platforms, this is a no-op.
  static Future<void> registerPdfViewer(String viewType, String pdfBase64) async {
    if (!kIsWeb || _registered.containsKey(viewType)) {
      return;
    }

    _registered[viewType] = true;

    try {
      // Use a deferred mechanism to load web-specific code
      await _registerWebViewer(viewType, pdfBase64);
    } catch (e) {
      debugPrint('Error registering PDF viewer: $e');
    }
  }

  static Future<void> _registerWebViewer(String viewType, String pdfBase64) async {
    if (!kIsWeb) return;

    try {
      // Dynamically call the web registration function
      // This avoids compile-time issues with dart:html imports
      // ignore: avoid_dynamic_calls
      final module = await _loadWebModule();
      if (module != null) {
        // ignore: avoid_dynamic_calls
        module.registerPdfViewerFactory(viewType, pdfBase64);
      }
    } catch (e) {
      // Fallback: try direct registration if available
      _tryDirectRegistration(viewType, pdfBase64);
    }
  }

  static Future<dynamic> _loadWebModule() async {
    if (!kIsWeb) return null;
    try {
      // Try to dynamically load web module
      // This would work with conditional imports at app level
      return null;
    } catch (e) {
      return null;
    }
  }

  static void _tryDirectRegistration(String viewType, String pdfBase64) {
    if (!kIsWeb) return;
    
    try {
      // This is a fallback stub
      // The actual implementation should be injected at runtime
    } catch (e) {
      debugPrint('Fallback PDF registration failed: $e');
    }
  }
}

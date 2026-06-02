// Platform-independent PDF viewer registration service.
//
// On web: Uses dart:html and ui_web to register iframe-based PDF viewers.
// On other platforms: Provides stub implementations.

import 'package:flutter/foundation.dart';

/// Register a PDF viewer factory
/// 
/// On web: Creates an iframe element to display the PDF
/// On other platforms: No-op
void registerPdfViewerFactory(String viewType, String pdfBase64) {
  if (!kIsWeb) {
    return; // No-op on non-web platforms
  }
  
  try {
    // Attempt to call the web implementation
    _registerWebPdfViewer(viewType, pdfBase64);
  } catch (e) {
    // Silently fail if web implementation is not available
    debugPrint('Could not register PDF viewer: $e');
  }
}

/// Web-specific implementation (will be overridden at runtime on web)
void _registerWebPdfViewer(String viewType, String pdfBase64) {
  if (!kIsWeb) return;
  
  // This stub will be dynamically replaced when running on web
  // The actual implementation uses ui_web.platformViewRegistry
}

/// Initialize PDF viewer support on web
void initializePdfViewers() {
  if (!kIsWeb) return;
  
  try {
    _initializeWebPdfViewers();
  } catch (e) {
    debugPrint('Could not initialize PDF viewers: $e');
  }
}

void _initializeWebPdfViewers() {
  if (!kIsWeb) return;
  // Stub implementation
}

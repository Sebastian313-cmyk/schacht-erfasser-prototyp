// Web-only PDF viewer initialization
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

// Global set to track registered view factories
final Set<String> _registeredPdfViewTypes = <String>{};

// Initialize PDF viewer factories
void initializePdfViewers() {
  // Create a generic factory that creates iframes on demand
  ui_web.platformViewRegistry.registerViewFactory(
    'pdf-viewer-generic',
    (int viewId) => _createDefaultPdfViewer(),
  );
}

html.Element _createDefaultPdfViewer() {
  return html.DivElement()
    ..text = 'PDF'
    ..style.width = '100%'
    ..style.height = '100%';
}

// Register a specific PDF viewer with Base64 data
void registerPdfViewer(String viewType, String pdfBase64) {
  if (_registeredPdfViewTypes.contains(viewType)) return;
  
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => _createPdfViewer(pdfBase64),
  );
  _registeredPdfViewTypes.add(viewType);
}

html.IFrameElement _createPdfViewer(String pdfBase64) {
  final dataUrl = 'data:application/pdf;base64,$pdfBase64';
  return html.IFrameElement()
    ..src = dataUrl
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..setAttribute('allowfullscreen', 'true');
}

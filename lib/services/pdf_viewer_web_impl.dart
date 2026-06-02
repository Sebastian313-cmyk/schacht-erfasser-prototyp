// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Global registry to track which PDF viewers have been registered
final Set<String> _registeredPdfViewers = {};

/// Register a PDF viewer with the given viewType and Base64 data
void registerPdfViewerFactory(String viewType, String pdfBase64) {
  if (_registeredPdfViewers.contains(viewType)) {
    return;
  }

  _registeredPdfViewers.add(viewType);

  // Register the platform view factory
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => _createPdfViewerElement(pdfBase64),
  );
}

/// Create an HTML element for displaying the PDF
html.Element _createPdfViewerElement(String pdfBase64) {
  final dataUrl = 'data:application/pdf;base64,$pdfBase64';
  final iframe = html.IFrameElement()
    ..src = dataUrl
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..setAttribute('allowfullscreen', 'true');
  return iframe;
}

/// Initialize PDF viewer support (call this on app startup)
void initializePdfViewerSupport() {
  // Register a generic factory for fallback
  if (!_registeredPdfViewers.contains('pdf-viewer-generic')) {
    ui_web.platformViewRegistry.registerViewFactory(
      'pdf-viewer-generic',
      (int viewId) {
        return html.DivElement()
          ..text = 'PDF Viewer'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center';
      },
    );
    _registeredPdfViewers.add('pdf-viewer-generic');
  }
}

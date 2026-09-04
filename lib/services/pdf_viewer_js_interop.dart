// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Register PDF viewer factory via JavaScript
/// Register a PDF viewer on web platform
void registerPdfViewerFactoryWeb(String viewType, String pdfBase64) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => _createPdfFrame(pdfBase64),
  );
}

/// Create an iframe element for PDF display
html.IFrameElement _createPdfFrame(String pdfBase64) {
  final dataUrl = 'data:application/pdf;base64,$pdfBase64';
  final iframe = html.IFrameElement()
    ..src = dataUrl
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..setAttribute('allowfullscreen', 'true');
  return iframe;
}

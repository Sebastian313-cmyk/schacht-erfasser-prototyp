// ignore_for_file: avoid_web_libraries_in_flutter
// ignore: deprecated_member_use
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

Widget buildNisPdfViewer(String pdfBase64, {bool allowInteraction = true}) {
  if (!kIsWeb) {
    return const Center(child: Text('PDF-Viewer nur im Web verfügbar'));
  }
  return _HtmlPdfViewer(pdfBase64: pdfBase64, allowInteraction: allowInteraction);
}

class _HtmlPdfViewer extends StatefulWidget {
  final String pdfBase64;
  final bool allowInteraction;
  const _HtmlPdfViewer({required this.pdfBase64, required this.allowInteraction});

  @override
  State<_HtmlPdfViewer> createState() => _HtmlPdfViewerState();
}

class _HtmlPdfViewerState extends State<_HtmlPdfViewer> {
  @override
  Widget build(BuildContext context) {
    try {
      final normalized = widget.pdfBase64.contains(',')
          ? widget.pdfBase64.split(',').last
          : widget.pdfBase64;
      final bytes = base64Decode(normalized);
      return SfPdfViewer.memory(
        bytes,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Fehler beim Laden des PDF: $e'),
          ],
        ),
      );
    }
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

Widget buildNisPdfViewer(String pdfBase64, {bool allowInteraction = true}) {
  return _MobilePdfViewer(pdfBase64: pdfBase64);
}

class _MobilePdfViewer extends StatelessWidget {
  final String pdfBase64;

  const _MobilePdfViewer({required this.pdfBase64});

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(pdfBase64);
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

// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Widget buildNisPdfViewer(String pdfBase64, {bool allowInteraction = true}) {
  if (!kIsWeb) {
    return const Center(child: Text('PDF-Viewer nur im Web verfuegbar'));
  }
  return _HtmlPdfViewer(
    pdfBase64: pdfBase64,
    allowInteraction: allowInteraction,
  );
}

class _HtmlPdfViewer extends StatefulWidget {
  final String pdfBase64;
  final bool allowInteraction;

  const _HtmlPdfViewer({
    required this.pdfBase64,
    required this.allowInteraction,
  });

  @override
  State<_HtmlPdfViewer> createState() => _HtmlPdfViewerState();
}

class _HtmlPdfViewerState extends State<_HtmlPdfViewer> {
  static final Set<String> _registeredViewTypes = <String>{};

  String? _viewType;
  String? _error;

  @override
  void initState() {
    super.initState();
    _configureViewer();
  }

  @override
  void didUpdateWidget(covariant _HtmlPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfBase64 != widget.pdfBase64 ||
        oldWidget.allowInteraction != widget.allowInteraction) {
      _configureViewer();
    }
  }

  void _configureViewer() {
    try {
      final normalized = _normalizeBase64(widget.pdfBase64);
      final bytes = base64Decode(normalized);
      final interactionKey = widget.allowInteraction ? 'interactive' : 'draw';
      final viewType =
          'nis-pdf-${normalized.length}-${normalized.hashCode}-$interactionKey';

      if (!_registeredViewTypes.contains(viewType)) {
        _registeredViewTypes.add(viewType);
        ui_web.platformViewRegistry.registerViewFactory(
          viewType,
          (int viewId) => _createPdfFrame(bytes, widget.allowInteraction),
        );
      }

      setState(() {
        _viewType = viewType;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _viewType = null;
        _error = error.toString();
      });
    }
  }

  String _normalizeBase64(String value) {
    final trimmed = value.trim();
    return trimmed.contains(',') ? trimmed.split(',').last.trim() : trimmed;
  }

  html.Element _createPdfFrame(Uint8List bytes, bool allowInteraction) {
    final blob = html.Blob(<Object>[bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final iframe = html.IFrameElement()
      ..src = '$url#toolbar=1&navpanes=0&view=FitH'
      ..title = 'NIS-Plan'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#ffffff'
      ..style.pointerEvents = allowInteraction ? 'auto' : 'none'
      ..setAttribute('allowfullscreen', 'true');
    return iframe;
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _viewType;
    if (_error != null) {
      return _PdfError(message: 'NIS-PDF konnte nicht geladen werden: $_error');
    }
    if (viewType == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return HtmlElementView(viewType: viewType);
  }
}

class _PdfError extends StatelessWidget {
  final String message;

  const _PdfError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

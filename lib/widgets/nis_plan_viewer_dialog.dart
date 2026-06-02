import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../services/session_store.dart';

import 'nis_plan_viewer_mobile.dart'
  if (dart.library.html) 'nis_plan_viewer_web.dart';

class NisPlanViewerDialog extends StatefulWidget {
  final String pdfBase64;
  final String fileName;
  final String? evnr;
  final List<List<List<double>>>? initialDrawings;
  final List<Map<String, dynamic>>? initialRoutes;
  final List<Map<String, dynamic>>? initialStamps;

  const NisPlanViewerDialog({
    required this.pdfBase64,
    required this.fileName,
    this.evnr,
    this.initialDrawings,
    this.initialRoutes,
    this.initialStamps,
    super.key,
  });

  @override
  State<NisPlanViewerDialog> createState() => _NisPlanViewerDialogState();
}

class _NisPlanViewerDialogState extends State<NisPlanViewerDialog> {
  _NisTool _tool = _NisTool.none;
  List<List<Offset>> _strokesNorm = <List<Offset>>[];
  List<_RouteLine> _routes = <_RouteLine>[];
  List<_NisStamp> _stamps = <_NisStamp>[];
  List<Offset>? _currentStroke;
  _RouteLine? _currentRoute;
  final _RouteColor _routeColor = _RouteColor.green;
  Size _canvasSize = Size.zero;
  final TextEditingController _posTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _strokesNorm = _decodeDrawings(widget.initialDrawings);
    _routes = _decodeRoutes(widget.initialRoutes);
    _stamps = _decodeStamps(widget.initialStamps);
  }

  @override
  void dispose() {
    _posTextCtrl.dispose();
    super.dispose();
  }

  List<List<Offset>> _decodeDrawings(List<List<List<double>>>? raw) {
    if (raw == null) return <List<Offset>>[];
    final result = <List<Offset>>[];
    for (final stroke in raw) {
      final points = <Offset>[];
      for (final p in stroke) {
        if (p.length >= 2) {
          points.add(Offset(p[0], p[1]));
        }
      }
      if (points.isNotEmpty) result.add(points);
    }
    return result;
  }

  List<_RouteLine> _decodeRoutes(List<Map<String, dynamic>>? raw) {
    if (raw == null) return <_RouteLine>[];
    final result = <_RouteLine>[];
    for (final item in raw) {
      final colorStr = (item['color'] ?? '').toString();
      final pointsRaw = item['points'];
      if (pointsRaw is! List) continue;
      final points = <Offset>[];
      for (final p in pointsRaw) {
        if (p is List && p.length >= 2) {
          final dx = (p[0] is num) ? (p[0] as num).toDouble() : null;
          final dy = (p[1] is num) ? (p[1] as num).toDouble() : null;
          if (dx != null && dy != null) points.add(Offset(dx, dy));
        }
      }
      if (points.isEmpty) continue;
      final color = _parseRouteColor(colorStr) ?? _RouteColor.green;
      result.add(_RouteLine(color: color, points: points));
    }
    return result;
  }

  List<_NisStamp> _decodeStamps(List<Map<String, dynamic>>? raw) {
    if (raw == null) return <_NisStamp>[];
    final result = <_NisStamp>[];
    for (final item in raw) {
      final typeStr = (item['type'] ?? '').toString();
      final x = item['x'];
      final y = item['y'];
      if (x is! num || y is! num) continue;
      final type = _parseStampType(typeStr);
      if (type == null) continue;
      result.add(_NisStamp(
        type: type,
        pos: Offset(x.toDouble(), y.toDouble()),
        text: item['text']?.toString(),
      ));
    }
    return result;
  }

  List<List<List<double>>> _encodeDrawings() {
    return _strokesNorm
        .map((stroke) => stroke.map((p) => [p.dx, p.dy]).toList())
        .toList();
  }

  List<Map<String, dynamic>> _encodeRoutes() {
    return _routes
        .map((r) => {
              'color': r.color.name,
              'points': r.points.map((p) => [p.dx, p.dy]).toList(),
            })
        .toList();
  }

  List<Map<String, dynamic>> _encodeStamps() {
    return _stamps
        .map((s) => {
              'type': s.type.name,
              'x': s.pos.dx,
              'y': s.pos.dy,
              if (s.text != null && s.text!.isNotEmpty) 'text': s.text,
            })
        .toList();
  }

  bool get _canSave => (widget.evnr ?? '').trim().isNotEmpty;

  Offset _normalize(Offset p) {
    if (_canvasSize.width <= 0 || _canvasSize.height <= 0) return const Offset(0, 0);
    return Offset(
      (p.dx / _canvasSize.width).clamp(0.0, 1.0),
      (p.dy / _canvasSize.height).clamp(0.0, 1.0),
    );
  }

  void _startStroke(Offset localPosition) {
    final n = _normalize(localPosition);
    setState(() {
      if (_tool == _NisTool.pen) {
        _currentStroke = <Offset>[n];
        _strokesNorm = List<List<Offset>>.from(_strokesNorm)..add(_currentStroke!);
      } else if (_tool == _NisTool.route) {
        _currentRoute = _RouteLine(color: _routeColor, points: <Offset>[n]);
        _routes = List<_RouteLine>.from(_routes)..add(_currentRoute!);
      }
    });
  }

  void _extendStroke(Offset localPosition) {
    final n = _normalize(localPosition);
    setState(() {
      if (_tool == _NisTool.pen) {
        _currentStroke?.add(n);
      } else if (_tool == _NisTool.route) {
        _currentRoute?.points.add(n);
      }
    });
  }

  void _endStroke() {
    setState(() {
      _currentStroke = null;
      _currentRoute = null;
    });
  }

  void _placeStamp(Offset localPosition) {
    final n = _normalize(localPosition);
    final type = _tool.toStampType;
    if (type == null) return;
    final text = type == _NisStampType.posNumber ? _posTextCtrl.text.trim() : null;
    setState(() => _stamps = List<_NisStamp>.from(_stamps)..add(_NisStamp(type: type, pos: n, text: text)));
  }

  Future<void> _saveDrawings() async {
    if (!_canSave) return;
    await SessionStore.saveNisPlanForEvnr(
      widget.evnr!.trim(),
      widget.pdfBase64,
      fileName: widget.fileName,
      drawings: _encodeDrawings(),
      routes: _encodeRoutes(),
      stamps: _encodeStamps(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('NIS-Zeichnung gespeichert.')),
    );
  }

  Future<void> _openNisInNewTab() async {
    final normalized = widget.pdfBase64.contains(',')
        ? widget.pdfBase64.split(',').last
        : widget.pdfBase64;

    // Validate base64 once; avoids opening broken data URLs.
    try {
      base64Decode(normalized);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NIS-PDF ist ungültig und konnte nicht geöffnet werden.')),
      );
      return;
    }

    final uri = Uri.parse('data:application/pdf;base64,$normalized');
    var opened = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );

    if (!opened) {
      opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NIS-PDF konnte nicht im Browser geöffnet werden.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header mit Titel und Close-Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'NIS-Plan: ${widget.fileName}',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (kIsWeb)
                  IconButton(
                    tooltip: 'NIS-PDF im neuen Tab öffnen',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: _openNisInNewTab,
                  ),
                _ToolButton(
                  tooltip: 'Stift',
                  icon: Icons.edit_outlined,
                  selected: _tool == _NisTool.pen,
                  onPressed: () => setState(() => _tool = _NisTool.pen),
                ),
                _ToolButton(
                  tooltip: 'Leitungsverlauf (gestrichelt, gruen)',
                  icon: Icons.timeline,
                  selected: _tool == _NisTool.route,
                  onPressed: () => setState(() => _tool = _NisTool.route),
                ),
                _ToolButton(
                  tooltip: 'ES (Kreis mit X)',
                  icon: Icons.do_not_disturb_on,
                  selected: _tool == _NisTool.stampCircleX,
                  onPressed: () => setState(() => _tool = _NisTool.stampCircleX),
                ),
                _ToolButton(
                  tooltip: 'Lueftung (X mit Pfeil)',
                  icon: Icons.arrow_outward,
                  selected: _tool == _NisTool.stampArrow,
                  onPressed: () => setState(() => _tool = _NisTool.stampArrow),
                ),
                _ToolButton(
                  tooltip: 'Schieber (Bowtie)',
                  icon: Icons.sync_alt,
                  selected: _tool == _NisTool.stampBowtie,
                  onPressed: () => setState(() => _tool = _NisTool.stampBowtie),
                ),
                _ToolButton(
                  tooltip: 'SSK (Rechteck)',
                  icon: Icons.crop_16_9,
                  selected: _tool == _NisTool.stampBox,
                  onPressed: () => setState(() => _tool = _NisTool.stampBox),
                ),
                _ToolButton(
                  tooltip: 'Leitungsverlauf unbekannt (3 Striche)',
                  icon: Icons.more_horiz,
                  selected: _tool == _NisTool.stampUnknownLine,
                  onPressed: () => setState(() => _tool = _NisTool.stampUnknownLine),
                ),
                _ToolButton(
                  tooltip: 'Positionsnummer (rot)',
                  icon: Icons.pin,
                  selected: _tool == _NisTool.stampPosNumber,
                  onPressed: () => setState(() => _tool = _NisTool.stampPosNumber),
                ),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _posTextCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pos',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Letzte Linie löschen',
                  icon: const Icon(Icons.undo),
                  onPressed: (_strokesNorm.isEmpty && _routes.isEmpty && _stamps.isEmpty)
                      ? null
                      : () => setState(() {
                            if (_tool == _NisTool.route && _routes.isNotEmpty) {
                              _routes = List<_RouteLine>.from(_routes)..removeLast();
                            } else if (_tool == _NisTool.pen && _strokesNorm.isNotEmpty) {
                              _strokesNorm = List<List<Offset>>.from(_strokesNorm)..removeLast();
                            } else if (_stamps.isNotEmpty) {
                              _stamps = List<_NisStamp>.from(_stamps)..removeLast();
                            }
                          }),
                ),
                IconButton(
                  tooltip: 'Alle Zeichnungen löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: (_strokesNorm.isEmpty && _routes.isEmpty && _stamps.isEmpty)
                      ? null
                      : () => setState(() {
                            _strokesNorm = <List<Offset>>[];
                            _routes = <_RouteLine>[];
                            _stamps = <_NisStamp>[];
                          }),
                ),
                IconButton(
                  tooltip: _canSave ? 'Zeichnung speichern' : 'Speichern nur mit EVNr möglich',
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _canSave ? _saveDrawings : null,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // PDF Viewer
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = constraints.biggest;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: buildNisPdfViewer(
                        widget.pdfBase64,
                        allowInteraction: _tool == _NisTool.none,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: _tool == _NisTool.none,
                        child: GestureDetector(
                          onTapDown: (d) => _placeStamp(d.localPosition),
                          onPanStart: (d) => _startStroke(d.localPosition),
                          onPanUpdate: (d) => _extendStroke(d.localPosition),
                          onPanEnd: (_) => _endStroke(),
                          child: CustomPaint(
                            painter: _NisDrawingPainter(
                              strokesNorm: _strokesNorm,
                              routes: _routes,
                              stamps: _stamps,
                              color: Colors.redAccent,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NisDrawingPainter extends CustomPainter {
  final List<List<Offset>> strokesNorm;
  final List<_RouteLine> routes;
  final List<_NisStamp> stamps;
  final Color color;
  final double strokeWidth;

  _NisDrawingPainter({
    required this.strokesNorm,
    required this.routes,
    required this.stamps,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokesNorm) {
      if (stroke.length < 2) continue;
      final path = Path();
      final first = stroke.first;
      path.moveTo(first.dx * size.width, first.dy * size.height);
      for (var i = 1; i < stroke.length; i++) {
        final p = stroke[i];
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }

    for (final route in routes) {
      if (route.points.length < 2) continue;
      final routePaint = Paint()
        ..color = const Color(0xFF2E7D32)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final first = route.points.first;
      path.moveTo(first.dx * size.width, first.dy * size.height);
      for (var i = 1; i < route.points.length; i++) {
        final p = route.points[i];
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      _drawDashedPath(canvas, path, routePaint, dashLength: 10, gapLength: 8);
    }

    final stampPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final redPaint = Paint()
      ..color = const Color(0xFFC62828)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final stamp in stamps) {
      final center = Offset(stamp.pos.dx * size.width, stamp.pos.dy * size.height);
      final s = (size.shortestSide * 0.03).clamp(12.0, 22.0);
      _drawStamp(canvas, stamp, center, s, stampPaint, redPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NisDrawingPainter oldDelegate) {
    return oldDelegate.strokesNorm != strokesNorm ||
        oldDelegate.routes != routes ||
        oldDelegate.stamps != stamps ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

enum _NisTool { none, pen, route, stampCircleX, stampArrow, stampBowtie, stampBox, stampUnknownLine, stampPosNumber }

extension on _NisTool {
  _NisStampType? get toStampType {
    switch (this) {
      case _NisTool.stampCircleX:
        return _NisStampType.circleX;
      case _NisTool.stampArrow:
        return _NisStampType.arrow;
      case _NisTool.stampBowtie:
        return _NisStampType.bowtie;
      case _NisTool.stampBox:
        return _NisStampType.box;
      case _NisTool.stampUnknownLine:
        return _NisStampType.unknownLine;
      case _NisTool.stampPosNumber:
        return _NisStampType.posNumber;
      default:
        return null;
    }
  }
}

enum _RouteColor { green, red, blue }

extension on _RouteColor {
  String get name => toString().split('.').last;

}

enum _NisStampType { circleX, arrow, bowtie, box, unknownLine, posNumber }

extension on _NisStampType {
  String get name => toString().split('.').last;
}

_RouteColor? _parseRouteColor(String v) {
  switch (v) {
    case 'green':
      return _RouteColor.green;
    case 'red':
      return _RouteColor.red;
    case 'blue':
      return _RouteColor.blue;
  }
  return null;
}

_NisStampType? _parseStampType(String v) {
  switch (v) {
    case 'circleX':
      return _NisStampType.circleX;
    case 'arrow':
      return _NisStampType.arrow;
    case 'bowtie':
      return _NisStampType.bowtie;
    case 'box':
      return _NisStampType.box;
    case 'unknownLine':
      return _NisStampType.unknownLine;
    case 'posNumber':
      return _NisStampType.posNumber;
  }
  return null;
}

class _RouteLine {
  final _RouteColor color;
  final List<Offset> points;
  _RouteLine({required this.color, required this.points});
}

class _NisStamp {
  final _NisStampType type;
  final Offset pos;
  final String? text;
  _NisStamp({required this.type, required this.pos, this.text});
}

void _drawStamp(Canvas canvas, _NisStamp stamp, Offset c, double s, Paint paint, Paint redPaint) {
  switch (stamp.type) {
    case _NisStampType.circleX:
      canvas.drawCircle(c, s, paint);
      canvas.drawLine(c + Offset(-s * 0.6, -s * 0.6), c + Offset(s * 0.6, s * 0.6), paint);
      canvas.drawLine(c + Offset(-s * 0.6, s * 0.6), c + Offset(s * 0.6, -s * 0.6), paint);
      canvas.drawCircle(c, s * 1.25, redPaint);
      break;
    case _NisStampType.arrow:
      // X in the center
      canvas.drawLine(c + Offset(-s * 0.35, -s * 0.35), c + Offset(s * 0.35, s * 0.35), paint);
      canvas.drawLine(c + Offset(-s * 0.35, s * 0.35), c + Offset(s * 0.35, -s * 0.35), paint);
      // Up arrow above the X
      final shaftTop = c.dy - s * 0.95;
      final shaftBottom = c.dy - s * 0.2;
      canvas.drawLine(Offset(c.dx, shaftBottom), Offset(c.dx, shaftTop), paint);
      final head = Path()
        ..moveTo(c.dx, shaftTop)
        ..lineTo(c.dx - s * 0.35, shaftTop + s * 0.35)
        ..lineTo(c.dx + s * 0.35, shaftTop + s * 0.35)
        ..close();
      final headPaint = Paint()..color = paint.color..style = PaintingStyle.fill;
      canvas.drawPath(head, headPaint);
      canvas.drawCircle(c, s * 1.25, redPaint);
      break;
    case _NisStampType.bowtie:
      final left = Path()
        ..moveTo(c.dx - s, c.dy)
        ..lineTo(c.dx - s * 0.1, c.dy - s * 0.7)
        ..lineTo(c.dx - s * 0.1, c.dy + s * 0.7)
        ..close();
      final right = Path()
        ..moveTo(c.dx + s, c.dy)
        ..lineTo(c.dx + s * 0.1, c.dy - s * 0.7)
        ..lineTo(c.dx + s * 0.1, c.dy + s * 0.7)
        ..close();
      final fill = Paint()..color = paint.color..style = PaintingStyle.fill;
      canvas.drawPath(left, fill);
      canvas.drawPath(right, fill);
      canvas.drawCircle(c, s * 1.25, redPaint);
      break;
    case _NisStampType.box:
      final rect = Rect.fromCenter(center: c, width: s * 2.2, height: s * 1.2);
      canvas.drawRect(rect, paint);
      canvas.drawLine(Offset(rect.left + rect.width / 3, rect.top), Offset(rect.left + rect.width / 3, rect.bottom), paint);
      canvas.drawLine(Offset(rect.left + rect.width * 2 / 3, rect.top), Offset(rect.left + rect.width * 2 / 3, rect.bottom), paint);
      canvas.drawCircle(c, s * 1.25, redPaint);
      break;
    case _NisStampType.unknownLine:
      final y = c.dy;
      final dash = s * 0.35;
      final gap = s * 0.25;
      canvas.drawLine(Offset(c.dx - dash - gap * 1.5, y), Offset(c.dx - gap * 1.5, y), paint);
      canvas.drawLine(Offset(c.dx - dash / 2, y), Offset(c.dx + dash / 2, y), paint);
      canvas.drawLine(Offset(c.dx + gap * 1.5, y), Offset(c.dx + dash + gap * 1.5, y), paint);
      canvas.drawCircle(c, s * 1.25, redPaint);
      break;
    case _NisStampType.posNumber:
      final label = (stamp.text == null || stamp.text!.isEmpty) ? '?' : stamp.text!;
      final textStyle = TextStyle(
        color: const Color(0xFFC62828),
        fontSize: s * 1.2,
        fontWeight: FontWeight.bold,
      );
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      break;
  }
}

void _drawDashedPath(Canvas canvas, Path path, Paint paint, {required double dashLength, required double gapLength}) {
  for (final metric in path.computeMetrics()) {
    double distance = 0;
    while (distance < metric.length) {
      final next = distance + dashLength;
      final extract = metric.extractPath(distance, next.clamp(0, metric.length));
      canvas.drawPath(extract, paint);
      distance = next + gapLength;
    }
  }
}

class _ToolButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : null),
      onPressed: onPressed,
    );
  }
}





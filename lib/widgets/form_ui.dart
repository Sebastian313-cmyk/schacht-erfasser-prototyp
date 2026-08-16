import 'package:flutter/material.dart';

import '../services/gps_service.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;

  const SectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 8),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: style ?? const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;

  const FieldLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 6),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: style ?? const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class KvRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;
  final EdgeInsetsGeometry padding;

  const KvRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 120,
    this.padding = const EdgeInsets.symmetric(vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    var display = label.trim();
    if (display.isNotEmpty && !display.endsWith(':')) {
      display = '$display:';
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              display,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String formatTemperatureValue(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty || value == '—') return '—';
  if (value.contains('°')) return value;
  return '$value °C';
}

class ObjectGpsPanel extends StatefulWidget {
  final Map<String, dynamic>? initialMeta;
  final bool captureEnabled;

  const ObjectGpsPanel({
    super.key,
    this.initialMeta,
    this.captureEnabled = false,
  });

  @override
  State<ObjectGpsPanel> createState() => _ObjectGpsPanelState();
}

class _ObjectGpsPanelState extends State<ObjectGpsPanel> {
  Future<Map<String, dynamic>?>? _gpsFuture;
  static const double _warningAccuracyMeters = GpsService.targetAccuracyMeters;

  @override
  void initState() {
    super.initState();
    if (widget.captureEnabled) {
      _gpsFuture = GpsService.getCurrentLocation();
    }
  }

  @override
  void didUpdateWidget(covariant ObjectGpsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.captureEnabled && widget.captureEnabled) {
      _gpsFuture = GpsService.getCurrentLocation();
    } else if (oldWidget.captureEnabled && !widget.captureEnabled) {
      _gpsFuture = null;
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  num? _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  Map<String, dynamic>? _normalizeGps(Map<String, dynamic>? source) {
    if (source == null) return null;

    final rawGps = source['gps'];
    if (rawGps is Map) {
      final gpsMap = Map<String, dynamic>.from(rawGps);
      final lat = _toDouble(
        gpsMap['lat'] ?? gpsMap['latitude'] ?? gpsMap['gpsLat'],
      );
      final lon = _toDouble(gpsMap['lon'] ?? gpsMap['lng'] ?? gpsMap['gpsLon']);
      if (lat == null || lon == null) return null;

      return <String, dynamic>{
        'lat': lat,
        'lon': lon,
        if (_toNum(
              gpsMap['accuracy_m'] ?? gpsMap['acc'] ?? gpsMap['accuracy'],
            ) !=
            null)
          'accuracy_m': _toNum(
            gpsMap['accuracy_m'] ?? gpsMap['acc'] ?? gpsMap['accuracy'],
          ),
      };
    }

    final lat = _toDouble(source['gpsLat'] ?? source['lat']);
    final lon = _toDouble(source['gpsLon'] ?? source['lon']);
    if (lat == null || lon == null) return null;

    return <String, dynamic>{
      'lat': lat,
      'lon': lon,
      if (_toNum(source['gpsAcc']) != null)
        'accuracy_m': _toNum(source['gpsAcc']),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _gpsFuture,
      builder: (context, snapshot) {
        final gps = snapshot.data ?? _normalizeGps(widget.initialMeta);
        final lat = _toDouble(gps?['lat']);
        final lon = _toDouble(gps?['lon']);
        final acc = _toNum(gps?['accuracy_m']);
        final hasCoords = lat != null && lon != null;
        final hasAccuracyWarning = acc != null && acc > _warningAccuracyMeters;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'GPS-Daten',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!widget.captureEnabled && !hasCoords)
                  Text(
                    'GPS wird nur ermittelt, wenn "Nicht im NIS" ausgewählt ist.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else if (snapshot.connectionState == ConnectionState.waiting &&
                    !hasCoords)
                  const Text('GPS wird ermittelt...')
                else if (hasCoords) ...[
                  KvRow(label: 'Breitengrad', value: lat.toStringAsFixed(6)),
                  KvRow(label: 'Längengrad', value: lon.toStringAsFixed(6)),
                  if (acc != null)
                    KvRow(
                      label: 'Genauigkeit',
                      value: '${acc.toString()} m (Ziel: max. 5 m)',
                    ),
                  if (hasAccuracyWarning)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Achtung: Die aktuelle GPS-Genauigkeit liegt noch über 5 m. Die App wartet beim Speichern länger auf einen genaueren Fix und speichert sonst den besten verfügbaren Wert.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    widget.captureEnabled
                        ? 'Wird beim Speichern automatisch am Objekt hinterlegt. Je kleiner der Wert, desto genauer die Position.'
                        : 'Gespeicherte GPS-Daten. Neu ermittelt wird nur bei "Nicht im NIS".',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else
                  Text(
                    widget.captureEnabled
                        ? 'Keine GPS-Daten verfügbar. Beim Speichern wird erneut versucht, die Position zu ermitteln.'
                        : 'Keine GPS-Daten nötig. GPS wird nur bei "Nicht im NIS" abgefragt.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

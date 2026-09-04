import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GpsService {
  static const double targetAccuracyMeters = 5;
  static const Duration _initialFixTimeout = Duration(seconds: 15);
  static const Duration _refineTimeout = Duration(seconds: 30);

  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      var best = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: _initialFixTimeout,
        ),
      );

      if (_isTargetAccuracy(best)) {
        return _toGpsMap(best);
      }

      final collected = <Position>[best];
      StreamSubscription<Position>? sub;
      final targetReached = Completer<void>();
      try {
        sub =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 0,
              ),
            ).listen((pos) {
              collected.add(pos);
              best = _bestPosition(collected);
              if (_isTargetAccuracy(best) && !targetReached.isCompleted) {
                targetReached.complete();
              }
            });

        await targetReached.future.timeout(_refineTimeout, onTimeout: () {});
      } finally {
        await sub?.cancel();
      }

      return _toGpsMap(best);
    } catch (_) {
      return null;
    }
  }

  static bool _isTargetAccuracy(Position pos) {
    return pos.accuracy <= targetAccuracyMeters;
  }

  static Position _bestPosition(List<Position> positions) {
    return positions.reduce((currentBest, candidate) {
      if (candidate.accuracy < currentBest.accuracy) return candidate;
      if (candidate.accuracy == currentBest.accuracy &&
          candidate.timestamp.isAfter(currentBest.timestamp)) {
        return candidate;
      }
      return currentBest;
    });
  }

  static Map<String, dynamic> _toGpsMap(Position pos) {
    return {
      'lat': pos.latitude,
      'lon': pos.longitude,
      'accuracy_m': pos.accuracy.round(),
      'target_accuracy_m': targetAccuracyMeters.round(),
      'target_reached': _isTargetAccuracy(pos),
      'ts': DateTime.now().toIso8601String(),
    };
  }

  static Future<String?> getCurrentStreet() async {
    final gps = await getCurrentLocation();
    if (gps == null) return null;

    final lat = (gps['lat'] as num?)?.toDouble();
    final lon = (gps['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=jsonv2&addressdetails=1',
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ErfasserApp/1.0',
        },
      );
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final address = decoded['address'];
      if (address is! Map<String, dynamic>) return null;

      final road = (address['road'] ?? '').toString().trim();
      if (road.isNotEmpty) return road;

      final pedestrian = (address['pedestrian'] ?? '').toString().trim();
      if (pedestrian.isNotEmpty) return pedestrian;

      final suburb = (address['suburb'] ?? '').toString().trim();
      if (suburb.isNotEmpty) return suburb;

      return null;
    } catch (_) {
      return null;
    }
  }
}

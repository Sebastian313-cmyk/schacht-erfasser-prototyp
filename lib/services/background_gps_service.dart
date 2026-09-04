import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gps_service.dart';

/// In-process Background GPS service.
///
/// This subscribes to the Geolocator position stream and writes the
/// last known position into SharedPreferences under `gps_last`.
/// It is reliable while the app process runs (including when the app is
/// backgrounded), but will stop if the OS terminates the process.
class BackgroundGpsService {
  static StreamSubscription<Position>? _sub;

  /// Start listening to position updates. Call once on app/session start.
  static Future<void> start() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      // Avoid double-subscription
      if (_sub != null) return;

      final settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );

      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final data = {
              'lat': pos.latitude,
              'lon': pos.longitude,
              'accuracy_m': pos.accuracy.round(),
              'target_accuracy_m': GpsService.targetAccuracyMeters.round(),
              'target_reached': pos.accuracy <= GpsService.targetAccuracyMeters,
              'ts': DateTime.now().toIso8601String(),
            };
            await prefs.setString('gps_last', jsonEncode(data));
          } catch (e) {
            debugPrint('Fehler beim Schreiben von gps_last: $e');
          }
        },
        onError: (e) {
          debugPrint('PositionStream Fehler: $e');
        },
      );
    } catch (e) {
      debugPrint('Fehler beim Starten des BackgroundGpsService: $e');
    }
  }

  /// Stop listening to position updates.
  static Future<void> stop() async {
    try {
      await _sub?.cancel();
      _sub = null;
    } catch (e) {
      debugPrint('Fehler beim Stoppen des BackgroundGpsService: $e');
    }
  }

  /// Read last known gps saved in SharedPreferences.
  static Future<Map<String, dynamic>?> getLastKnown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('gps_last');
      if (s == null) return null;
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return null;
    }
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gps_service.dart';

class WeatherService {
  static Future<Map<String, String>?> getCurrentWeatherAndTemperature() async {
    final gps = await GpsService.getCurrentLocation();
    if (gps == null) return null;

    final lat = (gps['lat'] as num?)?.toDouble();
    final lon = (gps['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&current=temperature_2m,weather_code,wind_speed_10m'
      '&timezone=auto',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final current = decoded['current'];
      if (current is! Map<String, dynamic>) return null;

      final weatherCode = (current['weather_code'] as num?)?.toInt();
      final temp = (current['temperature_2m'] as num?)?.toDouble();
      final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0;

      if (weatherCode == null || temp == null) return null;

      var wetter = _mapWeatherCode(weatherCode);
      if (windSpeed >= 40) {
        wetter = 'windig';
      }

      return {
        'wetter': wetter,
        'temperatur': temp.round().toString(),
      };
    } catch (_) {
      return null;
    }
  }

  static String _mapWeatherCode(int code) {
    if (code == 0) return 'klar';

    if (<int>{1, 2, 3, 45, 48}.contains(code)) {
      return 'bewoelkt';
    }

    if (<int>{71, 73, 75, 77, 85, 86}.contains(code)) {
      return 'schnee';
    }

    if (<int>{
      51,
      53,
      55,
      56,
      57,
      61,
      63,
      65,
      66,
      67,
      80,
      81,
      82,
      95,
      96,
      99,
    }.contains(code)) {
      return 'regen';
    }

    return 'bewoelkt';
  }
}

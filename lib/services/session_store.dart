import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  final String evnr;
  final String strasse;
  final String erfasser;
  final String wetter; // klar | bewoelkt | regen | schnee | windig
  final String zeitIso;
  final String temperatur; // Temperatur in °C
  final String? nisPlanPdf; // Base64-kodiertes PDF für NIS-Plan

  SessionData({
    required this.evnr,
    required this.strasse,
    required this.erfasser,
    required this.wetter,
    required this.zeitIso,
    this.temperatur = '',
    this.nisPlanPdf,
  });

  Map<String, dynamic> toJson() => {
    'evnr': evnr,
    'strasse': strasse,
    'erfasser': erfasser,
    'wetter': wetter,
    'zeitIso': zeitIso,
    'temperatur': temperatur,
    'nisPlanPdf': nisPlanPdf,
  };

  static SessionData fromJson(Map<String, dynamic> m) => SessionData(
    evnr: (m['evnr'] ?? '').toString(),
    strasse: (m['strasse'] ?? '').toString(),
    erfasser: (m['erfasser'] ?? '').toString(),
    wetter: (m['wetter'] ?? 'klar').toString(),
    zeitIso: (m['zeitIso'] ?? DateTime.now().toIso8601String()).toString(),
    nisPlanPdf: m['nisPlanPdf'] as String?,
    temperatur: (m['temperatur'] ?? '').toString(),
  );
}

class NisPlanData {
  final String pdfBase64;
  final String? fileName;
  final List<List<List<double>>>?
  drawings; // normalisierte Freihand-Zeichnungen
  final List<Map<String, dynamic>>? routes; // Leitungsverläufe (Farbe + Punkte)
  final List<Map<String, dynamic>>? stamps; // Stempel (Typ + Position)

  NisPlanData({
    required this.pdfBase64,
    this.fileName,
    this.drawings,
    this.routes,
    this.stamps,
  });

  Map<String, dynamic> toJson() => {
    'pdfBase64': pdfBase64,
    'fileName': fileName,
    'drawings': drawings,
    'routes': routes,
    'stamps': stamps,
  };

  static NisPlanData fromJson(Map<String, dynamic> m) => NisPlanData(
    pdfBase64: (m['pdfBase64'] ?? '').toString(),
    fileName: m['fileName']?.toString(),
    drawings: _parseDrawings(m['drawings']),
    routes: _parseRoutes(m['routes']),
    stamps: _parseStamps(m['stamps']),
  );

  static List<List<List<double>>>? _parseDrawings(dynamic raw) {
    if (raw is! List) return null;
    final result = <List<List<double>>>[];
    for (final stroke in raw) {
      if (stroke is! List) continue;
      final points = <List<double>>[];
      for (final p in stroke) {
        if (p is List && p.length >= 2) {
          final dx = (p[0] is num) ? (p[0] as num).toDouble() : null;
          final dy = (p[1] is num) ? (p[1] as num).toDouble() : null;
          if (dx != null && dy != null) {
            points.add([dx, dy]);
          }
        }
      }
      if (points.isNotEmpty) result.add(points);
    }
    return result.isEmpty ? null : result;
  }

  static List<Map<String, dynamic>>? _parseRoutes(dynamic raw) {
    if (raw is! List) return null;
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        final map = item.cast<String, dynamic>();
        if (map['points'] is List) {
          result.add(map);
        }
      }
    }
    return result.isEmpty ? null : result;
  }

  static List<Map<String, dynamic>>? _parseStamps(dynamic raw) {
    if (raw is! List) return null;
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        final map = item.cast<String, dynamic>();
        if (map.containsKey('type') &&
            map.containsKey('x') &&
            map.containsKey('y')) {
          result.add(map);
        }
      }
    }
    return result.isEmpty ? null : result;
  }
}

extension SessionDataExt on SessionData {
  /// Convenience: parsed DateTime for older code that expects `.zeit`
  DateTime get zeit {
    try {
      return DateTime.parse(zeitIso);
    } catch (_) {
      return DateTime.now();
    }
  }
}

class SessionStore {
  static const _key = 'start_session_v1';
  static const _nisLegacyKey = 'nis_plan_by_evnr_v1';
  static const _nisIndexKey = 'nis_plan_evnr_index_v2';
  static const _nisItemPrefix = 'nis_plan_item_v2_';

  static String _nisItemKey(String evnr) {
    return '$_nisItemPrefix${Uri.encodeComponent(evnr)}';
  }

  static List<String> _cleanIndex(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final clean = value.trim();
      if (clean.isEmpty || seen.contains(clean)) continue;
      seen.add(clean);
      result.add(clean);
    }
    result.sort();
    return result;
  }

  static Future<void> save(SessionData s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));

    // Liste letzter EVNr pflegen (für spätere Auswahl)
    final k2 = 'recent_evnr';
    final list = prefs.getStringList(k2) ?? <String>[];
    if (!list.contains(s.evnr)) {
      list.insert(0, s.evnr);
      await prefs.setStringList(k2, list.take(20).toList());
    }
  }

  static Future<SessionData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return SessionData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> loadNisPlanEvnrs() async {
    final prefs = await SharedPreferences.getInstance();
    final indexed = prefs.getStringList(_nisIndexKey);
    if (indexed != null) return _cleanIndex(indexed);

    final fromPerEvnrKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(_nisItemPrefix))
        .map((key) => Uri.decodeComponent(key.substring(_nisItemPrefix.length)))
        .toList();
    final clean = _cleanIndex(fromPerEvnrKeys);
    if (clean.isNotEmpty) {
      await prefs.setStringList(_nisIndexKey, clean);
    }
    return clean;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> saveNisPlanForEvnr(
    String evnr,
    String pdfBase64, {
    String? fileName,
    List<List<List<double>>>? drawings,
    List<Map<String, dynamic>>? routes,
    List<Map<String, dynamic>>? stamps,
  }) async {
    final e = evnr.trim();
    if (e.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final data = NisPlanData(
      pdfBase64: pdfBase64,
      fileName: fileName,
      drawings: drawings,
      routes: routes,
      stamps: stamps,
    );

    await prefs.setString(_nisItemKey(e), jsonEncode(data.toJson()));
    await _addNisIndex(prefs, e);
  }

  static Future<NisPlanData?> loadNisPlanForEvnr(String evnr) async {
    final e = evnr.trim();
    if (e.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_nisItemKey(e));
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = NisPlanData.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        return data.pdfBase64.trim().isEmpty ? null : data;
      } catch (_) {
        await prefs.remove(_nisItemKey(e));
      }
    }

    final legacy = await _loadLegacyNisPlanForEvnr(prefs, e);
    if (legacy == null) return null;

    await prefs.setString(_nisItemKey(e), jsonEncode(legacy.toJson()));
    await _addNisIndex(prefs, e);
    return legacy;
  }

  static Future<void> clearNisPlanForEvnr(String evnr) async {
    final e = evnr.trim();
    if (e.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nisItemKey(e));
    await _removeNisIndex(prefs, e);

    final raw = prefs.getString(_nisLegacyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.remove(e);
      if (map.isEmpty) {
        await prefs.remove(_nisLegacyKey);
      } else {
        await prefs.setString(_nisLegacyKey, jsonEncode(map));
      }
    } catch (_) {
      return;
    }
  }

  static Future<void> _addNisIndex(SharedPreferences prefs, String evnr) async {
    final current = prefs.getStringList(_nisIndexKey) ?? <String>[];
    await prefs.setStringList(_nisIndexKey, _cleanIndex([...current, evnr]));
  }

  static Future<void> _removeNisIndex(
    SharedPreferences prefs,
    String evnr,
  ) async {
    final current = prefs.getStringList(_nisIndexKey) ?? <String>[];
    await prefs.setStringList(
      _nisIndexKey,
      _cleanIndex(current.where((value) => value.trim() != evnr).toList()),
    );
  }

  static Future<NisPlanData?> _loadLegacyNisPlanForEvnr(
    SharedPreferences prefs,
    String evnr,
  ) async {
    final raw = prefs.getString(_nisLegacyKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final item = map[evnr];
      if (item is Map<String, dynamic>) {
        final data = NisPlanData.fromJson(item);
        return data.pdfBase64.trim().isEmpty ? null : data;
      }
      if (item is Map) {
        final data = NisPlanData.fromJson(item.cast<String, dynamic>());
        return data.pdfBase64.trim().isEmpty ? null : data;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

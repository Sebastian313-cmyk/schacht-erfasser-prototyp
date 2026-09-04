class HandoffDestination {
  static const nis = 'Small World / NIS-Abteilung';
  static const kanio = 'Kanio Aufträge';
}

class HandoffItem {
  final String destination;
  final String evnr;
  final String strasse;
  final String position;
  final String objekt;
  final List<String> reasons;
  final String note;

  const HandoffItem({
    required this.destination,
    required this.evnr,
    required this.strasse,
    required this.position,
    required this.objekt,
    required this.reasons,
    this.note = '',
  });

  String get title {
    final pos = position.isEmpty ? '-' : position;
    final typ = objekt.isEmpty ? 'Objekt' : objekt;
    return '$typ Position $pos';
  }

  String get reasonsText => reasons.join(', ');
}

class HandoffSummary {
  final List<HandoffItem> nisItems;
  final List<HandoffItem> kanioItems;

  const HandoffSummary({
    this.nisItems = const <HandoffItem>[],
    this.kanioItems = const <HandoffItem>[],
  });

  int get totalCount => nisItems.length + kanioItems.length;
  bool get isEmpty => totalCount == 0;
}

class HandoffRulesService {
  static const _nisTriggers = <String>{'nicht im nis', 'gibt es nicht'};

  static HandoffSummary buildSummary(List<Map<String, dynamic>> entries) {
    final nisItems = <HandoffItem>[];
    final kanioItems = <HandoffItem>[];

    for (final meta in entries) {
      final nisReasons = nisReasonsFor(meta);
      if (nisReasons.isNotEmpty) {
        nisItems.add(_itemFor(meta, HandoffDestination.nis, nisReasons));
      }

      final damageReasons = kanioReasonsFor(meta);
      if (damageReasons.isNotEmpty) {
        kanioItems.add(_itemFor(meta, HandoffDestination.kanio, damageReasons));
      }
    }

    return HandoffSummary(nisItems: nisItems, kanioItems: kanioItems);
  }

  static List<String> nisReasonsFor(Map<String, dynamic> meta) {
    final values = _values(meta['verfuegbarkeit']);
    final reasons = <String>[];

    for (final value in values) {
      final normalized = _normalize(value);
      if (_nisTriggers.contains(normalized)) {
        reasons.add(value);
      } else if (normalized.contains('leitungsverlauf')) {
        reasons.add(value);
      }
    }

    return _unique(reasons);
  }

  static List<String> kanioReasonsFor(Map<String, dynamic> meta) {
    if (meta['keinBefund'] == true) return const <String>[];

    final schaeden = _values(
      meta['schaeden'],
    ).where((value) => _isRealDamage(value)).toList();
    if (schaeden.isEmpty) return const <String>[];

    return _unique(schaeden);
  }

  static HandoffItem _itemFor(
    Map<String, dynamic> meta,
    String destination,
    List<String> reasons,
  ) {
    return HandoffItem(
      destination: destination,
      evnr: _text(meta['evnr'] ?? meta['EVNr']),
      strasse: _text(meta['strasse'] ?? meta['Straße']),
      position: _text(
        meta['posNr'] ??
            meta['positionsnummer'] ??
            meta['Positionsnummer'] ??
            meta['position'],
      ),
      objekt: _text(meta['typ'] ?? meta['objekt'] ?? meta['objektart']),
      reasons: reasons,
      note: _text(meta['bemerkung'] ?? meta['Bemerkung']),
    );
  }

  static bool _isRealDamage(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return false;
    if (normalized == 'kein befund') return false;
    if (normalized == 'keine schaeden') return false;
    if (normalized == 'keine schäden') return false;
    return true;
  }

  static List<String> _values(dynamic raw) {
    if (raw == null) return const <String>[];
    if (raw is Iterable) {
      return raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    return raw
        .toString()
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  static List<String> _unique(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final key = _normalize(value);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(value);
    }
    return result;
  }

  static String _text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}

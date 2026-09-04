import 'speicher_service.dart';

class ValidationResult {
  final bool isValid;
  final String? message;

  const ValidationResult._(this.isValid, this.message);

  const ValidationResult.ok() : this._(true, null);

  const ValidationResult.fail(String message) : this._(false, message);
}

class ValidationService {
  static final RegExp _positionPattern = RegExp(r'^[0-9]+[a-zA-Z]?$');
  static final RegExp _digitsOnlyPattern = RegExp(r'^\d+$');
  static const Set<int> _standardSchachtdurchmesserCm = {100, 120};

  static const Map<String, int> _idLengthByType = {
    'ES': 8,
    'SSK': 8,
    'SK': 4,
    'VS': 6,
    'VG': 6,
    'KANAL': 6,
  };

  static String? validatePositionField(
    String? value, {
    String requiredMessage = 'Pflichtfeld',
    String formatMessage = 'Format: Zahl + optionaler Buchstabe',
  }) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return requiredMessage;
    if (!_positionPattern.hasMatch(trimmed)) return formatMessage;
    return null;
  }

  static String? validateSchachtdurchmesserCm(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Bitte Schachtdurchmesser eintragen.';
    }

    final normalized = trimmed.replaceAll(',', '.');
    final parsed = num.tryParse(normalized);
    if (parsed == null) {
      return 'Schachtdurchmesser bitte als Zahl in cm eintragen.';
    }

    if (parsed % 1 != 0) {
      return 'Schachtdurchmesser bitte ohne Nachkommastellen eintragen.';
    }

    final diameter = parsed.toInt();
    if (!_standardSchachtdurchmesserCm.contains(diameter)) {
      return 'Schachtdurchmesser muss 100 oder 120 cm sein.';
    }

    return null;
  }

  static ValidationResult validateNoKeinBefundMitSchaeden({
    required bool keinBefund,
    required Iterable<dynamic> schaeden,
    required String message,
  }) {
    if (!keinBefund) return const ValidationResult.ok();

    final hasSchaeden = schaeden
        .map((e) => e.toString().trim())
        .any((s) => s.isNotEmpty);
    if (hasSchaeden) {
      return ValidationResult.fail(message);
    }
    return const ValidationResult.ok();
  }

  static Future<ValidationResult> validateUniquePosition({
    required String evnr,
    required String strasse,
    required String posNr,
    String? excludeStorageKey,
  }) async {
    final pos = posNr.trim();
    if (pos.isEmpty) {
      return const ValidationResult.fail('Positionsnummer fehlt.');
    }

    final entries = await SpeicherService.ladeEintraegeFuerEvNr(
      evnr,
      strasse: strasse,
    );

    final normalizedExcludeKey = (excludeStorageKey ?? '').trim();
    final requestedPositions = _splitPositions(pos);
    final conflictingPositions = <String>{};

    for (final entry in entries) {
      final existingPos = (entry['posNr'] ?? '').toString().trim();
      final entryKey = (entry['storageKey'] ?? '').toString().trim();
      if (normalizedExcludeKey.isNotEmpty && entryKey == normalizedExcludeKey) {
        continue;
      }

      final overlap = requestedPositions.intersection(
        _splitPositions(existingPos),
      );
      conflictingPositions.addAll(overlap);
    }

    if (conflictingPositions.isNotEmpty) {
      final conflicts = conflictingPositions.toList()..sort(_comparePositions);
      return ValidationResult.fail(
        conflicts.length == 1
            ? 'Position ${conflicts.first} ist in dieser EVNr/Straße bereits belegt.'
            : 'Die Positionen ${conflicts.join(", ")} sind in dieser EVNr/Straße bereits belegt.',
      );
    }

    return const ValidationResult.ok();
  }

  static Set<String> _splitPositions(String value) => value
      .split('/')
      .map((part) => part.trim().toLowerCase())
      .where((part) => part.isNotEmpty)
      .toSet();

  static int _comparePositions(String a, String b) {
    final aMatch = RegExp(r'^(\d+)([a-z]?)$').firstMatch(a);
    final bMatch = RegExp(r'^(\d+)([a-z]?)$').firstMatch(b);
    if (aMatch == null || bMatch == null) return a.compareTo(b);

    final numberComparison = int.parse(
      aMatch.group(1)!,
    ).compareTo(int.parse(bMatch.group(1)!));
    if (numberComparison != 0) return numberComparison;
    return aMatch.group(2)!.compareTo(bMatch.group(2)!);
  }

  /// Validiert die ID-Nummer typabhaengig (nur Ziffern, feste Laenge).
  /// Wenn [required] false ist, darf die ID leer bleiben.
  static String? validateIdNumberByType(
    String? value, {
    required String typ,
    bool required = true,
  }) {
    final normalizedType = typ.trim().toUpperCase();
    final expectedLength = _idLengthByType[normalizedType];
    if (expectedLength == null) return null;

    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      if (required) {
        return 'ID-Nummer ist Pflicht ($expectedLength-stellig).';
      }
      return null;
    }

    if (!_digitsOnlyPattern.hasMatch(trimmed)) {
      return 'ID-Nummer darf nur Ziffern enthalten.';
    }
    if (trimmed.length != expectedLength) {
      return 'ID-Nummer muss genau $expectedLength-stellig sein.';
    }
    return null;
  }
}

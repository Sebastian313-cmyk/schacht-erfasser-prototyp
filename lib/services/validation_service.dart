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
    final hasDuplicate = entries.any((entry) {
      final existingPos = (entry['posNr'] ?? '').toString().trim();
      if (existingPos != pos) return false;

      final entryKey = (entry['storageKey'] ?? '').toString().trim();
      if (normalizedExcludeKey.isNotEmpty && entryKey == normalizedExcludeKey) {
        return false;
      }

      return true;
    });

    if (hasDuplicate) {
      return ValidationResult.fail(
        'Positionsnummer $pos existiert bereits in dieser EVNr/Straße.',
      );
    }

    return const ValidationResult.ok();
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
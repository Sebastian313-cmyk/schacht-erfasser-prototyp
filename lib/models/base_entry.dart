import 'enums.dart';
import 'ssk_entry.dart';

class BaseEntry {
  final String id;
  final EntryType type;

  /// EVNr – wichtig für Bericht/Export und Repository-Filter
  final String evnr;

  // Basisfelder – gelten für alle Module
  final String? positionsnummer;
  final String? titel;          // = Schaden
  final DateTime? zeit;
  final String? strasse;
  final String? bemerkung;

  // Verfügbarkeit / Status / Zusatzinfos
  final String? verfuegbarkeitLabel;
  final String? statusVorOrtLabel;
  final String? notizen;
  final String? spezial;

  // NEU: gemeinsame technische Felder
  final String? deckelart;      // bei allen Modulen nutzbar
  final String? klasse;         // Belastungsklasse

  // NEU: nur sinnvoll bei ES (Einstiegschacht)
  final String? zugang;         // Zugang (Fahrbahn/Gehweg/Grünfläche…)
  final String? einsteigart;    // Steigeisen/Leiter/Podest…

  BaseEntry({
    required this.id,
    required this.type,
    required this.evnr,
    this.positionsnummer,
    this.titel,
    this.zeit,
    this.strasse,
    this.bemerkung,
    this.verfuegbarkeitLabel,
    this.statusVorOrtLabel,
    this.notizen,
    this.spezial,
    this.deckelart,
    this.klasse,
    this.zugang,
    this.einsteigart,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'evnr': evnr,
    'positionsnummer': positionsnummer,
    'titel': titel,
    'zeit': zeit?.toIso8601String(),
    'strasse': strasse,
    'bemerkung': bemerkung,
    'verfuegbarkeitLabel': verfuegbarkeitLabel,
    'statusVorOrtLabel': statusVorOrtLabel,
    'notizen': notizen,
    'spezial': spezial,
    'deckelart': deckelart,
    'klasse': klasse,
    'zugang': zugang,
    'einsteigart': einsteigart,
  };

  factory BaseEntry.fromJson(Map<String, dynamic> json) {
    return BaseEntry(
      id: json['id'] ?? '',
      type: EntryType.values[json['type'] ?? 0],
      evnr: (json['evnr'] ?? '').toString(),
      positionsnummer: json['positionsnummer'],
      titel: json['titel'],
      zeit: json['zeit'] != null ? DateTime.parse(json['zeit']) : null,
      strasse: json['strasse'],
      bemerkung: json['bemerkung'],
      verfuegbarkeitLabel: json['verfuegbarkeitLabel'],
      statusVorOrtLabel: json['statusVorOrtLabel'],
      notizen: json['notizen'],
      spezial: json['spezial'],
      deckelart: json['deckelart'],
      klasse: json['klasse'],
      zugang: json['zugang'],
      einsteigart: json['einsteigart'],
    );
  }
}

/// EntrySummary trennt jetzt strikt:
/// - Schaden (summaryShort) = nur `titel`
/// - Status vor Ort bleibt separat in `statusVorOrtLabel`
/// - Details (summaryDetail) = Notizen + Spezial + SSK-Zustände
extension EntrySummary on BaseEntry {
  /// Kurztext für den Schaden (Spalte "Schaden").
  /// Nur das Schaden-Feld (`titel`). Kein Status, keine Zustände.
  String get summaryShort {
    if ((titel ?? '').trim().isNotEmpty) {
      return titel!.trim();
    }
    // Verhalten nach Typ
    if (type == EntryType.ssk && this is SskEntry) {
      final s = this as SskEntry;
      final head = (statusVorOrtLabel ?? '').trim();
      final sParts = <String>[];
      if ((s.leitungsverlauf ?? '').trim().isNotEmpty) sParts.add('Leitungsverlauf: ${_shortClean(s.leitungsverlauf!)}');
      if ((s.rinnenzustand ?? '').trim().isNotEmpty) sParts.add('Rinne: ${_shortClean(s.rinnenzustand!)}');
      if ((s.einlaufzustand ?? '').trim().isNotEmpty) sParts.add('Einlauf: ${_shortClean(s.einlaufzustand!)}');

      if (head.isNotEmpty && sParts.isNotEmpty) {
        return '$head | ${sParts.join(' • ')}';
      }
      if (sParts.isNotEmpty) {
        return sParts.join(' • ');
      }

      // Fallback für SSK ohne Inhalte
      return 'ohne Titel';
    }

    // Für andere Typen: wenn kein Titel vorhanden -> 'ohne Titel'
    return 'ohne Titel';
  }

  /// Detailtext für "Details" (PDF/ Bericht):
  /// Enthält Notizen + Spezial + (bei SSK) Leitungsverlauf/Rinnen-/Einlaufzustand.
  /// Status kommt NICHT hinein.
  String get summaryDetail {
    final parts = <String>[];
    if ((notizen ?? '').trim().isNotEmpty) {
      parts.add('Notiz: ${notizen!.trim()}');
    }
    if ((spezial ?? '').trim().isNotEmpty) {
      parts.add('Spezial: ${spezial!.trim()}');
    }
    if (type == EntryType.einsteigschacht) {
      if ((deckelart ?? '').trim().isNotEmpty) parts.add('Deckel: ${deckelart!.trim()}');
      if ((klasse ?? '').trim().isNotEmpty) parts.add('KL: ${klasse!.trim()}');
      if ((zugang ?? '').trim().isNotEmpty) parts.add('Zugang: ${zugang!.trim()}');
      if ((einsteigart ?? '').trim().isNotEmpty) parts.add('Einsteigart: ${einsteigart!.trim()}');
    }
    if (type == EntryType.ssk && this is SskEntry) {
      final s = this as SskEntry;
      if ((s.leitungsverlauf ?? '').trim().isNotEmpty) {
        parts.add('Leitungsverlauf: ${_shortClean(s.leitungsverlauf!)}');
      }
      if ((s.rinnenzustand ?? '').trim().isNotEmpty) {
        parts.add('Rinnenzustand: ${_shortClean(s.rinnenzustand!)}');
      }
      if ((s.einlaufzustand ?? '').trim().isNotEmpty) {
        parts.add('Einlaufzustand: ${_shortClean(s.einlaufzustand!)}');
      }
    }
    return parts.isEmpty ? '' : parts.join(' • ');
  }

  String _shortClean(String v) => v.trim();
}

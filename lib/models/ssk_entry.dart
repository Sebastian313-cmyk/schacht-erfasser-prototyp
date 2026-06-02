import 'base_entry.dart';
import 'enums.dart';

class SskEntry extends BaseEntry {
  final String? leitungsverlauf;
  final String? rinnenzustand;
  final String? einlaufzustand;

  SskEntry({
    required super.id,
    required super.evnr,
    super.positionsnummer,
    super.titel,
    super.zeit,
    super.strasse,
    super.bemerkung,
    super.verfuegbarkeitLabel,
    super.statusVorOrtLabel,
    super.notizen,
    super.spezial,
    this.leitungsverlauf,
    this.rinnenzustand,
    this.einlaufzustand,
  }) : super(type: EntryType.ssk);

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'leitungsverlauf': leitungsverlauf,
    'rinnenzustand': rinnenzustand,
    'einlaufzustand': einlaufzustand,
  };

  factory SskEntry.fromJson(Map<String, dynamic> json) {
    return SskEntry(
      id: json['id'] ?? '',
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
      leitungsverlauf: json['leitungsverlauf'],
      rinnenzustand: json['rinnenzustand'],
      einlaufzustand: json['einlaufzustand'],
    );
  }
}

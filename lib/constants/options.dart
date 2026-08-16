// ================================
// Deckelart fuer Schacht-Objekte
// ================================

const String kStandardSchachtDeckelart = 'Begu DN 625';

const List<String> kSchachtDeckelartOptions = [
  kStandardSchachtDeckelart,
  'Mannloch',
  'Budaplan',
  'Bemerkung',
];

String normalizeSchachtDeckelart(
  dynamic value, {
  String fallback = kStandardSchachtDeckelart,
}) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) return fallback;

  final lower = text.toLowerCase();
  if (lower == 'dn' || lower == 'dn 625' || lower == 'begu dn625') {
    return kStandardSchachtDeckelart;
  }
  if (lower.startsWith('bemerkung:')) return 'Bemerkung';
  if (kSchachtDeckelartOptions.contains(text)) return text;
  return text;
}

String schachtDeckelBemerkung(dynamic value) {
  final text = (value ?? '').toString().trim();
  if (text.toLowerCase().startsWith('bemerkung:')) {
    return text.substring('Bemerkung:'.length).trim();
  }
  return '';
}

String buildSchachtDeckelartLabel(String deckel, String bemerkung) {
  if (deckel != 'Bemerkung') return deckel;
  final clean = bemerkung.trim();
  return clean.isEmpty ? 'Bemerkung' : 'Bemerkung: $clean';
}
// ================================
// Verfügbarkeit
// ================================

const String kVerfuegbarkeitNichtImNis = 'Nicht im NIS';

bool hasNichtImNis(dynamic value) {
  if (value == null) return false;
  if (value is Iterable) {
    return value.any(
      (entry) => entry.toString().trim() == kVerfuegbarkeitNichtImNis,
    );
  }
  return value
      .toString()
      .split(',')
      .map((entry) => entry.trim())
      .contains(kVerfuegbarkeitNichtImNis);
}

// Für ES, VS, LÜ, SK
const List<String> kVerfuegbarkeitOptionsAll = [
  kVerfuegbarkeitNichtImNis,
  'Ergänzen',
  'gibt es nicht',
];

// Für SSK
const List<String> kVerfuegbarkeitOptionsSsk = [
  kVerfuegbarkeitNichtImNis,
  'Ergänzen',
  'Leitungsverlauf ergänzen',
  'gibt es nicht',
];

// ================================
// Status vor Ort
// ================================

// Gilt für ALLE außer Sonstige
const List<String> kStatusAllgemein = [
  'zugeparkt',
  'Verkehr',
  'überbaut',
  'zugewachsen',
  'unterm Erdreich/Straße',
];

// Zusatz nur bei SSK
const List<String> kStatusSskExtra = [
  'läuft augenscheinlich ab',
  'läuft augenscheinlich nicht ab',
];

// Organisationsstruktur Kanalbetrieb 31 – mögliche Empfänger eines Meldescheins.
// Die Liste ist bewusst zentral gepflegt, damit KI31 nur gültige Empfänger vorschlagen kann.

export const EMPFAENGER = [
  '311 Arbeitssicherheit',
  '311 Koordinierung',
  '311 Netzsteuerung',
  '311 Netzeinstieg HN/AU',
  '311 Fuhrpark',
  '312 Störung, Service und Wache',
  '312 Arbeitsplanung',
  '312 Netzreinigung West – Kanalreinigung',
  '312 Netzreinigung West – Straßenentwässerung',
  '312 Netzreinigung Ost – Kanalreinigung',
  '312 Netzreinigung Ost – Straßenentwässerung',
  '312 Kanalinspektion',
  '313 BU-B Baukontrolle',
  '313 BU-B Bestandssicherung',
  '313 BU-BS',
  '313 BU-M Maurer',
  '313 BU-M Sanierung',
  '313 Technischer Unterhalt'
];

export const OBJEKTARTEN = [
  'Einstieg',
  'Grube',
  'Straßensinkkasten',
  'Lüftung',
  'Schieber',
  'Kanal',
  'Sonstige'
];

export const DRINGLICHKEITEN = ['normal', 'dringend', 'sofort'];

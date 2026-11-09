// KI31 – Zuordnung einer Anfrage zu einem Fachagenten.
// Im Pilot ist die Zuordnung regelbasiert und damit nachvollziehbar. Jeder Fachagent hat einen
// eigenen Arbeitsauftrag (Systemtext) und eine Liste von Werkzeugen, die er überhaupt
// anbieten darf. Ob die angemeldete Rolle ein Werkzeug nutzen darf, entscheidet 31C
// (berechtigungen.js).

export const AGENTEN = {
  '311': {
    name: '311 – Zentrale Aufgaben',
    auftrag:
      'Du unterstützt bei Arbeitssicherheit, Koordinierung, Netzsteuerung, Netzeinstieg (HN/AU), ' +
      'Fuhrpark und Betriebsorganisation. Bei Einstiegserlaubnissen weist du auf die zuständige ' +
      'Bezirksansicht (West oder Ost) hin und entscheidest nichts selbst.',
    werkzeuge: ['auftrag_zusammenfassen', 'fehlende_angaben'],
    stichworte: ['einstiegserlaubnis', 'arbeitssicherheit', 'fahrzeug', 'fuhrpark', 'kantine', 'netzsteuerung', 'koordin', 'gefährdung']
  },
  '312': {
    name: '312 – Netzwartung und Netzinspektion',
    auftrag:
      'Du unterstützt bei Störung, Service und Wache, Arbeitsplanung, Kanalreinigung, ' +
      'Straßenentwässerung und Kanalinspektion.',
    werkzeuge: ['auftrag_zusammenfassen', 'fehlende_angaben'],
    stichworte: ['reinig', 'spül', 'inspektion', 'tv-', 'kamera', 'störung', 'verstopf', 'straßenentwässerung', 'sinkkasten', 'wache']
  },
  '313': {
    name: '313 – Netzinstandsetzung',
    auftrag:
      'Du unterstützt den Baulichen Unterhalt (BU-B, BU-BS, BU-M Maurer und Sanierung) und den ' +
      'Technischen Unterhalt. Du hilfst, Schäden an Einstiegen, Gruben, Kanälen und ' +
      'Straßensinkkästen sauber zu dokumentieren und Meldescheine vorzubereiten.',
    werkzeuge: ['auftrag_zusammenfassen', 'fehlende_angaben', 'meldeschein_entwerfen'],
    stichworte: ['mauer', 'sanier', 'schaden', 'riss', 'rahmen', 'steigeisen', 'abdeckung', 'meldeschein', 'schacht', 'einstieg']
  }
};

/**
 * Wählt den Fachagenten. Stichworte in der Nachricht haben Vorrang; ohne Treffer wird der
 * Bereich genommen, zu dem der Auftrag gehört (BU-M-Aufträge → 313).
 */
export function waehleAgent(nachricht = '', auftrag = null) {
  const text = nachricht.toLowerCase();
  let bester = null;
  let besteTreffer = 0;
  for (const [kennung, agent] of Object.entries(AGENTEN)) {
    const treffer = agent.stichworte.filter((s) => text.includes(s)).length;
    if (treffer > besteTreffer) {
      bester = kennung;
      besteTreffer = treffer;
    }
  }
  if (bester) return bester;
  if (auftrag && ['Maurer', 'Sanierung'].includes(auftrag.auftragsart)) return '313';
  return '313';
}

/**
 * Erkennt, ob eine Chatnachricht ein Werkzeug anfordert.
 * Gibt den Werkzeugnamen zurück oder null.
 */
export function erkenneWerkzeug(nachricht = '') {
  const t = nachricht.toLowerCase();
  if (/meldeschein/.test(t) && /(entw|erstell|schreib|mach|vorbereit|formulier)/.test(t)) return 'meldeschein_entwerfen';
  if (/(fehl|offen|vollständig|unvollständig|prüf)/.test(t) && /(angabe|feld|auftrag|daten|was)/.test(t)) return 'fehlende_angaben';
  if (/(zusammenfass|fass\b.*zusammen|überblick|kurzfassung)/.test(t)) return 'auftrag_zusammenfassen';
  return null;
}

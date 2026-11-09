// 31C – Berechtigungen für Werkzeuge.
// Im Pilot gibt es zwei Testrollen. Später prüft hier der Server echte Personen-, Abteilungs-
// und Ordnerrechte. Wichtig: Die Prüfung findet auf dem Server statt, nicht im Browser und nicht
// im Sprachmodell.

export const ROLLEN = {
  fuehrungskraft: {
    bezeichnung: 'Führungskraft',
    werkzeuge: ['auftrag_zusammenfassen', 'fehlende_angaben', 'meldeschein_entwerfen', 'meldeschein_uebernehmen']
  },
  mitarbeitende: {
    bezeichnung: 'Mitarbeitende',
    werkzeuge: ['auftrag_zusammenfassen', 'fehlende_angaben']
  }
};

export function darfWerkzeug(rolle, werkzeug) {
  const r = ROLLEN[rolle];
  return Boolean(r && r.werkzeuge.includes(werkzeug));
}

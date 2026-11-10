// 31C – Berechtigungen.
// Im Pilot gibt es drei Testrollen. Später prüft hier der Server echte Personen-, Abteilungs-
// und Ordnerrechte. Wichtig: Die Prüfung findet auf dem Server statt, nicht im Browser und nicht
// im Sprachmodell.

export const ROLLEN = {
  fuehrungskraft: {
    bezeichnung: 'Führungskraft',
    werkzeuge: [
      'felder_setzen',
      'auftrag_zusammenfassen',
      'fehlende_angaben',
      'meldeschein_entwerfen',
      'meldeschein_uebernehmen',
      'einstiegserlaubnis_vorbereiten',
      'reinigung_anfragen'
    ]
  },
  mitarbeitende: {
    bezeichnung: 'Mitarbeitende',
    werkzeuge: ['felder_setzen', 'auftrag_zusammenfassen', 'fehlende_angaben']
  },
  it31c: {
    bezeichnung: '31C – IT',
    // 31C bearbeitet Werkstatt-Einträge und gibt Werkzeuge frei. Fachwerkzeuge nutzt 31C nur zum Testen.
    werkzeuge: ['auftrag_zusammenfassen', 'fehlende_angaben', 'werkstatt_bearbeiten', 'werkstatt_freigeben']
  }
};

/**
 * @param {string} rolle
 * @param {string} werkzeug  Name des Werkzeugs
 * @param {{quelle?: string, freigabe?: {rollen: string[]}}} [eintrag]  bei Werkstatt-Werkzeugen
 */
export function darfWerkzeug(rolle, werkzeug, eintrag) {
  if (!ROLLEN[rolle]) return false;
  if (eintrag?.quelle === 'werkstatt') return Boolean(eintrag.freigabe?.rollen?.includes(rolle));
  return ROLLEN[rolle].werkzeuge.includes(werkzeug);
}

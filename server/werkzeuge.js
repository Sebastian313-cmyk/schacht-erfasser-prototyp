// Werkzeuge von KI31 und den Fachagenten.
// Jedes Werkzeug gehört einem Agenten. Ob eine Rolle es nutzen darf, entscheidet 31C
// (berechtigungen.js). Werkzeuge ändern nie selbst Daten: Sie liefern Ergebnisse oder
// Änderungsvorschläge, die ein Mensch bestätigt.

import { pruefeAenderungen } from './felder.js';
import * as ki from './ki.js';
import { pruefeAuftrag } from './regeln.js';
import * as werkstatt from './werkstatt.js';

export const EINGEBAUT = {
  felder_setzen: {
    titel: 'Felder ausfüllen',
    agent: 'KI31',
    beschreibung: 'Trägt Angaben in Auftragsfelder ein (als Vorschlag zur Bestätigung). Parameter: {"aenderungen":[{"feld":"objekte.0.dn","wert":"300"}]}',
    ausfuehren: async ({ auftrag, parameter }) => pruefeAenderungen(auftrag, parameter?.aenderungen)
  },
  auftrag_zusammenfassen: {
    titel: 'Auftrag zusammenfassen',
    agent: 'KI31',
    beschreibung: 'Kurzüberblick über den Auftrag. Keine Parameter.',
    ausfuehren: async ({ auftrag, modus, agent }) => ({ text: await ki.zusammenfassen(auftrag, { modus, agent }) })
  },
  fehlende_angaben: {
    titel: 'Fehlende Angaben prüfen',
    agent: 'KI31',
    beschreibung: 'Prüft Pflichtangaben und Klärungsbedarf. Keine Parameter.',
    ausfuehren: async ({ auftrag, modus, agent }) => ki.fehlendeAngaben(auftrag, { modus, agent })
  },
  meldeschein_entwerfen: {
    titel: 'Meldeschein entwerfen',
    agent: '313',
    beschreibung: 'Entwirft einen Meldeschein zur Weitergabe des Auftrags. Parameter optional: {"wunsch":"…"}',
    ausfuehren: async ({ auftrag, modus, parameter }) => ({
      meldeschein: await ki.meldescheinEntwerfen(auftrag, { modus, agent: '313', wunsch: parameter?.wunsch || '' })
    })
  },
  einstiegserlaubnis_vorbereiten: {
    titel: 'Einstiegserlaubnis vorbereiten',
    agent: '311',
    beschreibung: 'Bereitet den Antrag auf Einstiegserlaubnis aus dem Auftrag vor. Die Entscheidung trifft die zuständige Person. Keine Parameter.',
    ausfuehren: async ({ auftrag }) => ({ antrag: einstiegsantrag(auftrag) })
  },
  reinigung_anfragen: {
    titel: 'Reinigung oder Inspektion anfragen',
    agent: '312',
    beschreibung: 'Entwirft einen Meldeschein an Netzreinigung oder Kanalinspektion. Parameter: {"art":"reinigung"|"inspektion"}',
    ausfuehren: async ({ auftrag, parameter }) => ({ meldeschein: anfrage312(auftrag, parameter?.art) })
  }
};

function einstiegsantrag(a) {
  const ee = a.einstiegserlaubnis || {};
  const objekte = (a.objekte || []).filter((o) => ['Einstieg', 'Grube', 'Kanal'].includes(o.objektart));
  const offen = [];
  if (!ee.bezirk) offen.push('Bezirk (West oder Ost) festlegen – davon hängt die zuständige Bezirksansicht ab.');
  if (objekte.length === 0) offen.push('Kein Einstieg, keine Grube und kein Kanal im Auftrag – ist eine Einstiegserlaubnis nötig?');
  if (!a.ausfuehrungstermin) offen.push('Geplanter Ausführungstermin fehlt.');
  if (!(a.personal || []).length) offen.push('Einsteigendes Personal ist noch nicht zugeordnet.');
  return {
    bezirk: ee.bezirk || '',
    auftragsnummer: a.auftragsnummer || '',
    ort: [a.strasse, a.hausnummer].filter(Boolean).join(' '),
    objekte: objekte.map((o) => [o.objektart, o.objektId, o.dn ? `DN ${o.dn}` : ''].filter(Boolean).join(' ')),
    anlass: objekte.map((o) => o.arbeit || o.befund).filter(Boolean).join('; '),
    personal: a.personal || [],
    termin: a.ausfuehrungstermin || '',
    offenePunkte: offen,
    hinweis: 'Entwurf. Zentrale Bereitstellung und Entscheidung erfolgen durch die zuständige Person im Ablauf Einstiegserlaubnis.'
  };
}

function anfrage312(a, art) {
  const bezirk = a.einstiegserlaubnis?.bezirk;
  const inspektion = art === 'inspektion';
  const empfaenger = inspektion ? '312 Kanalinspektion' : bezirk ? `312 Netzreinigung ${bezirk} – Kanalreinigung` : '';
  const o = (a.objekte || [])[0] || {};
  return ki.bereinigeMeldeschein(
    {
      empfaenger,
      angeforderteLeistung: inspektion ? 'Kanal-TV-Inspektion des betroffenen Abschnitts' : 'Reinigung vor Beginn der Instandsetzung',
      begruendung: o.befund ? `Befund: ${o.befund}` : '',
      dringlichkeit: 'normal',
      ortsangabe: [a.strasse, a.hausnummer].filter(Boolean).join(' '),
      objektbezug: [o.objektart, o.objektId, o.dn ? `DN ${o.dn}` : ''].filter(Boolean).join(', '),
      hinweise: ['Entwurf von Agent 312.'],
      offenePunkte: !inspektion && !bezirk ? ['Bezirk (West/Ost) fehlt – Empfänger Netzreinigung West oder Ost wählen.'] : []
    },
    pruefeAuftrag(a)
  );
}

/** Alle Werkzeuge, die gerade nutzbar sind: eingebaute + von 31C freigegebene Werkstatt-Werkzeuge. */
export async function verfuegbar() {
  const liste = Object.entries(EINGEBAUT).map(([name, w]) => ({ name, ...w, quelle: 'eingebaut' }));
  for (const e of await werkstatt.freigegebene()) {
    liste.push({
      name: e.spec.name,
      titel: e.spec.titel,
      agent: e.spec.agent,
      beschreibung: e.spec.beschreibung || e.spec.titel,
      stichworte: e.spec.stichworte,
      quelle: 'werkstatt',
      freigabe: e.freigabe,
      ausfuehren: async ({ auftrag }) => werkstatt.fuehreAus(e.spec, auftrag)
    });
  }
  return liste;
}

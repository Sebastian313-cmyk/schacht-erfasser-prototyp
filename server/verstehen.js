// Verstehen ohne Sprachmodell: feste Regeln, die aus einem Satz Arbeitsschritte machen.
// Sie laufen im Demo-Modus und als Rückfallebene, wenn das Sprachmodell keinen gültigen Plan liefert.
//
// Ergebnis: { schritte: [{ werkzeug, parameter }], luecke: string|null }

const WETTER = ['regen', 'sonnig', 'sonne', 'bedeckt', 'bewölkt', 'schnee', 'nebel', 'frost', 'trocken', 'nieselregen', 'glätte'];

function objektIndex(auftrag, art) {
  const objekte = auftrag?.objekte || [];
  const i = art ? objekte.findIndex((o) => o.objektart === art) : -1;
  return i >= 0 ? i : 0;
}

export function erkenneFelder(text, auftrag) {
  const t = text.toLowerCase();
  const aenderungen = [];
  const add = (feld, wert) => aenderungen.push({ feld, wert });

  const dn = text.match(/\bDN\s*(?:ist|=|:)?\s*(\d{2,4})\b/i);
  if (dn) add(`objekte.${objektIndex(auftrag, 'Kanal')}.dn`, dn[1]);

  const id = text.match(/objekt-?\s?id\s*(?:ist|:|=)?\s*([A-Z0-9][A-Z0-9-]{2,})/i);
  if (id) add(`objekte.${objektIndex(auftrag)}.objektId`, id[1].toUpperCase());

  if (/einstiegserlaubnis/.test(t)) {
    if (/(keine|nicht nötig|nicht erforderlich|ohne|brauchen wir nicht)/.test(t)) add('einstiegserlaubnis.erforderlich', false);
    else if (/(brauch|erforderlich|nötig|notwendig|benötig|muss|ist ja)/.test(t)) add('einstiegserlaubnis.erforderlich', true);
  }
  const bezirk = t.match(/bezirk\s*(west|ost)\b/) || (/(einstieg|reinig|bezirk)/.test(t) && t.match(/\b(west|ost)\b/));
  if (bezirk) add('einstiegserlaubnis.bezirk', bezirk[1] === 'west' ? 'West' : 'Ost');

  const temp = text.match(/(-?\d{1,2})\s*(?:°\s*c?|grad)/i);
  if (temp) add('temperatur', `${temp[1]} °C`);

  const wetter = WETTER.find((w) => new RegExp(`\\b${w}\\b`).test(t));
  if (wetter) add('wetter', wetter === 'sonne' ? 'sonnig' : wetter);

  const termin = text.match(/termin\w*\s*(?:ist\s*|am\s*|:\s*)?(\d{1,2}\.\d{1,2}\.\d{4})/i);
  if (termin) {
    add('ausfuehrungstermin', termin[1]);
    add('terminauftrag', true);
  }

  const personal = text.match(/personal\s*(?:ist|sind|:)?\s*([A-ZÄÖÜ][\wäöüß-]+(?:\s*(?:,|und)\s*[A-ZÄÖÜ][\wäöüß-]+)*)/);
  if (personal) add('personal', personal[1].split(/\s*(?:,|und)\s*/));

  const stand = t.match(/(?:stand|status|auftrag ist)\s*:?\s*(neu|in arbeit|abgeschlossen)/);
  if (stand) add('bearbeitungsstand', stand[1]);

  const arbeit = text.match(/arbeit\s*:\s*(.+?)(?:\.|$)/i);
  if (arbeit) add(`objekte.${objektIndex(auftrag)}.arbeit`, arbeit[1].trim());

  return aenderungen;
}

const AUFGABE = /^(bitte\s+)?(erstell|mach|schreib|bereite|berechne|plan|erzeug|liste|ermittl|stell|gib mir|kannst du|könntest du|ich brauche|wir brauchen|bestell|organisier|druck|exportier|sende|schick)/i;

/**
 * @param {string} text
 * @param {object} auftrag
 * @param {{name: string, stichworte?: string[]}[]} werkstattWerkzeuge  freigegebene Werkstatt-Werkzeuge
 */
export function verstehe(text = '', auftrag = {}, werkstattWerkzeuge = []) {
  const t = text.toLowerCase();
  const schritte = [];

  const aenderungen = erkenneFelder(text, auftrag);
  if (aenderungen.length) schritte.push({ werkzeug: 'felder_setzen', parameter: { aenderungen } });

  if (/einstiegserlaubnis/.test(t) && /(antrag|vorbereit|beantrag|ausfüll|anlegen|erstell)/.test(t))
    schritte.push({ werkzeug: 'einstiegserlaubnis_vorbereiten', parameter: {} });
  if (/(reinig|spül|inspektion|befahr|tv-?untersuch)/.test(t) && /(anfrag|bestell|beauftrag|brauch|anford|meldeschein|vorher)/.test(t))
    schritte.push({ werkzeug: 'reinigung_anfragen', parameter: { art: /(inspektion|befahr|tv)/.test(t) ? 'inspektion' : 'reinigung' } });
  else if (/meldeschein/.test(t) && /(entw|erstell|schreib|mach|vorbereit|formulier)/.test(t))
    schritte.push({ werkzeug: 'meldeschein_entwerfen', parameter: { wunsch: text } });
  if (/(fehl|offen|vollständig|unvollständig|prüf)/.test(t) && /(angabe|feld|auftrag|daten|was)/.test(t))
    schritte.push({ werkzeug: 'fehlende_angaben', parameter: {} });
  if (/(zusammenfass|fass\b.*zusammen|überblick|kurzfassung)/.test(t)) schritte.push({ werkzeug: 'auftrag_zusammenfassen', parameter: {} });

  for (const w of werkstattWerkzeuge) {
    if ((w.stichworte || []).some((s) => s && t.includes(String(s).toLowerCase()))) schritte.push({ werkzeug: w.name, parameter: {} });
  }

  // Klingt wie ein Arbeitsauftrag, aber kein Werkzeug passt → Lücke für die Werkstatt.
  const luecke = schritte.length === 0 && AUFGABE.test(text.trim()) ? text.trim() : null;
  return { schritte, luecke };
}

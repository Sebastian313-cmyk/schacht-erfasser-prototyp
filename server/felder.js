// Auftragsfelder, die KI31 und Werkstatt-Werkzeuge lesen oder ändern dürfen.
// Alles, was nicht in dieser Liste steht, ist für KI31 tabu. Werte werden geprüft und vereinheitlicht.

import { OBJEKTARTEN } from './organisation.js';

export const FELDER = {
  auftragsnummer: { titel: 'Auftragsnummer', typ: 'text' },
  auftragsart: { titel: 'Auftragsart', typ: 'auswahl', werte: ['Maurer', 'Sanierung'] },
  strasse: { titel: 'Straße', typ: 'text' },
  hausnummer: { titel: 'Hausnummer', typ: 'text' },
  weitergebendeAbteilung: { titel: 'Weitergebende Abteilung', typ: 'text' },
  eingangsdatum: { titel: 'Eingangsdatum', typ: 'datum' },
  terminauftrag: { titel: 'Terminauftrag', typ: 'janein' },
  ausfuehrungstermin: { titel: 'Ausführungstermin', typ: 'datum' },
  bearbeitungsstand: { titel: 'Bearbeitungsstand', typ: 'auswahl', werte: ['neu', 'in Arbeit', 'abgeschlossen'] },
  wetter: { titel: 'Wetter', typ: 'text' },
  temperatur: { titel: 'Temperatur', typ: 'text' },
  notizen: { titel: 'Notizen', typ: 'text' },
  personal: { titel: 'Personal', typ: 'liste' },
  'einstiegserlaubnis.erforderlich': { titel: 'Einstiegserlaubnis erforderlich', typ: 'janein' },
  'einstiegserlaubnis.bezirk': { titel: 'Bezirk', typ: 'auswahl', werte: ['West', 'Ost'] },
  'objekte.*.objektart': { titel: 'Objektart', typ: 'auswahl', werte: OBJEKTARTEN },
  'objekte.*.objektId': { titel: 'Objekt-ID', typ: 'text' },
  'objekte.*.dn': { titel: 'DN', typ: 'text' },
  'objekte.*.befund': { titel: 'Befund', typ: 'text' },
  'objekte.*.arbeit': { titel: 'Arbeit', typ: 'text' }
};

const MAX_OBJEKTE = 20;

export function feldDefinition(feld) {
  if (typeof feld !== 'string') return null;
  const m = feld.match(/^objekte\.(\d+)\.(\w+)$/);
  if (m) return Number(m[1]) < MAX_OBJEKTE ? FELDER[`objekte.*.${m[2]}`] || null : null;
  return FELDER[feld] || null;
}

export function feldTitel(feld) {
  const d = feldDefinition(feld);
  if (!d) return feld;
  const m = feld.match(/^objekte\.(\d+)\./);
  return m ? `Objekt ${Number(m[1]) + 1}: ${d.titel}` : d.titel;
}

export function lese(auftrag, feld) {
  return feld.split('.').reduce((o, teil) => (o == null ? undefined : o[teil]), auftrag);
}

export function setze(auftrag, feld, wert) {
  const teile = feld.split('.');
  let o = auftrag;
  for (let i = 0; i < teile.length - 1; i++) {
    const naechstesIstIndex = /^\d+$/.test(teile[i + 1]);
    if (o[teile[i]] == null) o[teile[i]] = naechstesIstIndex ? [] : {};
    o = o[teile[i]];
  }
  o[teile.at(-1)] = wert;
  return auftrag;
}

/** Prüft und vereinheitlicht einen Wert. */
export function validiere(feld, wert) {
  const d = feldDefinition(feld);
  if (!d) return { ok: false, fehler: `Feld „${feld}“ darf nicht geändert werden.` };
  switch (d.typ) {
    case 'text': {
      const t = String(wert ?? '').trim();
      return t.length > 2000 ? { ok: false, fehler: 'Text zu lang.' } : { ok: true, wert: t };
    }
    case 'auswahl': {
      const treffer = d.werte.find((w) => w.toLowerCase() === String(wert ?? '').trim().toLowerCase());
      return treffer ? { ok: true, wert: treffer } : { ok: false, fehler: `Erlaubt sind: ${d.werte.join(', ')}.` };
    }
    case 'janein': {
      if (wert === true || /^(ja|true|erforderlich)$/i.test(String(wert))) return { ok: true, wert: true };
      if (wert === false || /^(nein|false|nicht erforderlich)$/i.test(String(wert))) return { ok: true, wert: false };
      return { ok: false, fehler: 'Erwartet ja oder nein.' };
    }
    case 'datum': {
      const s = String(wert ?? '').trim();
      let m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
      if (m) return { ok: true, wert: s };
      m = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/);
      if (m) return { ok: true, wert: `${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}` };
      return { ok: false, fehler: 'Datum als TT.MM.JJJJ angeben.' };
    }
    case 'liste': {
      const liste = Array.isArray(wert) ? wert : String(wert ?? '').split(',');
      return { ok: true, wert: liste.map((x) => String(x).trim()).filter(Boolean) };
    }
    default:
      return { ok: false, fehler: 'Unbekannter Feldtyp.' };
  }
}

/**
 * Prüft eine Liste gewünschter Änderungen gegen den Auftrag.
 * Ändert den Auftrag NICHT – das Ergebnis ist ein Vorschlag zur Bestätigung.
 */
export function pruefeAenderungen(auftrag, aenderungen = []) {
  const gueltig = [];
  const ungueltig = [];
  for (const a of Array.isArray(aenderungen) ? aenderungen : []) {
    const v = validiere(a?.feld, a?.wert);
    if (!v.ok) {
      ungueltig.push({ feld: a?.feld, wert: a?.wert, fehler: v.fehler });
      continue;
    }
    const alt = lese(auftrag, a.feld);
    if (JSON.stringify(alt ?? '') === JSON.stringify(v.wert)) continue; // keine echte Änderung
    gueltig.push({ feld: a.feld, titel: feldTitel(a.feld), alt: alt ?? '', neu: v.wert });
  }
  return { aenderungen: gueltig, ungueltig };
}

export function wendeAn(auftrag, aenderungen = []) {
  const kopie = structuredClone(auftrag);
  for (const a of aenderungen) setze(kopie, a.feld, a.neu);
  return kopie;
}

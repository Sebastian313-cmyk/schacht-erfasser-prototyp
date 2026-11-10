// Werkzeugwerkstatt: Hier erweitern sich die Fachagenten selbst – unter Kontrolle.
//
// Ablauf:  Vorschlag → Entwurf → Test mit fiktiven Testdaten → Freigabe durch 31C → Nutzung
//          (jederzeit widerrufbar, jede Version bleibt nachvollziehbar)
//
// Sicherheit: Ein Werkstatt-Werkzeug ist KEIN Programmcode, sondern eine Beschreibung aus sicheren
// Bausteinen (Textvorlage, Prüfregeln, Feldänderungen). Der Interpreter unten führt nur diese Bausteine
// aus. Feldänderungen sind immer Vorschläge, die ein Mensch bestätigt.

import { readFile } from 'node:fs/promises';
import { FELDER, feldDefinition, lese, pruefeAenderungen, validiere } from './felder.js';
import * as speicher from './speicher.js';

export const ARTEN = {
  vorlage: 'Textvorlage – erzeugt einen Text aus Auftragsangaben',
  pruefung: 'Prüfregeln – meldet fehlende oder auffällige Angaben',
  felder: 'Feldänderungen – schlägt Werte für Auftragsfelder vor'
};
export const BEDINGUNGEN = ['leer', 'nicht_leer', 'gleich', 'enthaelt'];
export const AGENT_KENNUNGEN = ['311', '312', '313'];
const STUFEN = ['fehlt', 'klaeren', 'empfohlen'];

// ------------------------------------------------------------------ Ablage

export async function lade() {
  return (await speicher.ladeJson('werkstatt.json')) || [];
}
async function speichere(liste) {
  await speicher.speichereJson('werkstatt.json', liste);
}
async function aendere(id, fn) {
  const liste = await lade();
  const e = liste.find((x) => x.id === id);
  if (!e) throw new WerkstattFehler('Werkstatt-Eintrag nicht gefunden.', 404);
  await fn(e);
  await speichere(liste);
  return e;
}
const vermerk = (e, aktion, rolle) => e.verlauf.push({ zeit: new Date().toISOString(), aktion, rolle });

export class WerkstattFehler extends Error {
  constructor(text, status = 400) {
    super(text);
    this.status = status;
  }
}

export async function freigegebene() {
  return (await lade()).filter((e) => e.status === 'freigegeben');
}

// ------------------------------------------------------------------ Vorlagen-Platzhalter

const PLATZHALTER = /\{\{\s*([\w.]+)\s*\}\}/g;
const platzhalterErlaubt = (p) => p === 'heute' || Boolean(feldDefinition(p));

function fuelleVorlage(vorlage, auftrag) {
  return vorlage.replace(PLATZHALTER, (_, p) => {
    if (p === 'heute') return new Date().toISOString().slice(0, 10);
    const w = lese(auftrag, p);
    if (w === true) return 'ja';
    if (w === false) return 'nein';
    if (Array.isArray(w)) return w.join(', ');
    return w == null || w === '' ? '–' : String(w);
  });
}

// ------------------------------------------------------------------ Prüfung der Beschreibung

export function pruefeSpec(spec, { belegteNamen = [] } = {}) {
  const fehler = [];
  if (!spec || typeof spec !== 'object') return ['Beschreibung fehlt.'];
  if (!/^ws_[a-z0-9_]{3,40}$/.test(spec.name || '')) fehler.push('name: nur Kleinbuchstaben, Ziffern, _ und mit „ws_“ beginnend.');
  if (belegteNamen.includes(spec.name)) fehler.push(`name: „${spec.name}“ ist schon vergeben.`);
  if (!spec.titel || String(spec.titel).length > 80) fehler.push('titel: fehlt oder zu lang.');
  if (!AGENT_KENNUNGEN.includes(spec.agent)) fehler.push('agent: 311, 312 oder 313.');
  if (!ARTEN[spec.art]) fehler.push(`art: ${Object.keys(ARTEN).join(', ')}.`);
  if (!Array.isArray(spec.stichworte) || spec.stichworte.length === 0) fehler.push('stichworte: mindestens ein Stichwort, an dem KI31 das Werkzeug erkennt.');

  if (spec.art === 'vorlage') {
    if (typeof spec.vorlage !== 'string' || !spec.vorlage.trim()) fehler.push('vorlage: Text fehlt.');
    else if (spec.vorlage.length > 4000) fehler.push('vorlage: zu lang (max. 4000 Zeichen).');
    else for (const [, p] of spec.vorlage.matchAll(PLATZHALTER)) if (!platzhalterErlaubt(p)) fehler.push(`vorlage: Platzhalter {{${p}}} ist nicht erlaubt.`);
  }
  if (spec.art === 'pruefung') {
    if (!Array.isArray(spec.regeln) || spec.regeln.length === 0) fehler.push('regeln: mindestens eine Regel.');
    else
      spec.regeln.forEach((r, i) => {
        if (!feldDefinition(r.feld)) fehler.push(`regeln[${i}].feld: „${r.feld}“ ist kein erlaubtes Feld.`);
        if (!BEDINGUNGEN.includes(r.bedingung)) fehler.push(`regeln[${i}].bedingung: ${BEDINGUNGEN.join(', ')}.`);
        if (!r.meldung) fehler.push(`regeln[${i}].meldung fehlt.`);
        if (r.stufe && !STUFEN.includes(r.stufe)) fehler.push(`regeln[${i}].stufe: ${STUFEN.join(', ')}.`);
      });
  }
  if (spec.art === 'felder') {
    if (!Array.isArray(spec.aenderungen) || spec.aenderungen.length === 0) fehler.push('aenderungen: mindestens eine Änderung.');
    else
      spec.aenderungen.forEach((a, i) => {
        const v = validiere(a.feld, a.wert);
        if (!v.ok) fehler.push(`aenderungen[${i}]: ${v.fehler}`);
      });
  }
  if (!Array.isArray(spec.tests) || spec.tests.length === 0) fehler.push('tests: mindestens ein Testfall mit fiktivem Testauftrag.');
  return fehler;
}

// ------------------------------------------------------------------ Interpreter

/** Führt ein Werkstatt-Werkzeug aus. Ändert den Auftrag nicht. */
export function fuehreAus(spec, auftrag) {
  if (spec.art === 'vorlage') return { text: fuelleVorlage(spec.vorlage, auftrag) };
  if (spec.art === 'pruefung') {
    const regeln = [];
    for (const r of spec.regeln) {
      const w = lese(auftrag, r.feld);
      const leer = w == null || w === '' || (Array.isArray(w) && w.length === 0);
      const text = String(w ?? '').toLowerCase();
      const ziel = String(r.wert ?? '').toLowerCase();
      const trifft =
        (r.bedingung === 'leer' && leer) ||
        (r.bedingung === 'nicht_leer' && !leer) ||
        (r.bedingung === 'gleich' && text === ziel) ||
        (r.bedingung === 'enthaelt' && ziel !== '' && text.includes(ziel));
      if (trifft) regeln.push({ feld: r.feld, stufe: r.stufe || 'klaeren', text: fuelleVorlage(r.meldung, auftrag) });
    }
    return { regeln, hinweise: [] };
  }
  if (spec.art === 'felder') {
    const gewuenscht = spec.aenderungen.map((a) => ({ feld: a.feld, wert: typeof a.wert === 'string' ? fuelleVorlage(a.wert, auftrag) : a.wert }));
    return pruefeAenderungen(auftrag, gewuenscht);
  }
  throw new WerkstattFehler(`Unbekannte Art: ${spec.art}`);
}

// ------------------------------------------------------------------ Testen

async function testauftraege() {
  return JSON.parse(await readFile(new URL('../data/beispiel-auftraege.json', import.meta.url), 'utf8'));
}

export async function testeSpec(spec) {
  const auftraege = await testauftraege();
  const faelle = [];
  for (const [i, t] of (spec.tests || []).entries()) {
    const auftrag = auftraege.find((a) => a.id === t.auftragId);
    const fall = { nr: i + 1, auftragId: t.auftragId, ok: true, meldungen: [] };
    faelle.push(fall);
    if (!auftrag) {
      fall.ok = false;
      fall.meldungen.push(`Testauftrag „${t.auftragId}“ gibt es nicht. Verfügbar: ${auftraege.map((a) => a.id).join(', ')}`);
      continue;
    }
    let ergebnis;
    try {
      ergebnis = fuehreAus(spec, auftrag);
    } catch (f) {
      fall.ok = false;
      fall.meldungen.push(`Fehler bei der Ausführung: ${f.message}`);
      continue;
    }
    fall.ergebnis = ergebnis;
    const e = t.erwartet || {};
    const gesamtText = ergebnis.text ?? (ergebnis.regeln || []).map((r) => r.text).join('\n');
    for (const s of e.enthaelt || []) {
      if (!gesamtText.includes(s)) {
        fall.ok = false;
        fall.meldungen.push(`Erwartet „${s}“ im Ergebnis.`);
      }
    }
    for (const s of e.enthaeltNicht || []) {
      if (gesamtText.includes(s)) {
        fall.ok = false;
        fall.meldungen.push(`„${s}“ darf nicht im Ergebnis stehen.`);
      }
    }
    if (Number.isInteger(e.anzahlBefunde) && (ergebnis.regeln || []).length !== e.anzahlBefunde) {
      fall.ok = false;
      fall.meldungen.push(`Erwartet ${e.anzahlBefunde} Befunde, erhalten ${(ergebnis.regeln || []).length}.`);
    }
    for (const a of e.aenderungen || []) {
      if (!(ergebnis.aenderungen || []).some((x) => x.feld === a.feld && JSON.stringify(x.neu) === JSON.stringify(a.wert))) {
        fall.ok = false;
        fall.meldungen.push(`Erwartet Änderung ${a.feld} = ${JSON.stringify(a.wert)}.`);
      }
    }
    if (fall.ok) fall.meldungen.push('bestanden');
  }
  return { zeit: new Date().toISOString(), bestanden: faelle.length > 0 && faelle.every((f) => f.ok), faelle };
}

// ------------------------------------------------------------------ Lebenszyklus

export async function vorschlagAnlegen({ anliegen, agent, grund, auftragId }) {
  const liste = await lade();
  // Gleiches offenes Anliegen nicht doppelt anlegen.
  const vorhanden = liste.find((e) => e.anliegen === anliegen && ['vorschlag', 'entwurf', 'geprueft'].includes(e.status));
  if (vorhanden) return vorhanden;
  const e = {
    id: crypto.randomUUID(),
    status: 'vorschlag',
    version: 0,
    agent,
    anliegen,
    grund: grund || 'Kein passendes Werkzeug vorhanden.',
    beispielAuftrag: auftragId || null,
    erstellt: new Date().toISOString(),
    spec: null,
    testergebnis: null,
    freigabe: null,
    verlauf: []
  };
  vermerk(e, `Vorschlag von Agent ${agent}: ${e.grund}`, 'KI31');
  liste.push(e);
  await speichere(liste);
  return e;
}

export async function entwurfSpeichern(id, spec, rolle) {
  const alle = await lade();
  const belegteNamen = alle.filter((x) => x.id !== id && x.spec && x.status !== 'widerrufen').map((x) => x.spec.name);
  const fehler = pruefeSpec(spec, { belegteNamen });
  if (fehler.length) throw Object.assign(new WerkstattFehler('Die Beschreibung ist noch nicht gültig.'), { details: fehler });
  return aendere(id, (e) => {
    if (e.status === 'freigegeben') throw new WerkstattFehler('Ein freigegebenes Werkzeug wird nicht direkt geändert. Erst widerrufen.');
    e.spec = spec;
    e.status = 'entwurf';
    e.version += 1;
    e.testergebnis = null;
    e.freigabe = null;
    vermerk(e, `Entwurf Version ${e.version} gespeichert`, rolle);
  });
}

export async function testen(id, rolle) {
  const e0 = (await lade()).find((x) => x.id === id);
  if (!e0?.spec) throw new WerkstattFehler('Es gibt noch keinen Entwurf zum Testen.');
  const ergebnis = await testeSpec(e0.spec);
  return aendere(id, (e) => {
    e.testergebnis = ergebnis;
    if (e.status !== 'freigegeben') e.status = ergebnis.bestanden ? 'geprueft' : 'entwurf';
    vermerk(e, ergebnis.bestanden ? 'Tests bestanden' : 'Tests nicht bestanden', rolle);
  });
}

export async function freigeben(id, { rollen, rolle }) {
  const erlaubt = ['fuehrungskraft', 'mitarbeitende'];
  const fuer = (Array.isArray(rollen) ? rollen : []).filter((r) => erlaubt.includes(r));
  if (fuer.length === 0) throw new WerkstattFehler('Mindestens eine Rolle für die Nutzung wählen.');
  return aendere(id, (e) => {
    if (e.status !== 'geprueft' || !e.testergebnis?.bestanden) throw new WerkstattFehler('Nur geprüfte Werkzeuge mit bestandenen Tests können freigegeben werden.');
    e.status = 'freigegeben';
    e.freigabe = { rollen: fuer, durch: rolle, zeit: new Date().toISOString(), version: e.version };
    vermerk(e, `Freigegeben für ${fuer.join(', ')} (Version ${e.version})`, rolle);
  });
}

export async function widerrufen(id, rolle) {
  return aendere(id, (e) => {
    e.status = 'widerrufen';
    vermerk(e, 'Freigabe widerrufen', rolle);
  });
}

export async function verwerfen(id, rolle) {
  return aendere(id, (e) => {
    if (e.status === 'freigegeben') throw new WerkstattFehler('Erst widerrufen.');
    e.status = 'verworfen';
    vermerk(e, 'Verworfen', rolle);
  });
}

/** Nimmt einen widerrufenen oder verworfenen Eintrag wieder in Arbeit. */
export async function wiederAufnehmen(id, rolle) {
  return aendere(id, (e) => {
    if (!['widerrufen', 'verworfen'].includes(e.status)) throw new WerkstattFehler('Nur widerrufene oder verworfene Einträge.');
    e.status = e.spec ? 'entwurf' : 'vorschlag';
    e.testergebnis = null;
    e.freigabe = null;
    vermerk(e, 'Wieder in Arbeit genommen', rolle);
  });
}

// ------------------------------------------------------------------ Entwurf durch den Agenten

/** Beschreibung, die dem Sprachmodell erklärt, wie ein Werkstatt-Werkzeug aussieht. */
export function bauanleitung() {
  const felder = Object.keys(FELDER).join(', ');
  return `Ein Werkstatt-Werkzeug ist eine JSON-Beschreibung, kein Programmcode.
Pflichtangaben: name (beginnt mit ws_, nur a-z 0-9 _), titel, beschreibung, agent (311|312|313),
stichworte (Wörter, an denen KI31 das Anliegen erkennt), art, tests.
art "vorlage": Feld "vorlage" mit Text und Platzhaltern {{feld}} oder {{heute}}.
art "pruefung": Feld "regeln": [{feld, bedingung (leer|nicht_leer|gleich|enthaelt), wert, meldung, stufe (fehlt|klaeren|empfohlen)}].
art "felder": Feld "aenderungen": [{feld, wert}] – Vorschläge, die ein Mensch bestätigt.
Erlaubte Felder: ${felder}; Objektfelder als objekte.0.objektId usw.
tests: [{auftragId, erwartet: {enthaelt: [..], enthaeltNicht: [..], anzahlBefunde: n, aenderungen: [{feld, wert}]}}].
Testaufträge (fiktiv): test-001 (Einstieg E-TEST-4711, Ahornweg 12), test-002 (Kanal K-TEST-0815, Lindenstraße, Terminauftrag ohne Termin), test-003 (Straßensinkkasten ohne Objekt-ID, Am Mühlbach 3, ohne Auftragsnummer).`;
}

/** Einfacher Entwurf ohne Sprachmodell (Demo-Modus): eine Textvorlage zum Anliegen. */
export function grundentwurf(eintrag) {
  const stichworte = String(eintrag.anliegen)
    .toLowerCase()
    .replace(/[^a-zäöüß0-9 ]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length > 5 && !['bitte', 'kannst', 'erstelle', 'schreib', 'mache'].includes(w))
    .slice(0, 3);
  const kurz = String(eintrag.anliegen).replace(/\s+/g, ' ').trim().slice(0, 60);
  return {
    name: `ws_${(stichworte[0] || 'werkzeug').replace(/[^a-z0-9]/g, '').slice(0, 20) || 'werkzeug'}_${eintrag.id.slice(0, 4)}`,
    titel: kurz,
    beschreibung: `Grundentwurf zum Anliegen: ${eintrag.anliegen}`,
    agent: eintrag.agent,
    stichworte: stichworte.length ? stichworte : ['werkzeug'],
    art: 'vorlage',
    vorlage:
      `${kurz}\n` +
      'Auftrag: {{auftragsnummer}} ({{auftragsart}})\n' +
      'Ort: {{strasse}} {{hausnummer}}\n' +
      'Objekt: {{objekte.0.objektart}} {{objekte.0.objektId}}\n' +
      'Befund: {{objekte.0.befund}}\n' +
      'Erstellt am {{heute}} – Entwurf, bitte prüfen.',
    tests: [{ auftragId: 'test-001', erwartet: { enthaelt: ['BU-M-TEST-2026-0142', 'Ahornweg'] } }]
  };
}

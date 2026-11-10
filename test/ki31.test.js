import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

// Gefälschter Ollama-Server, damit die Modellanbindung ohne echtes Modell getestet wird.
let ollamaAntwort = {};
let ollamaPlan = { schritte: [], luecke: '', antwort: '' };
let ollamaWerkzeug = null;
const ollamaAnfragen = [];
const ollama = createServer(async (req, res) => {
  let text = '';
  for await (const s of req) text += s;
  if (req.url === '/api/tags') {
    res.end(JSON.stringify({ models: [{ name: 'testmodell:latest' }] }));
    return;
  }
  const body = JSON.parse(text);
  ollamaAnfragen.push(body);
  if (body.stream) {
    res.write(JSON.stringify({ message: { content: 'Hallo ' } }) + '\n');
    res.write(JSON.stringify({ message: { content: 'aus dem Modell.' } }) + '\n');
    res.end(JSON.stringify({ done: true }) + '\n');
  } else {
    const istPlan = Boolean(body.format?.properties?.schritte);
    const istWerkstatt = /Werkstatt/.test(body.messages[0].content);
    const inhalt = istPlan ? ollamaPlan : istWerkstatt ? ollamaWerkzeug : ollamaAntwort;
    res.end(JSON.stringify({ message: { content: typeof inhalt === 'string' ? inhalt : JSON.stringify(inhalt) } }));
  }
});

let server;
let basis;
let datenordner;

before(async () => {
  await new Promise((r) => ollama.listen(0, '127.0.0.1', r));
  datenordner = await mkdtemp(path.join(tmpdir(), 'ki31-test-'));
  process.env.KI31_OLLAMA_URL = `http://127.0.0.1:${ollama.address().port}`;
  process.env.KI31_MODELL = 'testmodell';
  process.env.KI31_DATEN = datenordner;
  const { bearbeite } = await import('../server/server.js');
  server = createServer(bearbeite);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  basis = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  server.close();
  ollama.close();
  await rm(datenordner, { recursive: true, force: true });
});

const anfrage = (pfad, { rolle = 'fuehrungskraft', daten, methode } = {}) =>
  fetch(basis + pfad, {
    method: methode || (daten ? 'POST' : 'GET'),
    headers: { 'content-type': 'application/json', 'x-ki31-rolle': rolle },
    body: daten ? JSON.stringify(daten) : undefined
  });

const beispiele = async () => JSON.parse(await readFile(new URL('../data/beispiel-auftraege.json', import.meta.url), 'utf8'));

test('Prüfregeln erkennen fehlende Pflichtangaben', async () => {
  const { pruefeAuftrag } = await import('../server/regeln.js');
  const [, zweiter, dritter] = await beispiele();
  const r2 = pruefeAuftrag(zweiter).map((r) => r.feld);
  assert.ok(r2.includes('ausfuehrungstermin'), 'Terminauftrag ohne Termin');
  assert.ok(r2.includes('objekte.0.dn'), 'Kanal ohne DN');
  assert.ok(r2.includes('einstiegserlaubnis'), 'Einstiegserlaubnis ungeklärt');
  const r3 = pruefeAuftrag(dritter).map((r) => r.feld);
  assert.ok(r3.includes('auftragsnummer'));
  assert.ok(r3.includes('objekte.0.objektId'));
  assert.ok(!r3.includes('einstiegserlaubnis'), 'Sinkkasten braucht keine Klärung');
});

test('Fachagent wird nach Stichworten gewählt', async () => {
  const { waehleAgent } = await import('../server/agenten.js');
  assert.equal(waehleAgent('Brauchen wir eine Einstiegserlaubnis und Arbeitssicherheit?'), '311');
  assert.equal(waehleAgent('Muss vorher gespült und eine Inspektion gemacht werden?'), '312');
  assert.equal(waehleAgent('Hallo'), '313');
});

test('Verstehen ohne Modell: Sätze werden zu Arbeitsschritten', async () => {
  const { verstehe } = await import('../server/verstehen.js');
  const [, kanalAuftrag] = await beispiele();
  const p = verstehe('DN ist 300, Bezirk Ost, Einstiegserlaubnis brauchen wir. Termin am 20.11.2026', kanalAuftrag);
  const felder = p.schritte.find((s) => s.werkzeug === 'felder_setzen').parameter.aenderungen;
  assert.deepEqual(felder.find((a) => a.feld === 'objekte.0.dn'), { feld: 'objekte.0.dn', wert: '300' });
  assert.ok(felder.some((a) => a.feld === 'einstiegserlaubnis.bezirk' && a.wert === 'Ost'));
  assert.ok(felder.some((a) => a.feld === 'einstiegserlaubnis.erforderlich' && a.wert === true));
  assert.ok(felder.some((a) => a.feld === 'ausfuehrungstermin' && a.wert === '20.11.2026'));
  assert.equal(verstehe('Bitte entwirf einen Meldeschein').schritte[0].werkzeug, 'meldeschein_entwerfen');
  assert.equal(verstehe('Wir brauchen vorher eine TV-Inspektion, bitte anfragen').schritte[0].parameter.art, 'inspektion');
  assert.equal(verstehe('Fass den Auftrag zusammen').schritte[0].werkzeug, 'auftrag_zusammenfassen');
  assert.equal(verstehe('Erstelle eine Materialliste für die Baustelle').luecke, 'Erstelle eine Materialliste für die Baustelle');
  assert.equal(verstehe('Wie ist das Wetter?').luecke, null);
});

test('Feldänderungen werden geprüft und nur vorgeschlagen', async () => {
  const { pruefeAenderungen } = await import('../server/felder.js');
  const [auftrag] = await beispiele();
  const r = pruefeAenderungen(auftrag, [
    { feld: 'einstiegserlaubnis.bezirk', wert: 'ost' },
    { feld: 'ausfuehrungstermin', wert: '1.12.2026' },
    { feld: 'id', wert: 'gehackt' },
    { feld: 'auftragsart', wert: 'Bagger' },
    { feld: 'strasse', wert: 'Ahornweg' }
  ]);
  assert.deepEqual(r.aenderungen.map((a) => [a.feld, a.neu]), [['einstiegserlaubnis.bezirk', 'Ost'], ['ausfuehrungstermin', '2026-12-01']]);
  assert.equal(r.ungueltig.length, 2, 'unerlaubtes Feld und ungültiger Wert');
  assert.equal(auftrag.einstiegserlaubnis.bezirk, '', 'Auftrag selbst bleibt unverändert');
});

test('Meldeschein-Entwurf: ungültige Werte werden bereinigt, Prüfregeln ergänzt', async () => {
  const [auftrag] = await beispiele();
  ollamaAntwort = {
    empfaenger: 'Erfundene Abteilung',
    angeforderteLeistung: ' Rahmen neu setzen ',
    begruendung: 'Rahmen gerissen',
    dringlichkeit: 'irgendwann',
    ortsangabe: 'Ahornweg 12',
    objektbezug: 'Einstieg E-TEST-4711',
    hinweise: ['Busverkehr beachten'],
    offenePunkte: []
  };
  const res = await anfrage('/api/ki/werkzeug', { daten: { werkzeug: 'meldeschein_entwerfen', auftrag } });
  assert.equal(res.status, 200);
  const { modus, ergebnis } = await res.json();
  assert.equal(modus, 'ollama');
  const ms = ergebnis.meldeschein;
  assert.equal(ms.empfaenger, '', 'unbekannter Empfänger wird verworfen');
  assert.equal(ms.dringlichkeit, 'normal');
  assert.equal(ms.angeforderteLeistung, 'Rahmen neu setzen');
  assert.ok(ms.offenePunkte.some((p) => p.includes('Einstiegserlaubnis')), 'Regel zur Einstiegserlaubnis ergänzt');
  const letzte = ollamaAnfragen.at(-1);
  assert.equal(letzte.model, 'testmodell');
  assert.ok(letzte.format?.properties?.empfaenger, 'JSON-Schema wird an Ollama übergeben');
  assert.match(letzte.messages[0].content, /E-TEST-4711/, 'Auftragsdaten stehen im Kontext');
});

test('31C: Mitarbeitende dürfen keinen Meldeschein entwerfen oder übernehmen', async () => {
  const [auftrag] = await beispiele();
  const r1 = await anfrage('/api/ki/werkzeug', { rolle: 'mitarbeitende', daten: { werkzeug: 'meldeschein_entwerfen', auftrag } });
  assert.equal(r1.status, 403);
  const r2 = await anfrage('/api/meldescheine', { rolle: 'mitarbeitende', daten: { meldeschein: {}, auftragId: auftrag.id } });
  assert.equal(r2.status, 403);
  const r3 = await anfrage('/api/ki/werkzeug', { rolle: 'mitarbeitende', daten: { werkzeug: 'fehlende_angaben', auftrag } });
  assert.equal(r3.status, 200);
});

const lesen = async (res) => (await res.text()).trim().split('\n').map((z) => JSON.parse(z));

test('Gehirn: Modellplan wird an Agenten verteilt, unbekannte Werkzeuge verworfen', async () => {
  const [, auftrag] = await beispiele();
  ollamaPlan = {
    schritte: [
      { werkzeug: 'felder_setzen', parameter: { aenderungen: [{ feld: 'objekte.0.dn', wert: '300' }, { feld: 'einstiegserlaubnis.bezirk', wert: 'Ost' }] } },
      { werkzeug: 'einstiegserlaubnis_vorbereiten', parameter: {} },
      { werkzeug: 'datenbank_loeschen', parameter: {} }
    ],
    luecke: '',
    antwort: ''
  };
  const e = await lesen(await anfrage('/api/ki31/anliegen', { daten: { anliegen: 'DN 300, Bezirk Ost, Antrag vorbereiten', auftrag } }));
  const werkzeuge = e.filter((x) => x.typ === 'werkzeug');
  assert.deepEqual(werkzeuge.map((w) => [w.werkzeug, w.agent]), [['felder_setzen', 'KI31'], ['einstiegserlaubnis_vorbereiten', '311']]);
  assert.equal(werkzeuge[0].ergebnis.aenderungen.length, 2);
  assert.equal(werkzeuge[1].ergebnis.antrag.bezirk, 'Ost', 'Agent 311 arbeitet mit den vorgeschlagenen Werten weiter');
  assert.ok(e.some((x) => x.typ === 'naechster'));
  assert.equal(e.at(-1).typ, 'ende');
});

test('Gehirn: reine Frage wird beantwortet, 31C sperrt Werkzeuge für Mitarbeitende', async () => {
  const [auftrag] = await beispiele();
  ollamaPlan = { schritte: [], luecke: '', antwort: '' };
  const e1 = await lesen(await anfrage('/api/ki31/anliegen', { daten: { anliegen: 'Was ist hier los?', auftrag } }));
  assert.equal(e1.filter((x) => x.typ === 'text').map((x) => x.text).join(''), 'Hallo aus dem Modell.');

  ollamaPlan = { schritte: [{ werkzeug: 'meldeschein_entwerfen', parameter: {} }], luecke: '', antwort: '' };
  const e2 = await lesen(await anfrage('/api/ki31/anliegen', { rolle: 'mitarbeitende', daten: { anliegen: 'Meldeschein bitte', auftrag } }));
  assert.ok(!e2.some((x) => x.typ === 'werkzeug'));
  assert.ok(e2.some((x) => x.typ === 'text' && /nicht freigegeben \(31C\)/.test(x.text)));
});

test('Werkstatt: Lücke → Entwurf → Test → Freigabe durch 31C → Nutzung → Widerruf', async () => {
  const [auftrag] = await beispiele();
  ollamaPlan = { schritte: [], luecke: 'Materialliste für die Baustelle erstellen', antwort: '' };
  ollamaWerkzeug = {
    name: 'materialliste',
    titel: 'Materialliste Baustelle',
    beschreibung: 'Erstellt eine Materialliste',
    agent: '311',
    stichworte: ['materialliste'],
    art: 'vorlage',
    vorlage: 'Materialliste für {{auftragsnummer}} – {{objekte.0.objektart}} {{objekte.0.objektId}}: {{objekte.0.arbeit}}',
    tests: [{ auftragId: 'test-001', erwartet: { enthaelt: ['E-TEST-4711'] } }]
  };
  const e = await lesen(await anfrage('/api/ki31/anliegen', { daten: { anliegen: 'Erstelle eine Materialliste für die Baustelle', auftrag } }));
  const luecke = e.find((x) => x.typ === 'luecke');
  assert.ok(luecke, 'Lücke wird gemeldet');
  assert.equal(luecke.agent, '313', 'zuständiger Agent baut, nicht der vom Modell genannte');
  assert.equal(luecke.eintrag.status, 'geprueft');

  const liste = await (await anfrage('/api/werkstatt', { rolle: 'it31c' })).json();
  const eintrag = liste.eintraege.find((x) => x.id === luecke.eintrag.id);
  assert.equal(eintrag.spec.name, 'ws_materialliste');
  assert.equal(eintrag.spec.agent, '313');
  assert.ok(eintrag.testergebnis.bestanden);

  // Noch nicht freigegeben → nicht nutzbar
  const vorher = await (await anfrage('/api/status')).json();
  assert.ok(!vorher.werkzeuge.some((w) => w.name === 'ws_materialliste'));

  // Nur 31C darf freigeben
  assert.equal((await anfrage(`/api/werkstatt/${eintrag.id}/freigeben`, { rolle: 'fuehrungskraft', daten: { rollen: ['fuehrungskraft'] } })).status, 403);
  assert.equal((await anfrage(`/api/werkstatt/${eintrag.id}/freigeben`, { rolle: 'it31c', daten: { rollen: ['fuehrungskraft'] } })).status, 200);

  // Jetzt nutzt KI31 das Werkzeug – ohne Modellplan, über die Stichworte
  ollamaPlan = { schritte: [{ werkzeug: 'ws_materialliste', parameter: {} }], luecke: '', antwort: '' };
  const e2 = await lesen(await anfrage('/api/ki31/anliegen', { daten: { anliegen: 'Materialliste bitte', auftrag } }));
  const w = e2.find((x) => x.typ === 'werkzeug');
  assert.equal(w.quelle, 'werkstatt');
  assert.match(w.ergebnis.text, /BU-M-TEST-2026-0142 – Einstieg E-TEST-4711/);
  const e3 = await lesen(await anfrage('/api/ki31/anliegen', { rolle: 'mitarbeitende', daten: { anliegen: 'Materialliste bitte', auftrag } }));
  assert.ok(!e3.some((x) => x.typ === 'werkzeug'), 'nur für Führungskraft freigegeben');

  // Widerruf
  assert.equal((await anfrage(`/api/werkstatt/${eintrag.id}/widerrufen`, { rolle: 'it31c', daten: {} })).status, 200);
  const nachher = await (await anfrage('/api/status')).json();
  assert.ok(!nachher.werkzeuge.some((w) => w.name === 'ws_materialliste'));
});

test('Werkstatt: unsichere oder fehlerhafte Entwürfe werden abgelehnt', async () => {
  const { pruefeSpec, testeSpec } = await import('../server/werkstatt.js');
  const basis = { name: 'ws_test_x', titel: 'T', agent: '312', stichworte: ['x'], art: 'vorlage', vorlage: '{{strasse}}', tests: [{ auftragId: 'test-001', erwartet: { enthaelt: ['Ahornweg'] } }] };
  assert.deepEqual(pruefeSpec(basis), []);
  assert.ok(pruefeSpec({ ...basis, vorlage: '{{constructor.prototype}}' }).some((f) => f.includes('nicht erlaubt')));
  assert.ok(pruefeSpec({ ...basis, art: 'javascript' }).length > 0);
  assert.ok(pruefeSpec({ ...basis, agent: 'root' }).length > 0);
  assert.ok(pruefeSpec({ ...basis, art: 'felder', aenderungen: [{ feld: 'id', wert: 'x' }] }).some((f) => f.includes('darf nicht')));
  assert.ok(pruefeSpec({ ...basis, tests: [] }).length > 0);
  const t = await testeSpec({ ...basis, tests: [{ auftragId: 'test-001', erwartet: { enthaelt: ['Lindenstraße'] } }] });
  assert.equal(t.bestanden, false);
  const pruef = await testeSpec({
    ...basis, art: 'pruefung', regeln: [{ feld: 'objekte.0.objektId', bedingung: 'leer', meldung: 'Objekt-ID fehlt in {{strasse}}', stufe: 'fehlt' }],
    tests: [{ auftragId: 'test-003', erwartet: { anzahlBefunde: 1, enthaelt: ['Am Mühlbach'] } }, { auftragId: 'test-001', erwartet: { anzahlBefunde: 0 } }]
  });
  assert.equal(pruef.bestanden, true);
});

test('Übernahme speichert Meldeschein und Messung, Auswertung bildet Median', async () => {
  for (const gesamtSek of [100, 200, 300]) {
    const res = await anfrage('/api/meldescheine', {
      daten: { auftragId: 'test-001', meldeschein: { empfaenger: '313 BU-M Maurer' }, messung: { modus: 'mit KI', gesamtSek, kontrolleSek: 60, geaenderteFelder: 1, brauchbar: true } }
    });
    assert.equal(res.status, 200);
  }
  await anfrage('/api/meldescheine', { daten: { auftragId: 'test-001', meldeschein: { empfaenger: '313 BU-M Maurer' }, messung: { modus: 'ohne KI', gesamtSek: 400 } } });
  const a = await (await anfrage('/api/auswertung')).json();
  assert.equal(a.gruppen['mit KI'].anzahl, 3);
  assert.equal(a.gruppen['mit KI'].medianGesamtSek, 200);
  assert.equal(a.gruppen['ohne KI'].medianGesamtSek, 400);
});

test('Statische Dateien: kein Zugriff außerhalb von public/', async () => {
  assert.equal((await anfrage('/')).status, 200);
  assert.equal((await anfrage('/..%2Fserver%2Fserver.js')).status, 404);
});

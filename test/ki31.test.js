import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

// Gefälschter Ollama-Server, damit die Modellanbindung ohne echtes Modell getestet wird.
let ollamaAntwort = {};
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
    res.end(JSON.stringify({ message: { content: JSON.stringify(ollamaAntwort) } }));
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

test('Fachagent wird nach Stichworten und Auftrag gewählt', async () => {
  const { waehleAgent, erkenneWerkzeug } = await import('../server/agenten.js');
  assert.equal(waehleAgent('Brauchen wir eine Einstiegserlaubnis und Arbeitssicherheit?'), '311');
  assert.equal(waehleAgent('Muss vorher gespült und eine Inspektion gemacht werden?'), '312');
  assert.equal(waehleAgent('Hallo', { auftragsart: 'Maurer' }), '313');
  assert.equal(erkenneWerkzeug('Bitte entwirf einen Meldeschein'), 'meldeschein_entwerfen');
  assert.equal(erkenneWerkzeug('Welche Angaben fehlen noch?'), 'fehlende_angaben');
  assert.equal(erkenneWerkzeug('Fass den Auftrag zusammen'), 'auftrag_zusammenfassen');
  assert.equal(erkenneWerkzeug('Wie ist das Wetter?'), null);
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

test('Chat streamt Modellantwort und erkennt Werkzeuge', async () => {
  const [auftrag] = await beispiele();
  const lesen = async (res) => (await res.text()).trim().split('\n').map((z) => JSON.parse(z));
  const e1 = await lesen(await anfrage('/api/ki/chat', { daten: { auftrag, verlauf: [{ rolle: 'user', text: 'Was ist hier los?' }] } }));
  assert.equal(e1[0].typ, 'agent');
  assert.equal(e1.filter((e) => e.typ === 'text').map((e) => e.text).join(''), 'Hallo aus dem Modell.');
  assert.equal(e1.at(-1).typ, 'ende');

  ollamaAntwort = { hinweise: ['Lage des Risses genauer angeben'] };
  const e2 = await lesen(await anfrage('/api/ki/chat', { daten: { auftrag, verlauf: [{ rolle: 'user', text: 'Welche Angaben fehlen noch?' }] } }));
  const w = e2.find((e) => e.typ === 'werkzeug');
  assert.equal(w.werkzeug, 'fehlende_angaben');
  assert.deepEqual(w.ergebnis.hinweise, ['Lage des Risses genauer angeben']);
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

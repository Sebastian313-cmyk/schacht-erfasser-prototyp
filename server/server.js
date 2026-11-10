// KI31-Pilot – lokaler Server ohne externe Abhängigkeiten.
// Start: npm start   (oder: npm run demo für den Betrieb ohne Sprachmodell)

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { AGENTEN } from './agenten.js';
import { darfWerkzeug, ROLLEN } from './berechtigungen.js';
import { FELDER } from './felder.js';
import { bearbeiteAnliegen, werkstattEntwurfBauen } from './gehirn.js';
import * as ki from './ki.js';
import { DRINGLICHKEITEN, EMPFAENGER, OBJEKTARTEN } from './organisation.js';
import * as speicher from './speicher.js';
import { auswerten } from './auswertung.js';
import * as werkstatt from './werkstatt.js';
import { verfuegbar } from './werkzeuge.js';

const OEFFENTLICH = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'public');
const PORT = Number(process.env.PORT || 3131);
// Standardmäßig nur auf dem eigenen Rechner erreichbar.
const HOST = process.env.KI31_HOST || '127.0.0.1';

const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml' };

function json(res, status, daten) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(daten));
}

async function koerper(req) {
  let text = '';
  for await (const stueck of req) {
    text += stueck;
    if (text.length > 2_000_000) throw new Error('Anfrage zu groß');
  }
  return text ? JSON.parse(text) : {};
}

const rolleAus = (req) => (ROLLEN[req.headers['x-ki31-rolle']] ? req.headers['x-ki31-rolle'] : 'mitarbeitende');

export async function bearbeite(req, res) {
  const url = new URL(req.url, 'http://localhost');
  const rolle = rolleAus(req);

  try {
    if (url.pathname === '/api/status' && req.method === 'GET') {
      return json(res, 200, {
        ...(await ki.betriebsart()),
        rollen: Object.fromEntries(Object.entries(ROLLEN).map(([k, r]) => [k, r.bezeichnung])),
        agenten: Object.fromEntries(Object.entries(AGENTEN).map(([k, a]) => [k, a.name])),
        empfaenger: EMPFAENGER,
        objektarten: OBJEKTARTEN,
        dringlichkeiten: DRINGLICHKEITEN,
        werkzeuge: (await verfuegbar()).map((w) => ({ name: w.name, titel: w.titel, agent: w.agent, quelle: w.quelle, erlaubt: darfWerkzeug(rolle, w.name, w) }))
      });
    }

    if (url.pathname === '/api/auftraege' && req.method === 'GET') return json(res, 200, await speicher.ladeAuftraege());

    if (url.pathname === '/api/auftraege' && req.method === 'PUT') {
      const auftrag = await koerper(req);
      if (!auftrag.id) return json(res, 400, { fehler: 'id fehlt' });
      return json(res, 200, await speicher.speichereAuftrag(auftrag));
    }

    if (url.pathname === '/api/auftraege/zuruecksetzen' && req.method === 'POST') {
      await speicher.beispieleZuruecksetzen();
      return json(res, 200, { ok: true });
    }

    if (url.pathname === '/api/ki/werkzeug' && req.method === 'POST') {
      const { werkzeug, auftrag, parameter = {} } = await koerper(req);
      const w = (await verfuegbar()).find((x) => x.name === werkzeug);
      if (!w) return json(res, 404, { fehler: `Unbekanntes Werkzeug: ${werkzeug}` });
      if (!darfWerkzeug(rolle, w.name, w)) {
        await speicher.protokolliere({ art: 'verweigert', rolle, werkzeug });
        return json(res, 403, { fehler: `Die Rolle „${ROLLEN[rolle].bezeichnung}“ darf „${w.titel}“ nicht nutzen (31C).` });
      }
      const { modus } = await ki.betriebsart();
      const ergebnis = await w.ausfuehren({ auftrag, parameter, modus, agent: w.agent });
      await speicher.protokolliere({ art: 'werkzeug', rolle, werkzeug, agent: w.agent, modus, auftrag: auftrag?.auftragsnummer });
      return json(res, 200, { werkzeug, agent: w.agent, modus, ergebnis });
    }

    if (url.pathname === '/api/ki31/anliegen' && req.method === 'POST') {
      const { anliegen = '', auftrag = {}, verlauf = [] } = await koerper(req);
      res.writeHead(200, { 'content-type': 'application/x-ndjson; charset=utf-8', 'cache-control': 'no-cache' });
      const senden = (e) => res.write(JSON.stringify(e) + '\n');
      try {
        await bearbeiteAnliegen({ anliegen: String(anliegen).slice(0, 4000), auftrag, verlauf, rolle, senden });
      } catch (fehler) {
        senden({ typ: 'fehler', text: String(fehler.message || fehler) });
      }
      senden({ typ: 'ende' });
      return res.end();
    }

    if (url.pathname === '/api/werkstatt' && req.method === 'GET') {
      return json(res, 200, {
        eintraege: (await werkstatt.lade()).reverse(),
        arten: werkstatt.ARTEN,
        bedingungen: werkstatt.BEDINGUNGEN,
        felder: Object.keys(FELDER),
        darfBearbeiten: darfWerkzeug(rolle, 'werkstatt_bearbeiten'),
        darfFreigeben: darfWerkzeug(rolle, 'werkstatt_freigeben')
      });
    }

    const ws = url.pathname.match(/^\/api\/werkstatt\/([\w-]+)\/(entwurf|ki-entwurf|testen|freigeben|widerrufen|verwerfen|aufnehmen)$/);
    if (ws && req.method === 'POST') {
      const [, id, aktion] = ws;
      const recht = ['freigeben', 'widerrufen'].includes(aktion) ? 'werkstatt_freigeben' : 'werkstatt_bearbeiten';
      if (!darfWerkzeug(rolle, recht)) return json(res, 403, { fehler: 'Nur 31C darf die Werkstatt bearbeiten und Werkzeuge freigeben.' });
      const daten = await koerper(req);
      const wer = ROLLEN[rolle].bezeichnung;
      try {
        let e;
        if (aktion === 'entwurf') e = await werkstatt.entwurfSpeichern(id, daten.spec, wer);
        if (aktion === 'ki-entwurf') {
          const eintrag = (await werkstatt.lade()).find((x) => x.id === id);
          if (!eintrag) return json(res, 404, { fehler: 'nicht gefunden' });
          e = (await werkstattEntwurfBauen(eintrag, (await ki.betriebsart()).modus)) || eintrag;
        }
        if (aktion === 'testen') e = await werkstatt.testen(id, wer);
        if (aktion === 'freigeben') e = await werkstatt.freigeben(id, { rollen: daten.rollen, rolle: wer });
        if (aktion === 'widerrufen') e = await werkstatt.widerrufen(id, wer);
        if (aktion === 'verwerfen') e = await werkstatt.verwerfen(id, wer);
        if (aktion === 'aufnehmen') e = await werkstatt.wiederAufnehmen(id, wer);
        await speicher.protokolliere({ art: 'werkstatt', aktion, rolle, id });
        return json(res, 200, e);
      } catch (f) {
        if (f instanceof werkstatt.WerkstattFehler) return json(res, f.status, { fehler: f.message, details: f.details });
        throw f;
      }
    }

    if (url.pathname === '/api/meldescheine' && req.method === 'POST') {
      if (!darfWerkzeug(rolle, 'meldeschein_uebernehmen'))
        return json(res, 403, { fehler: 'Nur die Führungskraft kann einen Meldeschein übernehmen (31C).' });
      const { meldeschein, messung, auftragId } = await koerper(req);
      const eintrag = { id: crypto.randomUUID(), auftragId, erstellt: new Date().toISOString(), rolle, ...meldeschein };
      await speicher.speichereMeldeschein(eintrag);
      if (messung) await speicher.speichereMessung({ ...messung, auftragId, meldescheinId: eintrag.id, zeit: eintrag.erstellt });
      return json(res, 200, eintrag);
    }

    if (url.pathname === '/api/meldescheine' && req.method === 'GET') return json(res, 200, await speicher.ladeMeldescheine());
    if (url.pathname === '/api/auswertung' && req.method === 'GET') return json(res, 200, auswerten(await speicher.ladeMessungen()));

    if (req.method === 'GET' && !url.pathname.startsWith('/api/')) {
      const relativ = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname).replace(/^\/+/, '');
      const ziel = path.resolve(OEFFENTLICH, relativ);
      if (!ziel.startsWith(OEFFENTLICH + path.sep)) return json(res, 404, { fehler: 'nicht gefunden' });
      try {
        const inhalt = await readFile(ziel);
        res.writeHead(200, { 'content-type': MIME[path.extname(ziel)] || 'application/octet-stream' });
        return res.end(inhalt);
      } catch {
        return json(res, 404, { fehler: 'nicht gefunden' });
      }
    }

    return json(res, 404, { fehler: 'nicht gefunden' });
  } catch (fehler) {
    console.error(fehler);
    if (!res.headersSent) return json(res, 500, { fehler: String(fehler.message || fehler) });
    res.end();
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  createServer(bearbeite).listen(PORT, HOST, async () => {
    const b = await ki.betriebsart();
    console.log(`KI31-Pilot läuft auf http://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT}`);
    console.log(b.modus === 'ollama' ? `Lokales Modell: ${b.modell}` : `Demo-Modus ohne KI – ${b.grund}`);
    console.log(`Daten: ${speicher.DATENORDNER}`);
  });
}

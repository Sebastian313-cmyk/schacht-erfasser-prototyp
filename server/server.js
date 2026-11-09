// KI31-Pilot – lokaler Server ohne externe Abhängigkeiten.
// Start: npm start   (oder: npm run demo für den Betrieb ohne Sprachmodell)

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { AGENTEN, erkenneWerkzeug, waehleAgent } from './agenten.js';
import { darfWerkzeug, ROLLEN } from './berechtigungen.js';
import * as ki from './ki.js';
import { DRINGLICHKEITEN, EMPFAENGER, OBJEKTARTEN } from './organisation.js';
import * as speicher from './speicher.js';
import { auswerten } from './auswertung.js';

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

async function werkzeugAusfuehren(werkzeug, { auftrag, agent, modus, wunsch }) {
  switch (werkzeug) {
    case 'auftrag_zusammenfassen':
      return { text: await ki.zusammenfassen(auftrag, { modus, agent }) };
    case 'fehlende_angaben':
      return ki.fehlendeAngaben(auftrag, { modus, agent });
    case 'meldeschein_entwerfen':
      return { meldeschein: await ki.meldescheinEntwerfen(auftrag, { modus, agent, wunsch }) };
    default:
      throw new Error(`Unbekanntes Werkzeug: ${werkzeug}`);
  }
}

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
        dringlichkeiten: DRINGLICHKEITEN
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
      const { werkzeug, auftrag, wunsch } = await koerper(req);
      if (!darfWerkzeug(rolle, werkzeug)) {
        await speicher.protokolliere({ art: 'verweigert', rolle, werkzeug });
        return json(res, 403, { fehler: `Die Rolle „${ROLLEN[rolle].bezeichnung}“ darf „${werkzeug}“ nicht nutzen (31C).` });
      }
      const { modus } = await ki.betriebsart();
      const agent = waehleAgent(wunsch || '', auftrag);
      const ergebnis = await werkzeugAusfuehren(werkzeug, { auftrag, agent, modus, wunsch });
      await speicher.protokolliere({ art: 'werkzeug', rolle, werkzeug, agent, modus, auftrag: auftrag?.auftragsnummer });
      return json(res, 200, { werkzeug, agent, modus, ergebnis });
    }

    if (url.pathname === '/api/ki/chat' && req.method === 'POST') {
      const { auftrag, verlauf = [] } = await koerper(req);
      const letzte = [...verlauf].reverse().find((n) => n.rolle === 'user')?.text || '';
      const agent = waehleAgent(letzte, auftrag);
      const { modus } = await ki.betriebsart();
      res.writeHead(200, { 'content-type': 'application/x-ndjson; charset=utf-8', 'cache-control': 'no-cache' });
      const senden = (e) => res.write(JSON.stringify(e) + '\n');
      senden({ typ: 'agent', agent, name: AGENTEN[agent].name, modus });

      try {
        const werkzeug = erkenneWerkzeug(letzte);
        if (werkzeug) {
          if (!darfWerkzeug(rolle, werkzeug)) {
            senden({ typ: 'text', text: `Das Werkzeug „${werkzeug}“ ist für die Rolle „${ROLLEN[rolle].bezeichnung}“ nicht freigegeben (31C).` });
          } else {
            const ergebnis = await werkzeugAusfuehren(werkzeug, { auftrag, agent, modus, wunsch: letzte });
            senden({ typ: 'werkzeug', werkzeug, ergebnis });
          }
          await speicher.protokolliere({ art: 'chat-werkzeug', rolle, werkzeug, agent, modus });
        } else {
          await ki.chatAntwort({ auftrag, verlauf, agent, modus, beiText: (text) => senden({ typ: 'text', text }) });
          await speicher.protokolliere({ art: 'chat', rolle, agent, modus });
        }
      } catch (fehler) {
        senden({ typ: 'fehler', text: String(fehler.message || fehler) });
      }
      senden({ typ: 'ende' });
      return res.end();
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

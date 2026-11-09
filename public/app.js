// KI31-Pilot – Oberfläche. Alle Texte werden mit textContent gesetzt (keine HTML-Einschleusung).

const $ = (sel) => document.querySelector(sel);
const zustand = {
  status: null,
  auftraege: [],
  aktiv: null,
  verlauf: [],
  messung: null, // { modus, start, entwurfZeit, entwurf }
  uhr: null
};

const rolle = () => $('#rolle').value;

async function api(pfad, { methode = 'GET', daten } = {}) {
  const res = await fetch(pfad, {
    method: methode,
    headers: { 'content-type': 'application/json', 'x-ki31-rolle': rolle() },
    body: daten ? JSON.stringify(daten) : undefined
  });
  const inhalt = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(inhalt.fehler || `Fehler ${res.status}`);
  return inhalt;
}

function el(tag, eigenschaften = {}, ...kinder) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(eigenschaften)) {
    if (k === 'text') e.textContent = v;
    else if (k === 'klasse') e.className = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else e.setAttribute(k, v);
  }
  for (const k of kinder) if (k) e.append(k);
  return e;
}

// ------------------------------------------------------------------ Start

async function start() {
  try { $('#rolle').value = localStorage.getItem('ki31-rolle') || 'fuehrungskraft'; } catch {}
  zustand.status = await api('/api/status');
  const m = $('#modus');
  m.textContent = zustand.status.modus === 'ollama' ? `Lokales Modell: ${zustand.status.modell}` : 'Demo-Modus – keine KI';
  m.title = zustand.status.grund || '';
  m.classList.toggle('demo', zustand.status.modus !== 'ollama');

  füllenAuswahl($('#ms-empfaenger'), ['', ...zustand.status.empfaenger]);
  füllenAuswahl($('#ms-dringlichkeit'), zustand.status.dringlichkeiten);
  await ladeAuftraege();
  rolleAnwenden();
}

function füllenAuswahl(select, werte) {
  select.replaceChildren(...werte.map((w) => el('option', { value: w, text: w || '–' })));
}

async function ladeAuftraege(aktiveId) {
  zustand.auftraege = await api('/api/auftraege');
  const id = aktiveId || zustand.aktiv?.id || zustand.auftraege[0]?.id;
  zeigeListe();
  if (id) waehleAuftrag(id);
}

function zeigeListe() {
  $('#auftragsliste').replaceChildren(
    ...zustand.auftraege.map((a) =>
      el('li', {},
        el('button', { type: 'button', 'aria-current': String(a.id === zustand.aktiv?.id), onclick: () => waehleAuftrag(a.id) },
          document.createTextNode(a.auftragsnummer || '(ohne Nummer)'),
          el('small', { text: `${a.auftragsart || '–'} · ${a.strasse || '–'}${a.terminauftrag ? ' · Termin' : ''}` })))
    )
  );
}

function waehleAuftrag(id) {
  zustand.aktiv = structuredClone(zustand.auftraege.find((a) => a.id === id));
  zustand.verlauf = [];
  $('#verlauf').replaceChildren();
  $('#agent').textContent = '';
  meldescheinSchliessen();
  stoppeMessung();
  zeigeAuftrag();
  zeigeListe();
  systemZeile('Auftrag geöffnet. KI31 kennt die Angaben in der Maske – auch ungespeicherte Änderungen.');
}

// ------------------------------------------------------------------ Auftragsmaske

const form = () => $('#auftrag-form');

function zeigeAuftrag() {
  const a = zustand.aktiv;
  const f = form();
  $('#auftrag-titel').textContent = `Auftrag ${a.auftragsnummer || '(ohne Nummer)'}${a.fiktiv ? ' – fiktiv' : ''}`;
  for (const name of ['auftragsnummer', 'auftragsart', 'strasse', 'hausnummer', 'weitergebendeAbteilung', 'eingangsdatum', 'ausfuehrungstermin', 'bearbeitungsstand', 'wetter', 'temperatur', 'notizen'])
    f.elements[name].value = a[name] || '';
  f.elements.terminauftrag.checked = Boolean(a.terminauftrag);
  f.elements.personal.value = (a.personal || []).join(', ');
  const ee = a.einstiegserlaubnis || {};
  f.elements.ee_erforderlich.value = ee.erforderlich === true ? 'ja' : ee.erforderlich === false ? 'nein' : '';
  f.elements.ee_bezirk.value = ee.bezirk || '';
  zeigeObjekte();
  zeigeMedien();
  markiereFelder([]);
}

function zeigeObjekte() {
  const arten = zustand.status.objektarten;
  $('#objekte').replaceChildren(
    ...(zustand.aktiv.objekte || []).map((o, i) => {
      const art = el('select', { 'data-objekt': i, 'data-feld': 'objektart' }, el('option', { value: '', text: '–' }), ...arten.map((x) => el('option', { value: x, text: x })));
      art.value = o.objektart || '';
      const feld = (name, titel, klasse = '') => {
        const eingabe = name === 'befund' || name === 'arbeit' ? el('textarea', { rows: 2 }) : el('input');
        eingabe.dataset.objekt = i;
        eingabe.dataset.feld = name;
        eingabe.value = o[name] || '';
        return el('label', klasse ? { klasse } : {}, document.createTextNode(titel), eingabe);
      };
      return el('div', { klasse: 'objekt' },
        el('label', {}, document.createTextNode(`Objekt ${i + 1} – Objektart`), art),
        feld('objektId', 'Objekt-ID'),
        feld('dn', 'DN (bei Kanal)'),
        feld('befund', 'Befund', 'breit'),
        feld('arbeit', 'Arbeit', 'breit'),
        el('button', { type: 'button', klasse: 'leise klein', text: 'Objekt entfernen', onclick: () => { leseMaske(); zustand.aktiv.objekte.splice(i, 1); zeigeObjekte(); } }));
    })
  );
}

function zeigeMedien() {
  $('#medien').replaceChildren(
    ...(zustand.aktiv.medien || []).map((m, i) => {
      const name = el('input', { 'data-medium': i, 'data-feld': 'name' });
      name.value = m.name || '';
      const beschr = el('input', { 'data-medium': i, 'data-feld': 'beschreibung' });
      beschr.value = m.beschreibung || '';
      return el('div', { klasse: 'medium' },
        el('label', {}, document.createTextNode('Dateiname'), name),
        el('label', {}, document.createTextNode('Beschreibung'), beschr),
        el('button', { type: 'button', klasse: 'leise klein', text: 'entfernen', onclick: () => { leseMaske(); zustand.aktiv.medien.splice(i, 1); zeigeMedien(); } }));
    })
  );
}

function leseMaske() {
  const a = zustand.aktiv;
  const f = form();
  for (const name of ['auftragsnummer', 'auftragsart', 'strasse', 'hausnummer', 'weitergebendeAbteilung', 'eingangsdatum', 'ausfuehrungstermin', 'bearbeitungsstand', 'wetter', 'temperatur', 'notizen'])
    a[name] = f.elements[name].value.trim();
  a.terminauftrag = f.elements.terminauftrag.checked;
  a.personal = f.elements.personal.value.split(',').map((s) => s.trim()).filter(Boolean);
  const ee = f.elements.ee_erforderlich.value;
  a.einstiegserlaubnis = { erforderlich: ee === 'ja' ? true : ee === 'nein' ? false : null, bezirk: f.elements.ee_bezirk.value };
  a.objekte = [...document.querySelectorAll('#objekte .objekt')].map((_, i) => {
    const o = {};
    document.querySelectorAll(`#objekte [data-objekt="${i}"]`).forEach((e) => (o[e.dataset.feld] = e.value.trim()));
    return o;
  });
  a.medien = [...document.querySelectorAll('#medien .medium')].map((_, i) => {
    const m = {};
    document.querySelectorAll(`#medien [data-medium="${i}"]`).forEach((e) => (m[e.dataset.feld] = e.value.trim()));
    return m;
  });
  return a;
}

function markiereFelder(regeln) {
  document.querySelectorAll('.feld-fehlt, .feld-klaeren').forEach((e) => e.classList.remove('feld-fehlt', 'feld-klaeren'));
  for (const r of regeln) {
    if (r.stufe === 'empfohlen') continue;
    const klasse = r.stufe === 'fehlt' ? 'feld-fehlt' : 'feld-klaeren';
    const teile = r.feld.split('.');
    let ziel = null;
    if (teile[0] === 'objekte' && teile.length === 3) ziel = document.querySelector(`#objekte [data-objekt="${teile[1]}"][data-feld="${teile[2]}"]`);
    else if (teile[0] === 'einstiegserlaubnis') ziel = form().elements[teile[1] === 'bezirk' ? 'ee_bezirk' : 'ee_erforderlich'];
    else if (teile[0] === 'objekte') ziel = $('#objekt-neu');
    else ziel = form().elements[teile[0]];
    ziel?.classList.add(klasse);
  }
}

form().addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const a = leseMaske();
  await api('/api/auftraege', { methode: 'PUT', daten: a });
  await ladeAuftraege(a.id);
  systemZeile('Auftrag gespeichert.');
});
$('#objekt-neu').addEventListener('click', () => { leseMaske(); (zustand.aktiv.objekte ||= []).push({}); zeigeObjekte(); });
$('#medium-neu').addEventListener('click', () => { leseMaske(); (zustand.aktiv.medien ||= []).push({}); zeigeMedien(); });

// ------------------------------------------------------------------ Verlauf

function zeile(rolleName, inhalt) {
  const li = el('li', { klasse: rolleName });
  if (typeof inhalt === 'string') li.textContent = inhalt;
  else li.append(inhalt);
  $('#verlauf').append(li);
  li.scrollIntoView({ block: 'nearest' });
  return li;
}
const systemZeile = (text) => zeile('system', text);

function zeigeWerkzeugErgebnis(werkzeug, ergebnis) {
  if (werkzeug === 'auftrag_zusammenfassen') {
    zeile('assistant', ergebnis.text);
    zustand.verlauf.push({ rolle: 'assistant', text: ergebnis.text });
  } else if (werkzeug === 'fehlende_angaben') {
    const box = el('div', {}, el('strong', { text: ergebnis.regeln.length ? 'Prüfung der Angaben' : 'Alle Pflichtangaben sind vorhanden.' }));
    const stufen = { fehlt: 'fehlt', klaeren: 'klären', empfohlen: 'empfohlen' };
    if (ergebnis.regeln.length)
      box.append(el('ul', {}, ...ergebnis.regeln.map((r) => el('li', { klasse: `befund-${r.stufe}`, text: `${stufen[r.stufe]}: ${r.text}` }))));
    if (ergebnis.hinweise?.length)
      box.append(el('strong', { text: 'Hinweise von KI31' }), el('ul', {}, ...ergebnis.hinweise.map((h) => el('li', { text: h }))));
    zeile('assistant', box);
    markiereFelder(ergebnis.regeln);
    zustand.verlauf.push({ rolle: 'assistant', text: ergebnis.regeln.map((r) => r.text).concat(ergebnis.hinweise || []).join('\n') || 'Alle Pflichtangaben vorhanden.' });
  } else if (werkzeug === 'meldeschein_entwerfen') {
    meldescheinZeigen(ergebnis.meldeschein, 'Entwurf von KI31');
    zeile('assistant', `Meldeschein-Entwurf an ${ergebnis.meldeschein.empfaenger || '(Empfänger offen)'} liegt unter dem Auftrag bereit. ${ergebnis.meldeschein.offenePunkte.length} offene Punkte.`);
    zustand.verlauf.push({ rolle: 'assistant', text: `Ich habe einen Meldeschein-Entwurf erstellt: ${JSON.stringify(ergebnis.meldeschein)}` });
  }
}

async function werkzeug(name) {
  const a = leseMaske();
  if (name === 'meldeschein_entwerfen') beginneMessung('mit KI');
  const knoepfe = document.querySelectorAll('.werkzeuge button');
  knoepfe.forEach((k) => (k.disabled = true));
  const warte = systemZeile('KI31 arbeitet …');
  try {
    const antwort = await api('/api/ki/werkzeug', { methode: 'POST', daten: { werkzeug: name, auftrag: a } });
    warte.remove();
    zeigeAgent(antwort.agent);
    zeigeWerkzeugErgebnis(name, antwort.ergebnis);
  } catch (f) {
    warte.textContent = f.message;
    if (name === 'meldeschein_entwerfen') stoppeMessung();
  } finally {
    knoepfe.forEach((k) => (k.disabled = false));
  }
}
document.querySelectorAll('.werkzeuge button').forEach((b) => b.addEventListener('click', () => werkzeug(b.dataset.werkzeug)));

function zeigeAgent(kennung) {
  $('#agent').textContent = zustand.status.agenten[kennung] || '';
}

// ------------------------------------------------------------------ Chat

$('#chat-form').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const text = $('#chat-text').value.trim();
  if (!text) return;
  $('#chat-text').value = '';
  zeile('user', text);
  zustand.verlauf.push({ rolle: 'user', text });
  const knopf = ev.submitter || $('#chat-form button[type=submit]');
  knopf.disabled = true;
  let antwortZeile = null;
  let antwortText = '';
  try {
    const res = await fetch('/api/ki/chat', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-ki31-rolle': rolle() },
      body: JSON.stringify({ auftrag: leseMaske(), verlauf: zustand.verlauf })
    });
    const leser = res.body.getReader();
    const decoder = new TextDecoder();
    let puffer = '';
    for (;;) {
      const { value, done } = await leser.read();
      if (done) break;
      puffer += decoder.decode(value, { stream: true });
      let n;
      while ((n = puffer.indexOf('\n')) >= 0) {
        const e = JSON.parse(puffer.slice(0, n));
        puffer = puffer.slice(n + 1);
        if (e.typ === 'agent') zeigeAgent(e.agent);
        else if (e.typ === 'text') {
          antwortZeile ||= zeile('assistant', '');
          antwortText += e.text;
          antwortZeile.textContent = antwortText;
        } else if (e.typ === 'werkzeug') {
          if (e.werkzeug === 'meldeschein_entwerfen') beginneMessung('mit KI');
          zeigeWerkzeugErgebnis(e.werkzeug, e.ergebnis);
        } else if (e.typ === 'fehler') systemZeile(`Fehler: ${e.text}`);
      }
    }
    if (antwortText) zustand.verlauf.push({ rolle: 'assistant', text: antwortText });
  } catch (f) {
    systemZeile(`Fehler: ${f.message}`);
  } finally {
    knopf.disabled = false;
  }
});
$('#chat-text').addEventListener('keydown', (ev) => {
  if (ev.key === 'Enter' && !ev.shiftKey) { ev.preventDefault(); $('#chat-form').requestSubmit(); }
});

// Spracheingabe über die Browser-Spracherkennung. Achtung: In Chrome und Edge wird die
// Sprache dafür an einen Dienst des Browserherstellers übertragen – im Pilot nur mit
// fiktiven Inhalten verwenden. Eine lokale Spracherkennung ist für einen späteren Stand geplant.
(function diktat() {
  const Erkennung = window.SpeechRecognition || window.webkitSpeechRecognition;
  const knopf = $('#diktat');
  if (!Erkennung) { knopf.hidden = true; return; }
  let laeuft = null;
  knopf.addEventListener('click', () => {
    if (laeuft) { laeuft.stop(); return; }
    const h = $('#diktat-hinweis');
    h.hidden = false;
    h.textContent = 'Spracheingabe aktiv. Hinweis: Der Browser überträgt die Sprache zur Erkennung an seinen Hersteller – nur fiktive Inhalte diktieren.';
    const e = new Erkennung();
    e.lang = 'de-DE';
    e.interimResults = false;
    e.onresult = (ev) => {
      const text = [...ev.results].map((r) => r[0].transcript).join(' ');
      $('#chat-text').value = `${$('#chat-text').value} ${text}`.trim();
    };
    e.onend = () => { laeuft = null; knopf.textContent = '🎤'; };
    e.start();
    laeuft = e;
    knopf.textContent = '■';
  });
})();

// ------------------------------------------------------------------ Meldeschein

const MS_FELDER = ['empfaenger', 'dringlichkeit', 'angeforderteLeistung', 'begruendung', 'ortsangabe', 'objektbezug', 'hinweise', 'offenePunkte'];
const LISTENFELDER = ['hinweise', 'offenePunkte'];

function meldescheinZeigen(ms, quelle) {
  for (const f of MS_FELDER) {
    const e = $(`#ms-${f}`);
    e.value = LISTENFELDER.includes(f) ? (ms[f] || []).join('\n') : ms[f] || '';
  }
  $('#ms-quelle').textContent = quelle;
  $('#ms-brauchbar').value = '';
  $('#ms-brauchbar').closest('label').hidden = !zustand.messung?.entwurf;
  $('#ms-meldung').textContent = '';
  $('#meldeschein').hidden = false;
  if (zustand.messung) {
    zustand.messung.entwurfZeit = Date.now();
    zustand.messung.entwurf = zustand.messung.modus === 'mit KI' ? structuredClone(ms) : null;
    $('#ms-brauchbar').closest('label').hidden = zustand.messung.modus !== 'mit KI';
  }
  $('#meldeschein').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function leseMeldeschein() {
  const ms = {};
  for (const f of MS_FELDER) {
    const w = $(`#ms-${f}`).value;
    ms[f] = LISTENFELDER.includes(f) ? w.split('\n').map((s) => s.trim()).filter(Boolean) : w.trim();
  }
  return ms;
}

function meldescheinSchliessen() {
  $('#meldeschein').hidden = true;
}

$('#ms-verwerfen').addEventListener('click', () => { meldescheinSchliessen(); stoppeMessung(); systemZeile('Meldeschein verworfen. Die Messung wurde nicht gespeichert.'); });

$('#ms-uebernehmen').addEventListener('click', async () => {
  const ms = leseMeldeschein();
  if (!ms.empfaenger) { $('#ms-meldung').textContent = 'Bitte einen Empfänger wählen.'; return; }
  if (!ms.angeforderteLeistung) { $('#ms-meldung').textContent = 'Bitte die angeforderte Leistung beschreiben.'; return; }
  const m = zustand.messung;
  let messung = null;
  if (m) {
    const jetzt = Date.now();
    const geaendert = m.entwurf ? MS_FELDER.filter((f) => JSON.stringify(m.entwurf[f] ?? (LISTENFELDER.includes(f) ? [] : '')) !== JSON.stringify(ms[f])).length : null;
    const brauchbar = $('#ms-brauchbar').value;
    messung = {
      modus: m.modus,
      rolle: rolle(),
      gesamtSek: Math.round((jetzt - m.start) / 1000),
      kontrolleSek: m.entwurfZeit ? Math.round((jetzt - m.entwurfZeit) / 1000) : null,
      geaenderteFelder: geaendert,
      brauchbar: brauchbar === '' ? null : brauchbar !== 'nein',
      bewertung: brauchbar || null,
      ki: zustand.status.modus === 'ollama' ? zustand.status.modell : 'demo'
    };
  }
  try {
    await api('/api/meldescheine', { methode: 'POST', daten: { meldeschein: ms, messung, auftragId: zustand.aktiv.id } });
    $('#ms-meldung').textContent = messung
      ? `Übernommen. Dauer ${formatDauer(messung.gesamtSek)}${messung.kontrolleSek != null && m.modus === 'mit KI' ? `, davon Kontrolle ${formatDauer(messung.kontrolleSek)}` : ''}.`
      : 'Übernommen.';
    systemZeile(`Meldeschein an ${ms.empfaenger} übernommen. Die Weitergabe selbst erfolgt im Fachablauf.`);
    stoppeMessung();
  } catch (f) {
    $('#ms-meldung').textContent = f.message;
  }
});

// ------------------------------------------------------------------ Messung

$('#messmodus').addEventListener('change', () => {
  const ohne = $('#messmodus').value === 'ohne KI';
  $('#ohne-ki-start').hidden = !ohne;
  document.querySelector('[data-werkzeug="meldeschein_entwerfen"]').disabled = ohne;
});
$('#ohne-ki-start').addEventListener('click', () => {
  beginneMessung('ohne KI');
  meldescheinZeigen({}, 'Ohne KI – manuell');
});

function beginneMessung(modus) {
  if (zustand.messung) return;
  zustand.messung = { modus, start: Date.now(), entwurfZeit: null, entwurf: null };
  clearInterval(zustand.uhr);
  zustand.uhr = setInterval(() => {
    $('#stoppuhr').textContent = `⏱ ${formatDauer(Math.round((Date.now() - zustand.messung.start) / 1000))} (${modus})`;
  }, 1000);
}
function stoppeMessung() {
  clearInterval(zustand.uhr);
  zustand.messung = null;
  $('#stoppuhr').textContent = '';
}
const formatDauer = (s) => (s == null ? '–' : `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')} min`);

$('#auswertung-oeffnen').addEventListener('click', async () => {
  const daten = await api('/api/auswertung');
  const inhalt = $('#auswertung-inhalt');
  const gruppen = Object.entries(daten.gruppen);
  if (gruppen.length === 0) {
    inhalt.replaceChildren(el('p', { text: 'Noch keine Messungen. Erzeuge einen Meldeschein mit KI oder beginne einen leeren Meldeschein „ohne KI“ und übernimm ihn.' }));
  } else {
    const kopf = el('tr', {}, ...['Durchlauf', 'Anzahl', 'Median Gesamt', 'Median Kontrolle', 'Median geänderte Felder', 'unbrauchbar'].map((t, i) => el('th', { klasse: i ? 'zahl' : '', text: t })));
    inhalt.replaceChildren(
      el('p', { klasse: 'hinweis', text: 'Gesamt = vom Beginn bis zur Übernahme, einschließlich Kontrolle. Kontrolle = vom fertigen Entwurf bis zur Übernahme.' }),
      el('table', {}, el('thead', {}, kopf), el('tbody', {}, ...gruppen.map(([modus, g]) =>
        el('tr', {}, el('td', { text: modus }), el('td', { klasse: 'zahl', text: String(g.anzahl) }), el('td', { klasse: 'zahl', text: formatDauer(g.medianGesamtSek) }),
          el('td', { klasse: 'zahl', text: formatDauer(g.medianKontrolleSek) }), el('td', { klasse: 'zahl', text: g.medianGeaenderteFelder ?? '–' }), el('td', { klasse: 'zahl', text: String(g.unbrauchbar) }))))))
  }
  $('#auswertung').showModal();
});

// ------------------------------------------------------------------ Rolle

function rolleAnwenden() {
  try { localStorage.setItem('ki31-rolle', rolle()); } catch {}
  const fk = rolle() === 'fuehrungskraft';
  document.querySelector('[data-werkzeug="meldeschein_entwerfen"]').hidden = !fk;
  $('.messmodus').hidden = !fk;
  if (!fk) meldescheinSchliessen();
}
$('#rolle').addEventListener('change', rolleAnwenden);

$('#zuruecksetzen').addEventListener('click', async () => {
  if (!confirm('Alle Aufträge auf die fiktiven Beispieldaten zurücksetzen?')) return;
  await api('/api/auftraege/zuruecksetzen', { methode: 'POST' });
  zustand.aktiv = null;
  await ladeAuftraege();
});

start().catch((f) => systemZeile(`Start fehlgeschlagen: ${f.message}`));

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

function setzeFeld(obj, feld, wert) {
  const teile = feld.split('.');
  let o = obj;
  for (let i = 0; i < teile.length - 1; i++) {
    if (o[teile[i]] == null) o[teile[i]] = /^\d+$/.test(teile[i + 1]) ? [] : {};
    o = o[teile[i]];
  }
  o[teile.at(-1)] = wert;
}
const anzeigeWert = (w) => (w === true ? 'ja' : w === false ? 'nein' : Array.isArray(w) ? w.join(', ') : w === '' || w == null ? '–' : String(w));

function zeigeAenderungen(ergebnis) {
  const box = el('div', { klasse: 'kasten' });
  if (!ergebnis.aenderungen.length) box.append(el('span', { text: 'Keine neuen Werte – die Angaben stehen schon so im Auftrag.' }));
  else {
    box.append(el('strong', { text: `${ergebnis.aenderungen.length} Feld(er) ausfüllen – bitte bestätigen` }));
    const zeilen = el('div', { klasse: 'zeilen' });
    ergebnis.aenderungen.forEach((a, i) => {
      const haken = el('input', { type: 'checkbox', 'data-i': i });
      haken.checked = true;
      zeilen.append(el('label', { klasse: 'haken' }, haken, document.createTextNode(`${a.titel}: `), el('span', { klasse: 'alt', text: anzeigeWert(a.alt) }), document.createTextNode(` → ${anzeigeWert(a.neu)}`)));
    });
    const knopf = el('button', { type: 'button', text: 'Bestätigen und speichern' });
    knopf.addEventListener('click', async () => {
      const gewaehlt = [...zeilen.querySelectorAll('input:checked')].map((h) => ergebnis.aenderungen[h.dataset.i]);
      leseMaske();
      for (const a of gewaehlt) setzeFeld(zustand.aktiv, a.feld, a.neu);
      try {
        await api('/api/auftraege', { methode: 'PUT', daten: zustand.aktiv });
        const id = zustand.aktiv.id;
        const kopie = structuredClone(zustand.aktiv);
        zustand.auftraege = zustand.auftraege.map((x) => (x.id === id ? kopie : x));
        zeigeAuftrag();
        zeigeListe();
        box.replaceChildren(el('span', { text: `${gewaehlt.length} Feld(er) übernommen und gespeichert.` }));
      } catch (f) {
        box.append(el('span', { klasse: 'nok', text: f.message }));
      }
    });
    box.append(zeilen, el('div', { klasse: 'knopfzeile' }, knopf, el('button', { type: 'button', klasse: 'leise', text: 'Verwerfen', onclick: () => box.replaceChildren(el('span', { text: 'Vorschlag verworfen.' })) })));
  }
  if (ergebnis.ungueltig?.length)
    box.append(el('ul', {}, ...ergebnis.ungueltig.map((u) => el('li', { klasse: 'nok', text: `Nicht übernommen (${u.feld}): ${u.fehler}` }))));
  zeile('assistant', box);
}

function zeigeAntrag(antrag) {
  const box = el('div', { klasse: 'kasten' }, el('strong', { text: 'Entwurf Antrag Einstiegserlaubnis' }));
  const zeilen = [
    ['Bezirk', antrag.bezirk], ['Auftrag', antrag.auftragsnummer], ['Ort', antrag.ort], ['Objekte', antrag.objekte.join('; ')],
    ['Anlass', antrag.anlass], ['Personal', antrag.personal.join(', ')], ['Termin', antrag.termin]
  ];
  box.append(el('ul', {}, ...zeilen.map(([k, v]) => el('li', { text: `${k}: ${v || '–'}` }))));
  if (antrag.offenePunkte.length) box.append(el('strong', { text: 'Offen' }), el('ul', {}, ...antrag.offenePunkte.map((p) => el('li', { klasse: 'befund-klaeren', text: p }))));
  box.append(el('span', { klasse: 'hinweis', text: antrag.hinweis }));
  zeile('assistant', box);
}

function zeigeWerkzeugErgebnis(werkzeug, ergebnis) {
  if (ergebnis.aenderungen) {
    zeigeAenderungen(ergebnis);
    zustand.verlauf.push({ rolle: 'assistant', text: `Feldvorschläge: ${ergebnis.aenderungen.map((a) => `${a.titel}=${anzeigeWert(a.neu)}`).join(', ')}` });
  } else if (ergebnis.antrag) {
    zeigeAntrag(ergebnis.antrag);
    zustand.verlauf.push({ rolle: 'assistant', text: 'Ich habe einen Antrag auf Einstiegserlaubnis vorbereitet.' });
  } else if (ergebnis.meldeschein) {
    beginneMessung('mit KI', zustand.anfrageStart);
    meldescheinZeigen(ergebnis.meldeschein, 'Entwurf von KI31');
    zeile('assistant', `Meldeschein-Entwurf an ${ergebnis.meldeschein.empfaenger || '(Empfänger offen)'} liegt unter dem Auftrag bereit. ${ergebnis.meldeschein.offenePunkte.length} offene Punkte.`);
    zustand.verlauf.push({ rolle: 'assistant', text: `Ich habe einen Meldeschein-Entwurf erstellt: ${JSON.stringify(ergebnis.meldeschein)}` });
  } else if (ergebnis.regeln) {
    const box = el('div', {}, el('strong', { text: ergebnis.regeln.length ? 'Prüfung der Angaben' : 'Keine Auffälligkeiten.' }));
    const stufen = { fehlt: 'fehlt', klaeren: 'klären', empfohlen: 'empfohlen' };
    if (ergebnis.regeln.length)
      box.append(el('ul', {}, ...ergebnis.regeln.map((r) => el('li', { klasse: `befund-${r.stufe}`, text: `${stufen[r.stufe] || r.stufe}: ${r.text}` }))));
    if (ergebnis.hinweise?.length)
      box.append(el('strong', { text: 'Hinweise von KI31' }), el('ul', {}, ...ergebnis.hinweise.map((h) => el('li', { text: h }))));
    zeile('assistant', box);
    if (werkzeug === 'fehlende_angaben') markiereFelder(ergebnis.regeln);
    zustand.verlauf.push({ rolle: 'assistant', text: ergebnis.regeln.map((r) => r.text).concat(ergebnis.hinweise || []).join('\n') || 'Keine Auffälligkeiten.' });
  } else if (typeof ergebnis.text === 'string') {
    zeile('assistant', ergebnis.text);
    zustand.verlauf.push({ rolle: 'assistant', text: ergebnis.text });
  }
}

async function werkzeug(name) {
  const a = leseMaske();
  zustand.anfrageStart = Date.now();
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
  } finally {
    knoepfe.forEach((k) => (k.disabled = false));
  }
}
document.querySelectorAll('.werkzeuge button').forEach((b) => b.addEventListener('click', () => werkzeug(b.dataset.werkzeug)));

function zeigeAgent(kennung) {
  $('#agent').textContent = zustand.status.agenten[kennung] || '';
}

// ------------------------------------------------------------------ Chat

async function anliegenSenden(text) {
  zustand.anfrageStart = Date.now();
  zeile('user', text);
  zustand.verlauf.push({ rolle: 'user', text });
  const knopf = $('#chat-form button[type=submit]');
  knopf.disabled = true;
  let antwortZeile = null;
  let antwortText = '';
  try {
    const res = await fetch('/api/ki31/anliegen', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-ki31-rolle': rolle() },
      body: JSON.stringify({ anliegen: text, auftrag: leseMaske(), verlauf: zustand.verlauf })
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
        else if (e.typ === 'plan' && e.schritte.length)
          zeile('system', `Plan: ${e.schritte.map((x, i) => `${i + 1}. ${x.titel} (${x.agent === 'KI31' ? 'KI31' : `Agent ${x.agent}`})`).join(' → ')}`);
        else if (e.typ === 'text') {
          antwortZeile ||= zeile('assistant', '');
          antwortText += e.text;
          antwortZeile.textContent = antwortText;
        } else if (e.typ === 'werkzeug') zeigeWerkzeugErgebnis(e.werkzeug, e.ergebnis);
        else if (e.typ === 'luecke') zeigeLuecke(e);
        else if (e.typ === 'naechster' && e.vorschlaege.length) {
          const box = el('div', { klasse: 'naechste' });
          for (const v of e.vorschlaege) box.append(el('button', { type: 'button', klasse: 'leise klein', text: v.text, onclick: () => anliegenSenden(v.anliegen) }));
          zeile('system', box);
        } else if (e.typ === 'fehler') systemZeile(`Fehler: ${e.text}`);
      }
    }
    if (antwortText) zustand.verlauf.push({ rolle: 'assistant', text: antwortText });
  } catch (f) {
    systemZeile(`Fehler: ${f.message}`);
  } finally {
    knopf.disabled = false;
    werkstattZaehler();
  }
}

function zeigeLuecke(e) {
  const status = { vorschlag: 'Vorschlag', entwurf: 'Entwurf', geprueft: 'Entwurf getestet – wartet auf Freigabe durch 31C' };
  const box = el('div', { klasse: 'kasten' },
    el('strong', { text: `Agent ${e.agent} hat dafür noch kein Werkzeug.` }),
    el('span', { text: `In der Werkstatt angelegt: „${e.eintrag.titel}“ – ${status[e.eintrag.status] || e.eintrag.status}.` }),
    el('span', { klasse: 'hinweis', text: 'Nutzbar wird das Werkzeug erst, wenn 31C es freigibt.' }),
    el('div', { klasse: 'knopfzeile' }, el('button', { type: 'button', klasse: 'leise klein', text: 'Werkstatt öffnen', onclick: werkstattOeffnen })));
  zeile('assistant', box);
}

$('#chat-form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  const text = $('#chat-text').value.trim();
  if (!text) return;
  $('#chat-text').value = '';
  anliegenSenden(text);
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

function beginneMessung(modus, start = Date.now()) {
  if (zustand.messung) return;
  zustand.messung = { modus, start: start || Date.now(), entwurfZeit: null, entwurf: null };
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
  werkstattZaehler();
}
$('#rolle').addEventListener('change', rolleAnwenden);

$('#zuruecksetzen').addEventListener('click', async () => {
  if (!confirm('Alle Aufträge auf die fiktiven Beispieldaten zurücksetzen?')) return;
  await api('/api/auftraege/zuruecksetzen', { methode: 'POST' });
  zustand.aktiv = null;
  await ladeAuftraege();
});

// ------------------------------------------------------------------ Werkstatt

const WS_STATUS = { vorschlag: 'Vorschlag', entwurf: 'Entwurf', geprueft: 'getestet', freigegeben: 'freigegeben', widerrufen: 'widerrufen', verworfen: 'verworfen' };

async function werkstattZaehler() {
  try {
    const d = await api('/api/werkstatt');
    const offen = d.eintraege.filter((e) => ['vorschlag', 'entwurf', 'geprueft'].includes(e.status)).length;
    $('#werkstatt-zaehler').hidden = offen === 0;
    $('#werkstatt-zaehler').textContent = String(offen);
  } catch {}
}

async function werkstattOeffnen() {
  await werkstattZeigen();
  if (!$('#werkstatt').open) $('#werkstatt').showModal();
}
$('#werkstatt-oeffnen').addEventListener('click', werkstattOeffnen);

async function werkstattAktion(id, aktion, daten = {}) {
  const res = await fetch(`/api/werkstatt/${id}/${aktion}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-ki31-rolle': rolle() },
    body: JSON.stringify(daten)
  });
  const inhalt = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(inhalt.fehler || `Fehler ${res.status}`), { details: inhalt.details });
  return inhalt;
}

async function werkstattZeigen() {
  const d = await api('/api/werkstatt');
  const ziel = $('#werkstatt-inhalt');
  if (!d.darfBearbeiten) ziel.replaceChildren(el('p', { klasse: 'hinweis', text: 'Ansicht nur lesend. Bearbeiten und Freigeben: Ansicht „31C – IT“ wählen.' }));
  else ziel.replaceChildren();
  if (d.eintraege.length === 0) {
    ziel.append(el('p', { text: 'Noch keine Einträge. Gib KI31 eine Aufgabe, für die es noch kein Werkzeug gibt, z. B. „Erstelle eine Materialliste für die Baustelle“.' }));
    return;
  }
  for (const e of d.eintraege) {
    const meldung = el('p', { klasse: 'meldung', role: 'status' });
    const tue = async (aktion, daten) => {
      meldung.textContent = 'Bitte warten …';
      try {
        await werkstattAktion(e.id, aktion, daten);
        await werkstattZeigen();
        werkstattZaehler();
      } catch (f) {
        meldung.replaceChildren(el('span', { klasse: 'nok', text: f.message }), ...(f.details || []).map((x) => el('div', { klasse: 'nok', text: `• ${x}` })));
      }
    };
    const block = el('section', { klasse: 'ws-eintrag' },
      el('div', { klasse: 'ws-kopf' },
        el('strong', { text: e.spec?.titel || e.anliegen }),
        el('span', { klasse: `abzeichen st-${e.status}`, text: `${WS_STATUS[e.status] || e.status}${e.version ? ` · v${e.version}` : ''}` })),
      el('span', { klasse: 'hinweis', text: `Agent ${e.agent} · Anliegen: „${e.anliegen}“${e.spec ? ` · Art: ${d.arten[e.spec.art] || e.spec.art}` : ''}` }));
    if (e.freigabe) block.append(el('span', { klasse: 'hinweis', text: `Freigegeben für: ${e.freigabe.rollen.map((r) => zustand.status.rollen[r] || r).join(', ')} durch ${e.freigabe.durch}` }));

    if (e.testergebnis) {
      block.append(el('strong', { klasse: e.testergebnis.bestanden ? 'ok' : 'nok', text: e.testergebnis.bestanden ? 'Tests bestanden' : 'Tests nicht bestanden' }),
        el('ul', {}, ...e.testergebnis.faelle.map((f) => el('li', { klasse: f.ok ? 'ok' : 'nok', text: `Test ${f.nr} (${f.auftragId}): ${f.meldungen.join(' ')}` }))));
      const beispiel = e.testergebnis.faelle.find((f) => f.ergebnis)?.ergebnis;
      if (beispiel?.text) block.append(el('details', {}, el('summary', { text: 'Beispielergebnis ansehen' }), el('pre', { text: beispiel.text })));
    }

    const editor = el('textarea', { rows: 12 });
    editor.value = e.spec ? JSON.stringify(e.spec, null, 2) : '';
    editor.readOnly = !d.darfBearbeiten || e.status === 'freigegeben';
    if (e.spec) block.append(el('details', d.darfBearbeiten && e.status !== 'freigegeben' ? { open: '' } : {}, el('summary', { text: 'Beschreibung des Werkzeugs (JSON)' }), editor));

    if (d.darfBearbeiten) {
      const knoepfe = el('div', { klasse: 'knopfzeile' });
      const knopf = (text, fn, leise = true) => knoepfe.append(el('button', { type: 'button', klasse: leise ? 'leise klein' : 'klein', text, onclick: fn }));
      if (['vorschlag', 'entwurf', 'geprueft'].includes(e.status)) {
        knopf(e.spec ? 'Agent soll neu entwerfen' : 'Agent soll Entwurf bauen', () => tue('ki-entwurf'));
        if (e.spec) {
          knopf('Änderungen speichern', () => {
            let spec;
            try { spec = JSON.parse(editor.value); } catch { meldung.textContent = 'Kein gültiges JSON.'; return; }
            tue('entwurf', { spec });
          });
          knopf('Testen', () => tue('testen'));
        }
        knopf('Verwerfen', () => tue('verwerfen'));
      }
      if (e.status === 'geprueft' && d.darfFreigeben) {
        const fk = el('input', { type: 'checkbox' }); fk.checked = true;
        const ma = el('input', { type: 'checkbox' });
        knoepfe.append(el('label', { klasse: 'haken' }, fk, document.createTextNode('Führungskraft')), el('label', { klasse: 'haken' }, ma, document.createTextNode('Mitarbeitende')));
        knopf('Freigeben', () => tue('freigeben', { rollen: [fk.checked && 'fuehrungskraft', ma.checked && 'mitarbeitende'].filter(Boolean) }), false);
      }
      if (e.status === 'freigegeben' && d.darfFreigeben) knopf('Freigabe widerrufen', () => tue('widerrufen'));
      if (['widerrufen', 'verworfen'].includes(e.status)) knopf('Wieder aufnehmen', () => tue('aufnehmen'));
      block.append(knoepfe);
    }
    block.append(el('details', {}, el('summary', { text: 'Verlauf' }), el('ul', {}, ...e.verlauf.map((v) => el('li', { text: `${v.zeit.slice(0, 16).replace('T', ' ')} – ${v.rolle}: ${v.aktion}` })))), meldung);
    ziel.append(block);
  }
}

start().catch((f) => systemZeile(`Start fehlgeschlagen: ${f.message}`));

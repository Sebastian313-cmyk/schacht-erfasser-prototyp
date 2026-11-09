// Anbindung an ein lokales Sprachmodell über Ollama (https://ollama.com).
// Ollama läuft auf dem eigenen Rechner; es fallen keine API-Gebühren an und es verlassen keine
// Daten den Rechner. Adresse und Modell sind über Umgebungsvariablen einstellbar.

export const OLLAMA_URL = (process.env.KI31_OLLAMA_URL || 'http://127.0.0.1:11434').replace(/\/$/, '');
export const MODELL = process.env.KI31_MODELL || 'qwen2.5:7b';

export async function status() {
  try {
    const res = await fetch(`${OLLAMA_URL}/api/tags`, { signal: AbortSignal.timeout(2000) });
    if (!res.ok) return { erreichbar: false, modellVorhanden: false };
    const daten = await res.json();
    const namen = (daten.models || []).map((m) => m.name);
    const modellVorhanden = namen.some((n) => n === MODELL || n === `${MODELL}:latest`);
    return { erreichbar: true, modellVorhanden, modelle: namen };
  } catch {
    return { erreichbar: false, modellVorhanden: false };
  }
}

/**
 * Einmalige Antwort. Mit `schema` liefert Ollama JSON nach diesem JSON-Schema.
 */
export async function chat({ nachrichten, schema, temperatur = 0.2 }) {
  const res = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      model: MODELL,
      messages: nachrichten,
      stream: false,
      ...(schema ? { format: schema } : {}),
      options: { temperature: temperatur }
    })
  });
  if (!res.ok) throw new Error(`Ollama antwortet mit ${res.status}: ${await res.text()}`);
  const daten = await res.json();
  return daten.message?.content ?? '';
}

/**
 * Gestreamte Antwort. Ruft `beiText` für jedes Textstück auf.
 */
export async function chatStream({ nachrichten, temperatur = 0.3, beiText }) {
  const res = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ model: MODELL, messages: nachrichten, stream: true, options: { temperature: temperatur } })
  });
  if (!res.ok || !res.body) throw new Error(`Ollama antwortet mit ${res.status}`);
  const decoder = new TextDecoder();
  let puffer = '';
  for await (const stueck of res.body) {
    puffer += decoder.decode(stueck, { stream: true });
    let zeilenende;
    while ((zeilenende = puffer.indexOf('\n')) >= 0) {
      const zeile = puffer.slice(0, zeilenende).trim();
      puffer = puffer.slice(zeilenende + 1);
      if (!zeile) continue;
      const ereignis = JSON.parse(zeile);
      if (ereignis.error) throw new Error(ereignis.error);
      if (ereignis.message?.content) beiText(ereignis.message.content);
    }
  }
}

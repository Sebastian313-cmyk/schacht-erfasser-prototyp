// Einfache Dateiablage für den Pilot. Alles liegt in data/laufzeit/ auf dem eigenen Rechner.
// Beim ersten Start werden die fiktiven Beispielaufträge übernommen.

import { appendFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const WURZEL = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const DATENORDNER = process.env.KI31_DATEN || path.join(WURZEL, 'data', 'laufzeit');
const BEISPIELE = path.join(WURZEL, 'data', 'beispiel-auftraege.json');

const datei = (name) => path.join(DATENORDNER, name);

async function vorbereiten() {
  await mkdir(DATENORDNER, { recursive: true });
  if (!existsSync(datei('auftraege.json'))) {
    await writeFile(datei('auftraege.json'), await readFile(BEISPIELE, 'utf8'));
  }
}

export async function ladeAuftraege() {
  await vorbereiten();
  return JSON.parse(await readFile(datei('auftraege.json'), 'utf8'));
}

export async function speichereAuftrag(auftrag) {
  const alle = await ladeAuftraege();
  const i = alle.findIndex((a) => a.id === auftrag.id);
  if (i >= 0) alle[i] = auftrag;
  else alle.push(auftrag);
  await writeFile(datei('auftraege.json'), JSON.stringify(alle, null, 2));
  return auftrag;
}

export async function beispieleZuruecksetzen() {
  await mkdir(DATENORDNER, { recursive: true });
  await writeFile(datei('auftraege.json'), await readFile(BEISPIELE, 'utf8'));
}

async function anhaengen(name, eintrag) {
  await vorbereiten();
  await appendFile(datei(name), JSON.stringify(eintrag) + '\n');
}

async function lesenZeilen(name) {
  await vorbereiten();
  if (!existsSync(datei(name))) return [];
  return (await readFile(datei(name), 'utf8'))
    .split('\n')
    .filter(Boolean)
    .map((z) => JSON.parse(z));
}

export async function ladeJson(name) {
  await vorbereiten();
  if (!existsSync(datei(name))) return null;
  return JSON.parse(await readFile(datei(name), 'utf8'));
}

export async function speichereJson(name, daten) {
  await vorbereiten();
  await writeFile(datei(name), JSON.stringify(daten, null, 2));
}

export const speichereMeldeschein =(m) => anhaengen('meldescheine.jsonl', m);
export const ladeMeldescheine = () => lesenZeilen('meldescheine.jsonl');
export const speichereMessung = (m) => anhaengen('messung.jsonl', m);
export const ladeMessungen = () => lesenZeilen('messung.jsonl');
export const protokolliere = (e) => anhaengen('protokoll.jsonl', { zeit: new Date().toISOString(), ...e });

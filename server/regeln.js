// Feste Prüfregeln für einen Auftrag.
// Diese Prüfung läuft immer ohne KI. Sie ist nachvollziehbar und wird nicht vom Sprachmodell
// ersetzt. KI31 darf zusätzliche Hinweise geben, aber keine Pflichtprüfung „wegdiskutieren“.

const leer = (wert) =>
  wert === undefined || wert === null || (typeof wert === 'string' && wert.trim() === '');

/**
 * @returns {{feld: string, stufe: 'fehlt'|'empfohlen'|'klaeren', text: string}[]}
 */
export function pruefeAuftrag(auftrag = {}) {
  const befunde = [];
  const add = (feld, stufe, text) => befunde.push({ feld, stufe, text });

  if (leer(auftrag.auftragsnummer)) add('auftragsnummer', 'fehlt', 'Auftragsnummer fehlt.');
  if (leer(auftrag.auftragsart)) add('auftragsart', 'fehlt', 'Auftragsart (Maurer oder Sanierung) fehlt.');
  if (leer(auftrag.strasse)) add('strasse', 'fehlt', 'Straße fehlt.');
  if (leer(auftrag.weitergebendeAbteilung))
    add('weitergebendeAbteilung', 'fehlt', 'Weitergebende Abteilung fehlt.');
  if (leer(auftrag.eingangsdatum)) add('eingangsdatum', 'fehlt', 'Eingangsdatum fehlt.');
  if (auftrag.terminauftrag && leer(auftrag.ausfuehrungstermin))
    add('ausfuehrungstermin', 'fehlt', 'Terminauftrag ohne Ausführungstermin.');

  const objekte = Array.isArray(auftrag.objekte) ? auftrag.objekte : [];
  if (objekte.length === 0) add('objekte', 'fehlt', 'Es ist noch kein Objekt erfasst.');

  objekte.forEach((o, i) => {
    const nr = `Objekt ${i + 1}`;
    if (leer(o.objektart)) add(`objekte.${i}.objektart`, 'fehlt', `${nr}: Objektart fehlt.`);
    if (o.objektart && o.objektart !== 'Sonstige' && leer(o.objektId))
      add(`objekte.${i}.objektId`, 'fehlt', `${nr} (${o.objektart}): Objekt-ID fehlt.`);
    if (o.objektart === 'Kanal' && leer(o.dn))
      add(`objekte.${i}.dn`, 'fehlt', `${nr} (Kanal): DN-Größe fehlt.`);
    if (leer(o.befund)) add(`objekte.${i}.befund`, 'fehlt', `${nr}: Befund bzw. Schadensbeschreibung fehlt.`);
    if (leer(o.arbeit)) add(`objekte.${i}.arbeit`, 'empfohlen', `${nr}: Auszuführende Arbeit ist noch nicht beschrieben.`);
  });

  const personal = Array.isArray(auftrag.personal) ? auftrag.personal.filter((p) => !leer(p)) : [];
  if (personal.length === 0) add('personal', 'empfohlen', 'Kein Personal zugeordnet.');

  const medien = Array.isArray(auftrag.medien) ? auftrag.medien : [];
  if (medien.length === 0) add('medien', 'empfohlen', 'Keine Fotos oder Medien zum Schaden hinterlegt.');

  if (leer(auftrag.wetter)) add('wetter', 'empfohlen', 'Witterung ist nicht erfasst.');
  if (leer(auftrag.temperatur)) add('temperatur', 'empfohlen', 'Temperatur ist nicht erfasst.');

  // Einstiegserlaubnis: Bei Arbeiten in Einstiegen, Gruben oder Kanälen muss geklärt sein,
  // ob eine Einstiegserlaubnis nötig ist. Die Entscheidung trifft die zuständige Person.
  const einstiegRelevant = objekte.some((o) => ['Einstieg', 'Grube', 'Kanal'].includes(o.objektart));
  const ee = auftrag.einstiegserlaubnis || {};
  if (einstiegRelevant && (ee.erforderlich === undefined || ee.erforderlich === null || ee.erforderlich === ''))
    add('einstiegserlaubnis', 'klaeren', 'Ob eine Einstiegserlaubnis erforderlich ist, ist noch nicht entschieden.');
  if (ee.erforderlich === true && leer(ee.bezirk))
    add('einstiegserlaubnis.bezirk', 'fehlt', 'Einstiegserlaubnis erforderlich, aber Bezirk (West/Ost) fehlt.');

  return befunde;
}

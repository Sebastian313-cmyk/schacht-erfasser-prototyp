// Auswertung des Maßstabs: Wie lange dauert es vom Beginn bis zum übernommenen Meldeschein –
// einschließlich der Kontrolle? Verglichen werden Durchläufe „mit KI“ und „ohne KI“.

function median(werte) {
  if (werte.length === 0) return null;
  const s = [...werte].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : Math.round((s[m - 1] + s[m]) / 2);
}

export function auswerten(messungen = []) {
  const gruppen = {};
  for (const m of messungen) {
    const g = (gruppen[m.modus] ||= { anzahl: 0, gesamt: [], kontrolle: [], geaendert: [], unbrauchbar: 0 });
    g.anzahl += 1;
    if (Number.isFinite(m.gesamtSek)) g.gesamt.push(m.gesamtSek);
    if (Number.isFinite(m.kontrolleSek)) g.kontrolle.push(m.kontrolleSek);
    if (Number.isFinite(m.geaenderteFelder)) g.geaendert.push(m.geaenderteFelder);
    if (m.brauchbar === false) g.unbrauchbar += 1;
  }
  const ergebnis = {};
  for (const [modus, g] of Object.entries(gruppen)) {
    ergebnis[modus] = {
      anzahl: g.anzahl,
      medianGesamtSek: median(g.gesamt),
      medianKontrolleSek: median(g.kontrolle),
      medianGeaenderteFelder: median(g.geaendert),
      unbrauchbar: g.unbrauchbar
    };
  }
  return { gruppen: ergebnis, messungen: messungen.slice(-50).reverse() };
}

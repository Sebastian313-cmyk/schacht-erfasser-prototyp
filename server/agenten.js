// Die Fachagenten von KI31. Jeder Agent kennt die Abläufe seines Bereichs. Welche Werkzeuge
// ihm gehören, steht in werkzeuge.js bzw. in der Werkstatt. Kommt ein Agent nicht weiter, legt
// er in der Werkstatt einen Werkzeugvorschlag an.

export const AGENTEN = {
  KI31: {
    name: 'KI31 – Gehirn',
    auftrag: 'Du verstehst das Anliegen, planst die Arbeitsschritte und verteilst sie an die Fachagenten.',
    stichworte: []
  },
  '311': {
    name: '311 – Zentrale Aufgaben',
    auftrag:
      'Du unterstützt bei Arbeitssicherheit, Koordinierung, Netzsteuerung, Netzeinstieg (HN/AU), ' +
      'Fuhrpark und Betriebsorganisation. Bei Einstiegserlaubnissen bereitest du vor und entscheidest nichts selbst.',
    stichworte: ['einstiegserlaubnis', 'arbeitssicherheit', 'fahrzeug', 'fuhrpark', 'kantine', 'netzsteuerung', 'koordin', 'gefährdung', 'verkehrssicherung', 'absperr']
  },
  '312': {
    name: '312 – Netzwartung und Netzinspektion',
    auftrag:
      'Du unterstützt bei Störung, Service und Wache, Arbeitsplanung, Kanalreinigung, ' +
      'Straßenentwässerung und Kanalinspektion.',
    stichworte: ['reinig', 'spül', 'inspektion', 'tv-', 'kamera', 'störung', 'verstopf', 'straßenentwässerung', 'sinkkasten', 'wache', 'befahr']
  },
  '313': {
    name: '313 – Netzinstandsetzung',
    auftrag:
      'Du unterstützt den Baulichen Unterhalt (BU-B, BU-BS, BU-M Maurer und Sanierung) und den ' +
      'Technischen Unterhalt. Du hilfst, Schäden an Einstiegen, Gruben, Kanälen und ' +
      'Straßensinkkästen sauber zu dokumentieren und Meldescheine vorzubereiten.',
    stichworte: ['mauer', 'sanier', 'schaden', 'riss', 'rahmen', 'steigeisen', 'abdeckung', 'meldeschein', 'schacht', 'material', 'mörtel']
  }
};

export const FACHAGENTEN = ['311', '312', '313'];

/**
 * Wählt den zuständigen Fachagenten nach Stichworten. Ohne Treffer ist 313 zuständig,
 * weil der Pilot BU-M-Aufträge bearbeitet.
 */
export function waehleAgent(nachricht = '') {
  const text = nachricht.toLowerCase();
  let bester = '313';
  let besteTreffer = 0;
  for (const kennung of FACHAGENTEN) {
    const treffer = AGENTEN[kennung].stichworte.filter((s) => text.includes(s)).length;
    if (treffer > besteTreffer) {
      bester = kennung;
      besteTreffer = treffer;
    }
  }
  return bester;
}

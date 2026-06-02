# Word Platzhalter Checkliste

Ziel: DOCX-Vorlagen nur ueber Platzhalter befuellen, nicht ueber Spalten/Koordinaten.

Regeln:
- In jede Zielzelle einen eindeutigen Platzhalter setzen: `{{...}}`
- Layout, Tabellen, Zeilen und Spalten nicht aendern
- JA/NEIN Felder: ausgewaehlt => `X`, nicht ausgewaehlt => leer
- Nach Export duerfen keine `{{...}}` mehr sichtbar sein
- Stil der eingesetzten Werte: Arial, 11pt, fett, rot (#FF0000)

## ES Vorlage (Einstiegsschaechte)
Diese Platzhalter sind fuer die ES Vorlage vorgesehen:

- `{{auftragsnummer}}`
- `{{datum}}`
- `{{name}}`
- `{{strasse}}`
- `{{schachtnummer}}`
- `{{schachtdurchmesser}}`
- `{{kanalprofil}}`

- `{{hauptstrasse}}`
- `{{nebenstrasse}}`
- `{{spuren}}`
- `{{kreuzung}}`
- `{{baustellensicherung}}`
- `{{einbahnstrasse}}`
- `{{geh_radweg}}`

- `{{asphalt}}`
- `{{teerhaltig}}`
- `{{grossstein}}`
- `{{kleinstein}}`
- `{{kupla}}`
- `{{oberflaeche_sonstige}}`
- `{{gruenflaeche}}`
- `{{baum_in_der_naehe}}`
- `{{baum_zusatz}}`

- `{{mannloch}}`
- `{{begu_dn_625}}`
- `{{schachtkopf_sonstige}}`
- `{{ausgleichsringe}}`
- `{{uebergangsplatte}}`
- `{{konus_dn_625_ohne_versatz}}`
- `{{konus_dn_700_mit_versatz}}`
- `{{steigeisen_alt}}`
- `{{steigeisen_neu}}`
- `{{leiter}}`
- `{{sonstige}}`

- `{{konusanfang}}`
- `{{steighoehe_1_steigeisen}}`
- `{{steighoehe_2_steigeisen}}`
- `{{mass_815}}`
- `{{rueckenfreiheit_1_steigeisen}}`
- `{{konusende}}`
- `{{rueckenfreiheit_2_steigeisen}}`
- `{{schachtdurchmesser_skizze}}`
- `{{berme}}`
- `{{solltiefe}}`

## Sickergruben Vorlage
Empfohlene Platzhalter fuer die Sickergruben Vorlage:

- `{{auftragsnummer}}`
- `{{datum}}`
- `{{name}}`
- `{{strasse}}`

- `{{witterung_sonne}}`
- `{{witterung_regen}}`
- `{{witterung_letzter_niederschlag}}`

- `{{grubenart_kb_schacht}}`
- `{{grubenart_din}}`
- `{{grubenart_gemauert}}`

- `{{grubentiefe_cm}}`

- `{{wasserstand_ja}}`
- `{{wasserstand_nein}}`
- `{{wasserstand_cm}}`

- `{{baujahr}}`

- `{{anschluss_vorhanden_ja}}`
- `{{anschluss_vorhanden_nein}}`

- `{{anschluss_offen_ja}}`
- `{{anschluss_offen_nein}}`

- `{{filtersand_ja}}`
- `{{filtersand_nein}}`

- `{{filtersand_locker}}`
- `{{filtersand_sickerfaehig}}`
- `{{filtersand_fest}}`
- `{{filtersand_lehmig}}`

## Schnelltest nach Umbau
1. Vorlage in Word oeffnen und alle Zielzellen auf `{{...}}` pruefen.
2. Ein Export mit Testdaten ausfuehren.
3. Ergebnis-DOCX oeffnen und pruefen:
- keine Platzhalter mehr sichtbar
- JA/NEIN Felder korrekt mit `X`
- Werte stehen in den richtigen Zellen
- Schrift ist rot/fett/Arial 11

## Hinweis zum aktuellen Code
Die App ersetzt jetzt Platzhalter vorrangig. Falls in einer Vorlage noch keine Platzhalter vorhanden sind, wird als Rueckfall weiter die alte Label-Logik versucht.
# Word Mapping App-Feld -> Platzhalter

Diese Datei beschreibt das 1:1 Mapping fuer den Platzhalter-Export.
Quelle sind die tatsaechlich gespeicherten Meta-Felder aus den Modulen.

Hinweis zur Ausgabe:
- Text/Zahl: direkter Wert
- Checkbox/Option: ausgewaehlt => X, sonst leer
- Leere/fehlende Werte => leer

## ES (Einsteigschaechte)
Meta-Quelle: Eintrag mit `typ = ES`

Basis:
- `meta.evnr` + `meta.posNr` -> `{{auftragsnummer}}` (Format z. B. `25300/1`)
- `meta.zeitIso` -> `{{datum}}` (formatiert)
- `meta.erfasser` -> `{{name}}`
- `meta.strasse` -> `{{strasse}}`
- `meta.posNr` -> `{{schachtnummer}}`
- `meta.durchmesser` -> `{{schachtdurchmesser}}`
- `meta.kanalprofil` -> `{{kanalprofil}}`

Oertlichkeit (`meta.oertlichkeit`, CSV):
- enthaelt `Hauptstraße` -> `{{hauptstrasse}}`
- enthaelt `Nebenstraße` -> `{{nebenstrasse}}`
- enthaelt `Spuren` -> `{{spuren}}`
- enthaelt `Kreuzung` -> `{{kreuzung}}`
- enthaelt `Baustellensicherung` -> `{{baustellensicherung}}`
- enthaelt `Einbahnstraße` -> `{{einbahnstrasse}}`
- enthaelt `Geh-/Radweg` -> `{{geh_radweg}}`

Oberflaeche (`meta.oberflaeche`, CSV):
- enthaelt `Asphalt` -> `{{asphalt}}`
- enthaelt `teerhaltig` -> `{{teerhaltig}}`
- enthaelt `Großstein` -> `{{grossstein}}`
- enthaelt `Kleinstein` -> `{{kleinstein}}`
- enthaelt `Kupla` -> `{{kupla}}`
- enthaelt `Sonstige` -> `{{oberflaeche_sonstige}}`
- enthaelt `Grünfläche` -> `{{gruenflaeche}}`
- enthaelt `Baum in der Nähe` -> `{{baum_in_der_naehe}}`
- `meta.obflBem` -> `{{baum_zusatz}}`

Schachtkopf (`meta.schachtkopf`, CSV) + Deckel:
- `meta.deckel` beginnt mit `Mannloch` -> `{{mannloch}}`
- `meta.deckel` beginnt mit `Begu DN 625` -> `{{begu_dn_625}}`
- `meta.deckel` beginnt mit `Bemerkung:` -> `{{schachtkopf_sonstige}}`
- enthaelt `Ausgleichsringe` -> `{{ausgleichsringe}}`
- enthaelt `Übergangsplatte (Höhe)` -> `{{uebergangsplatte}}`
- enthaelt `Konus DN 625 o. Versatz` -> `{{konus_dn_625_ohne_versatz}}`
- enthaelt `Konus DN 700 m. Versatz` -> `{{konus_dn_700_mit_versatz}}`

Einsteigart:
- `meta.einsteigart = Steigeisen` und `meta.steigeisenStand = Alt` -> `{{steigeisen_alt}}`
- `meta.einsteigart = Steigeisen` und `meta.steigeisenStand = Neu` -> `{{steigeisen_neu}}`
- `meta.einsteigart = Leiter` -> `{{leiter}}`
- sonstiger Freitext/Abweichung -> `{{sonstige}}`

Masse:
- `meta.mKonusAnf` -> `{{konusanfang}}`
- `meta.st1Hoehe` -> `{{steighoehe_1_steigeisen}}`
- `meta.st2Hoehe` -> `{{steighoehe_2_steigeisen}}`
- `meta.mAusgleich` -> `{{mass_815}}`
- `meta.st1Rf` -> `{{rueckenfreiheit_1_steigeisen}}`
- `meta.mKonusEnd` -> `{{konusende}}`
- `meta.st2Rf` -> `{{rueckenfreiheit_2_steigeisen}}`
- `meta.durchmesser` -> `{{schachtdurchmesser_skizze}}`
- `meta.mBerme` -> `{{berme}}`
- `meta.mSolltiefe` -> `{{solltiefe}}`

## Sickergruben / Gruben (VS)
Meta-Quelle: Eintrag mit `typ = VS`

Basis:
- `meta.evnr` + `meta.posNr` -> `{{auftragsnummer}}` (Format z. B. `25300/11`)
- `meta.zeitIso` -> `{{datum}}` (formatiert)
- `meta.erfasser` -> `{{name}}`
- `meta.strasse` -> `{{strasse}}`

Witterung (`meta.wetter`):
- `klar` -> `{{witterung_sonne}}`
- `regen` -> `{{witterung_regen}}`
- optional Zusatz aus Bemerkung -> `{{witterung_letzter_niederschlag}}`

Grubenart (`meta.grubentyp`):
- `KB-Schacht` -> `{{grubenart_kb_schacht}}`
- `DIN` (falls genutzt) -> `{{grubenart_din}}`
- `Gemauert` (falls genutzt) -> `{{grubenart_gemauert}}`

Messwerte:
- `meta.tiefe_cm` (oder aus `meta.tiefe_m`) -> `{{grubentiefe_cm}}`
- `meta.wasser_cm` -> `{{wasserstand_cm}}`
- `meta.baujahr` -> `{{baujahr}}`

Wasserstand JA/NEIN:
- `meta.wasser_cm` hat Wert > 0 -> `{{wasserstand_ja}}`
- sonst -> `{{wasserstand_nein}}`

Anschluss:
- `meta.anschlussJa = true` -> `{{anschluss_vorhanden_ja}}`
- `meta.anschlussJa = false` -> `{{anschluss_vorhanden_nein}}`

Ueberlauf offen:
- `meta.teller = offen` -> `{{anschluss_offen_ja}}`
- `meta.teller = nicht offen` -> `{{anschluss_offen_nein}}`

Filtersand:
- `meta.filtersandJa = true` -> `{{filtersand_ja}}`
- `meta.filtersandJa = false` -> `{{filtersand_nein}}`
- `meta.filtersandEigensch` enthaelt `locker` -> `{{filtersand_locker}}`
- `meta.filtersandEigensch` enthaelt `sickerfähig` -> `{{filtersand_sickerfaehig}}`
- `meta.filtersandEigensch` enthaelt `fest` -> `{{filtersand_fest}}`
- `meta.filtersandEigensch` enthaelt `lehmig` -> `{{filtersand_lehmig}}`

## Technische Empfehlung fuer Export-Builder
Beim Aufbau der `replacements` Liste nur noch Platzhalter-Keys liefern:
- `(auftragsnummer, 25300/1)`
- `(wasserstand_ja, X)`
- `(wasserstand_nein, )`

Dann kann der DOCX-Service stabil per `{{key}}` ersetzen, ohne Spalten/Position zu raten.
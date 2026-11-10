# KI31 – Konzept und Ausbaustufen

Stand: 10. November 2026 · Pilot 0.2

## Leitidee

**KI31 ist das Gehirn**, kein Chatprogramm. Das Sprachmodell ist darin nur das Sprachzentrum.

| Teil | In KI31 |
|---|---|
| Wahrnehmen | Auftrag, Eingaben, später Fotos, Standort, Wetter |
| Verstehen | lokales Sprachmodell oder feste Regeln → Arbeitsschritte |
| Wissen | Prüfregeln, Abläufe, Organisation 311/312/313 |
| Entscheiden | Plan, Zuordnung jedes Schritts zum Agenten, dem das Werkzeug gehört |
| Handeln | Werkzeuge: Felder ausfüllen, Anträge und Meldescheine vorbereiten |
| Gedächtnis | Protokoll aller Schritte |
| Gewissen (31C) | Rechte je Rolle und Werkzeug, Freigaben |
| Wachsen | Werkstatt |

KI31 ist der Assistent des Kanalbetriebs 31. Man spricht oder schreibt mit ihm, während man einen
Auftrag bearbeitet. KI31 versteht den Zusammenhang, erkennt fehlende Angaben und bereitet den
nächsten Arbeitsschritt vor. **Entscheidungen bleiben bei der zuständigen Person**: Weitergabe eines
Meldescheins, Einstiegserlaubnis, Freigabe von Werkzeugen.

Erster Maßstab: *Hilft KI31, aus einem Auftrag schneller einen brauchbaren Meldeschein zu machen –
einschließlich der Zeit für die Kontrolle?*

## Architektur

```
            Browser (Auftragsmaske, Chat, Meldeschein)
                              │
                     KI31-Server (Node.js)
     ┌──────────────┬─────────┴─────────┬──────────────────┐
  31C-Rechte    KI31-Zuordnung     Prüfregeln         Ablage / Protokoll
 (Rolle →       (311 / 312 / 313)  (ohne KI)          (Aufträge, Meldescheine,
  Werkzeuge)          │                                Messungen)
               Fachagent mit Auftrag
               und erlaubten Werkzeugen
                      │
            lokales Sprachmodell (Ollama)
```

Grundsätze, die auch in späteren Stufen gelten:

1. **Rechte prüft der Server, nicht das Modell.** Ein Werkzeug, das 31C für eine Rolle nicht
   freigibt, wird nicht ausgeführt – egal, was im Chat steht.
2. **Feste Regeln vor KI.** Pflichtangaben prüfen feste Regeln. Das Modell ergänzt Hinweise, kann
   Pflichtprüfungen aber nicht abschalten. Offene Pflichtpunkte werden in jeden Meldeschein-Entwurf
   übernommen.
3. **Strukturierte Ausgabe.** Der Meldeschein kommt als JSON nach festem Schema. Werte außerhalb der
   erlaubten Listen (Empfänger, Dringlichkeit) werden verworfen.
4. **Vorschlag, Prüfung, Übernahme.** KI31 schreibt Entwürfe. Gespeichert wird erst nach
   ausdrücklicher Übernahme durch eine berechtigte Person.
5. **Protokoll.** Jede Werkzeugnutzung wird mit Rolle, Agent, Modell und Ergebnisart protokolliert
   (`data/laufzeit/protokoll.jsonl`).
6. **Lokal.** Modell und Daten bleiben auf dem Rechner bzw. später auf der IT-Infrastruktur.
   Modell- und Softwareversionen werden gezielt eingespielt (`KI31_MODELL`), nicht automatisch
   aktualisiert.

## Ausbaustufen

### Stufe 1 – Pilot Meldeschein (dieser Stand)

- BU-M-Auftrag, Prüfung, Zusammenfassung, Meldeschein-Entwurf, Chat
- regelbasierte Zuordnung zu 311/312/313, zwei Testrollen
- Messung „mit KI“ und „ohne KI“
- fiktive Daten, Einzelplatz

**Entscheidung danach:** Trägt der Ablauf? Ziel z. B. Median „mit KI“ deutlich unter „ohne KI“
bei höchstens wenigen unbrauchbaren Entwürfen. Gleichzeitig auswählen, welches lokale Modell bei
vertretbarer Hardware die besten Entwürfe liefert.

### Stufe 2 – Einbindung in die Arbeitsplattform

- KI31-Panel in die BU-M-Auftragsmaske der bestehenden Webanwendung einbauen. Dafür wird der
  Quellcode der Anwendung im Repository benötigt („Anwendung herunterladen“).
- Datenübergabe Auftrag → KI31 über eine feste Schnittstelle statt über eigene Ablage
- übernommener Meldeschein → bestehender Meldeschein-Ablauf (Empfänger nimmt an, meldet zurück)
- lokale Spracherkennung (z. B. whisper.cpp) statt Browser-Spracherkennung
- Fotos: optional ein lokales Bildmodell, das Schadensfotos beschreibt (nur als Vorschlag)

### Stufe 3 – Fachagenten mit Werkzeugen

- Werkzeuge als Funktionen mit Beschreibung, die das Modell aufrufen darf (Tool-Calling), z. B.
  „Einstiegserlaubnis-Antrag vorbereiten“ (311), „Reinigung anfragen“ (312), „BU-BS-Erfassung
  übernehmen“ (313)
- Zuordnung zu Fachagenten durch das Modell, abgesichert durch die regelbasierte Zuordnung
- Wissen je Bereich: Arbeitsanweisungen und Formulare aus der Dokumentensuche als Nachschlagequelle
  (lokale Suche, Quellenangabe in der Antwort)
- 31C mit echten Personen-, Abteilungs- und Ordnerrechten (setzt Anmeldung auf dem Server voraus)

### Stufe 4 – Werkzeugwerkstatt (Selbsterweiterung unter Kontrolle)

**Erster Stand umgesetzt (Pilot 0.2):** Findet KI31 kein Werkzeug, legt der zuständige Agent einen
Vorschlag an, baut einen Entwurf, testet ihn mit den fiktiven Testaufträgen, und 31C gibt ihn für
bestimmte Rollen frei oder widerruft ihn. Werkzeuge bestehen aus sicheren Bausteinen
(Textvorlage, Prüfregeln, Feldänderungen) – nicht aus Programmcode. Weitere Bausteine, z. B.
Berechnungen oder Tabellen, kommen dazu, wenn die Agenten sie brauchen.

Idee: KI31 bemerkt, dass bei einem wiederkehrenden Arbeitsschritt ein Werkzeug fehlt, schlägt eine
Lösung vor, baut in einer getrennten Werkstatt einen Entwurf und prüft ihn mit Testdaten. 31C
gibt das Werkzeug frei.

Vorgeschlagener Ablauf:

1. **Bedarf erkennen** – aus dem Protokoll: wiederkehrende Bitten, die kein Werkzeug abdeckt.
   KI31 legt einen *Werkzeugvorschlag* an (Zweck, Ein- und Ausgaben, Bereich, nötige Rechte).
2. **Entwurf bauen** – in einer abgeschotteten Werkstatt ohne Zugriff auf Echtdaten, Netz und
   Produktivablage. Ein Werkzeug ist dort eine kleine Funktion mit festgelegter Schnittstelle.
3. **Prüfen** – automatische Tests mit Testdaten aus der Testzentrale, ergänzt um Fälle, die die
   Fachseite vorgibt. Ergebnis und Quellcode werden für die Freigabe aufbereitet.
4. **Freigeben** – 31C prüft Code, Tests und Rechte und gibt frei, für welche Rollen und Bereiche.
   Ohne Freigabe ist das Werkzeug nicht verfügbar.
5. **Versionieren und zurücknehmen** – jedes Werkzeug hat eine Version. Eine Freigabe lässt sich
   jederzeit widerrufen.

Wichtig: Die Selbsterweiterung bleibt immer *Vorschlag + Prüfung + Freigabe durch Menschen*.
KI31 ändert produktive Werkzeuge nie selbst.

### Stufe 5 – Betrieb durch die IT

- Betrieb auf IT-Infrastruktur mit GPU-Server für das Modell, Anmeldung (z. B. über den
  Verzeichnisdienst), zentrale Datenhaltung, Datensicherung
- Datenschutz-Folgenabschätzung, Beteiligung Personalrat (Zeitmessung und Protokoll betreffen
  Beschäftigte), Löschfristen
- festgelegter Ablauf für neue Modell- und Softwareversionen: Testlauf mit gleichem Testbestand,
  Vergleich der Messwerte, dann gezielte Freigabe

## Offene Fragen an die Fachseite

- Welche Felder hat der Papier-Meldeschein genau? Das Schema im Pilot ist eine Annahme.
- Nach welchen Regeln wird heute der Empfänger gewählt? Diese Regeln könnten fest hinterlegt werden
  und das Modell entlasten.
- Wann ist ein Meldeschein „dringend“ bzw. „sofort“?
- Welche Angaben sind für die Einstiegserlaubnis aus dem Auftrag zwingend?

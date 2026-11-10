# CLAUDE.md – Arbeitsregeln für Claude in diesem Repository

## Projekt

Arbeitsplattform des Kanalbetriebs 31 und der KI-Assistent **KI31**.
- `server/`, `public/`, `test/`, `data/`: KI31-Pilot (Node.js, ohne npm-Abhängigkeiten)
- `docs/KONZEPT.md`: Architektur und Ausbaustufen von KI31 – vor größeren Änderungen lesen
- `arbeitsplattform/`: Quellcode der bestehenden Webanwendung (folgt, Ordner „Kanalbetrieb“)
- Branch `import/erfasser-app`: Erfasser-App (Flutter) – Vorbild für Formulare,
  vorgefertigte Vorlagen in `assets/App/Formulare/`
- Arbeitsordner des Nutzers am PC: `C:\Users\sgbgr\Desktop\KI31` (nur per Remote Control erreichbar)

## Schreibtisch – wo Claude arbeiten darf

- Ändern nur innerhalb dieses Repositorys und nur auf dem zugewiesenen Arbeitsbranch.
- In `arbeitsplattform/` zuerst lesen und einen Vorschlag machen. Erst nach Zustimmung umbauen.
- Nichts löschen oder großflächig umstrukturieren ohne Rückfrage.
- Kein Pull Request und kein Merge ohne ausdrücklichen Auftrag.

## Daten und Sicherheit

- Nur **fiktive Testdaten**. Keine echten Personen-, Auftrags- oder Standortdaten ins Repository.
- Keine Passwörter, Tokens oder Zugangsschlüssel im Code. Fällt so etwas auf: melden, nicht verwenden.
- KI31 läuft **lokal** (Ollama). Keine Cloud-KI-Dienste einbauen und keine Daten an externe Dienste
  senden ohne ausdrückliche Zustimmung.
- Rechte (31C) prüft immer der Server, nie das Sprachmodell oder der Browser.

## Fachliche Grundsätze für KI31

- KI31 bereitet vor, Menschen entscheiden: Weitergabe von Meldescheinen, Einstiegserlaubnis,
  Freigabe neuer Werkzeuge.
- Feste Prüfregeln vor KI. Das Modell darf Pflichtprüfungen nicht ersetzen.
- KI-Ausgaben in festen Schemata. Werte außerhalb erlaubter Listen werden verworfen.
- Formulare wie in der Erfasser-App: vorgefertigte Vorlagen mit nummerierten Feldern. KI31 füllt
  nur aus (Feldplan je Formular), markiert Fehlendes statt zu erfinden, ein Mensch prüft vor dem Download.
- Agenten erweitern sich nie selbst: Werkstatt nur mit Genehmigung von KI31, Nutzung nur nach Freigabe durch 31C.
- Erster Maßstab: schneller zu einem brauchbaren Meldeschein, einschließlich Kontrollzeit.

## Sprache und Stil

- Oberfläche, Kommentare, Dokumentation und Commit-Nachrichten auf **Deutsch**.
- Fachbegriffe des Kanalbetriebs verwenden (Einstieg, Objekt-ID, DN, Meldeschein, BU-M, BU-BS …).
- Antworten an den Nutzer kurz und verständlich, auch für die Lektüre am Handy.

## Prüfen vor dem Commit

- `npm test` muss grün sein.
- Bei Oberflächenänderungen im Demo-Modus (`npm run demo`) im Browser prüfen, auch in Handybreite.

# KI31 – lokaler KI-Assistent für den Kanalbetrieb 31 (Pilot)

KI31 unterstützt bei der Bearbeitung von BU-M-Aufträgen. Der erste Stand konzentriert sich auf
einen Arbeitsablauf: **aus einem Auftrag einen geprüften Meldeschein machen**, und misst, ob das
mit KI schneller geht – einschließlich der Zeit für die Kontrolle.

- läuft vollständig auf dem eigenen Rechner, ohne laufende API-Gebühren
- Sprachmodell lokal über [Ollama](https://ollama.com)
- nur **fiktive Testdaten**
- keine npm-Abhängigkeiten, nur Node.js

Architektur, Ausbaustufen und offene Fragen: [docs/KONZEPT.md](docs/KONZEPT.md).

## Aufbau: KI31 ist das Gehirn

```
Anliegen („DN ist 300, Bezirk Ost, Einstiegserlaubnis brauchen wir“)
   │
KI31 – Gehirn: verstehen → planen → an Agenten verteilen → nächsten Schritt vorschlagen
   │
   ├── Agent 311 Zentrale Aufgaben      → z. B. Einstiegserlaubnis vorbereiten
   ├── Agent 312 Netzwartung/-inspektion → z. B. Reinigung oder Inspektion anfragen
   └── Agent 313 Netzinstandsetzung      → z. B. Meldeschein entwerfen
   │
   kein Werkzeug passt? → Werkstatt: Vorschlag → Entwurf → Test → Freigabe durch 31C
```

Das Sprachmodell ist nur das „Sprachzentrum“ von KI31. Ohne Modell versteht KI31 feste
Formulierungen über Regeln (Demo-Modus). Rechte, Prüfregeln und Freigaben liegen immer im Server.

## Was der Pilot kann

| Funktion | So funktioniert sie |
|---|---|
| Anliegen | Sprechen oder schreiben. KI31 plant die Arbeitsschritte, zeigt den Plan und gibt jeden Schritt an den zuständigen Agenten. |
| Felder ausfüllen | KI31 trägt Angaben ein, z. B. DN, Objekt-ID, Bezirk, Einstiegserlaubnis, Termin, Wetter, Temperatur, Personal. Die Änderungen erscheinen als Vorschlag mit alt → neu. Erst „Bestätigen“ übernimmt sie. Nur freigegebene Felder, alle Werte werden geprüft. |
| Nächster Schritt | Nach jedem Anliegen schlägt KI31 vor, was als Nächstes sinnvoll ist, z. B. offene Pflichtangaben, Einstiegserlaubnis oder Meldeschein. |
| Agent 311 | Einstiegserlaubnis-Antrag vorbereiten, mit offenen Punkten. Die Entscheidung trifft die zuständige Person. |
| Agent 312 | Reinigung oder TV-Inspektion als Meldeschein-Entwurf anfragen |
| Agent 313 | Meldeschein entwerfen. Empfänger nur aus der Organisationsliste, offene Pflichtpunkte immer unter „Offene Punkte“. |
| Werkstatt | Findet KI31 kein Werkzeug, legt der zuständige Agent einen Vorschlag an, baut einen Entwurf und testet ihn mit den fiktiven Testaufträgen. 31C prüft, ändert und gibt für bestimmte Rollen frei oder widerruft. |
| Sichere Bausteine | Werkstatt-Werkzeuge sind kein Programmcode, sondern Beschreibungen aus drei Bausteinen: Textvorlage, Prüfregeln, Feldänderungen (immer als Vorschlag). |
| Fehlende Angaben | Feste Prüfregeln ohne KI markieren Pflichtfelder rot und Klärungsbedarf orange. |
| 31C-Rechte | Drei Testrollen: Führungskraft, Mitarbeitende, 31C – IT. Der Server prüft jedes Werkzeug. |
| Messung | Durchläufe „mit KI“ und „ohne KI“ bis zum übernommenen Meldeschein, inklusive Kontrollzeit |
| Demo-Modus | Ohne Modell versteht KI31 feste Formulierungen und baut Grundentwürfe in der Werkstatt. |

### Ausprobieren (auch im Demo-Modus)

1. Auftrag „…0143“ öffnen und schreiben: *DN ist 300, Bezirk Ost, Einstiegserlaubnis brauchen wir. Termin am 20.11.2026*
   → Vorschlag bestätigen → KI31 schlägt „Antrag Einstiegserlaubnis vorbereiten“ vor.
2. Schreiben: *Erstelle eine Materialliste für die Baustelle* → Agent 313 hat kein Werkzeug →
   Eintrag in der Werkstatt mit getestetem Entwurf.
3. Ansicht „31C – IT“ → Werkstatt → Entwurf ansehen, ändern, testen, freigeben.
4. Zurück zu „Führungskraft“ → *Materialliste bitte* → KI31 nutzt das neue Werkzeug.

## Installation (Windows, macOS oder Linux)

1. **Node.js 20 oder neuer** installieren: https://nodejs.org
2. **Ollama** installieren: https://ollama.com/download
3. Ein Sprachmodell laden (einmalig, einige GB):
   ```
   ollama pull qwen2.5:7b
   ```
4. Dieses Repository herunterladen und im Ordner starten:
   ```
   npm start
   ```
5. Im Browser öffnen: http://localhost:3131

Ohne Ollama: `npm run demo` startet den Demo-Modus.

### Einstellungen (Umgebungsvariablen)

| Variable | Standard | Bedeutung |
|---|---|---|
| `KI31_MODELL` | `qwen2.5:7b` | Ollama-Modell. Andere Modelle lassen sich so vergleichen. |
| `KI31_OLLAMA_URL` | `http://127.0.0.1:11434` | Adresse von Ollama |
| `KI31_MODUS` | – | `demo` erzwingt den Betrieb ohne KI |
| `PORT` | `3131` | Port der Anwendung |
| `KI31_HOST` | `127.0.0.1` | Nur vom eigenen Rechner erreichbar. `0.0.0.0` öffnet sie im Netz – im Pilot nicht empfohlen, da es noch keine Anmeldung gibt. |
| `KI31_DATEN` | `data/laufzeit` | Ablage für Aufträge, Meldescheine, Messungen und Protokoll |

Beispiel (macOS/Linux): `KI31_MODELL=llama3.1:8b npm start`
Beispiel (Windows PowerShell): `$env:KI31_MODELL="llama3.1:8b"; npm start`

**Hardware:** Ein 7–8B-Modell braucht etwa 8 GB freien Arbeitsspeicher. Mit Grafikkarte oder
Apple-Silicon antwortet es in Sekunden, nur mit Prozessor deutlich langsamer. Das gehört zur
Messung dazu.

## So prüfst du den Maßstab

1. Ansicht **Führungskraft** wählen.
2. Durchlauf **ohne KI**: Auftrag öffnen, „Leeren Meldeschein beginnen“, selbst ausfüllen, übernehmen.
3. Durchlauf **mit KI**: anderen Auftrag öffnen, „Meldeschein entwerfen“, prüfen, korrigieren,
   „Entwurf brauchbar?“ beantworten, übernehmen.
4. **Auswertung** öffnen. Für eine belastbare Aussage mehrere Aufträge je Durchlauf bearbeiten
   und die Reihenfolge wechseln.

„Beispieldaten zurücksetzen“ stellt die fiktiven Aufträge wieder her. Messungen bleiben erhalten.
Zum Löschen den Ordner `data/laufzeit` entfernen.

## Tests

```
npm test
```

Die Tests simulieren einen Ollama-Server und prüfen Prüfregeln, Agentenwahl,
Meldeschein-Bereinigung, 31C-Rechte, Gehirn-Ablauf, Werkstatt-Lebenszyklus und Auswertung.

## Projektaufbau

```
server/
  server.js         HTTP-Server und Schnittstellen
  gehirn.js         KI31: verstehen, planen, verteilen, Lücken an die Werkstatt
  verstehen.js      Verstehen ohne Modell (feste Formulierungen)
  werkzeuge.js      Werkzeuge der Agenten (eingebaut + freigegebene Werkstatt-Werkzeuge)
  werkstatt.js      Werkstatt: Vorschlag, Entwurf, Prüfung, Test, Freigabe, Widerruf
  felder.js         Felder, die KI31 ändern darf, mit Wertprüfung
  ki.js             Funktionen mit Sprachmodell und Demo-Vorlagen
  ollama.js         Anbindung an das lokale Modell
  regeln.js         feste Prüfregeln für Pflichtangaben
  agenten.js        Fachagenten 311/312/313
  berechtigungen.js 31C: welche Rolle welches Werkzeug nutzen darf
  organisation.js   Empfängerliste, Objektarten, Dringlichkeiten
  speicher.js       Dateiablage in data/laufzeit
  auswertung.js     Kennzahlen der Messung
public/             Oberfläche (HTML, CSS, JavaScript)
data/               fiktive Beispielaufträge
test/               automatische Tests
docs/KONZEPT.md     Architektur und Ausbaustufen
```

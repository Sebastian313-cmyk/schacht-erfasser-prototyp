# KI31 – lokaler KI-Assistent für den Kanalbetrieb 31 (Pilot)

KI31 unterstützt bei der Bearbeitung von BU-M-Aufträgen. Der erste Stand konzentriert sich auf
einen Arbeitsablauf: **aus einem Auftrag einen geprüften Meldeschein machen**, und misst, ob das
mit KI schneller geht – einschließlich der Zeit für die Kontrolle.

- läuft vollständig auf dem eigenen Rechner, ohne laufende API-Gebühren
- Sprachmodell lokal über [Ollama](https://ollama.com)
- nur **fiktive Testdaten**
- keine npm-Abhängigkeiten, nur Node.js

Architektur, Ausbaustufen und offene Fragen: [docs/KONZEPT.md](docs/KONZEPT.md).

## Was der Pilot kann

| Funktion | So funktioniert sie |
|---|---|
| Auftragsmaske | BU-M-Auftrag mit Objekten (Objektart, Objekt-ID, DN, Befund, Arbeit), Personal, Wetter, Medien, Einstiegserlaubnis |
| Fehlende Angaben | Feste Prüfregeln (ohne KI, nachvollziehbar) markieren Pflichtfelder rot und Klärungsbedarf orange. Das Modell ergänzt höchstens drei inhaltliche Hinweise. |
| Zusammenfassen | Kurzüberblick über Ort, Objekte, Schaden, Arbeit und Stand |
| Meldeschein entwerfen | KI31 füllt Empfänger, angeforderte Leistung, Begründung, Dringlichkeit, Ort, Objektbezug, Hinweise und offene Punkte. Empfänger nur aus der Organisationsliste. Offene Pflichtangaben landen immer in „Offene Punkte“. |
| Prüfen und übernehmen | Der Entwurf ist frei änderbar. Erst „Übernehmen“ speichert ihn. Die Weitergabe selbst entscheidet die zuständige Person. |
| Chat | Fragen zum geöffneten Auftrag, auch mit ungespeicherten Änderungen. Bitten wie „Entwirf einen Meldeschein“ lösen das passende Werkzeug aus. |
| Fachagenten | KI31 ordnet eine Anfrage 311, 312 oder 313 zu. Im Pilot geschieht das regelbasiert und wird angezeigt. |
| 31C-Rechte | Ansicht „Mitarbeitende“ darf zusammenfassen und prüfen, aber keinen Meldeschein entwerfen oder übernehmen. Die Prüfung erfolgt auf dem Server. |
| Messung | Durchläufe „mit KI“ und „ohne KI“ werden gestoppt. Die Auswertung zeigt Median der Gesamtdauer, Kontrollzeit, geänderte Felder und unbrauchbare Entwürfe. |
| Demo-Modus | Ohne Modell laufen Vorlagen statt KI. Damit lassen sich Oberfläche und Ablauf sofort testen. |

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
Meldeschein-Bereinigung, 31C-Rechte, Chat-Streaming und Auswertung.

## Projektaufbau

```
server/
  server.js         HTTP-Server und Schnittstellen
  ki.js             KI-Funktionen und Systemtexte, Demo-Vorlagen
  ollama.js         Anbindung an das lokale Modell
  regeln.js         feste Prüfregeln für Pflichtangaben
  agenten.js        Fachagenten 311/312/313, Zuordnung, Werkzeugerkennung
  berechtigungen.js 31C: welche Rolle welches Werkzeug nutzen darf
  organisation.js   Empfängerliste, Objektarten, Dringlichkeiten
  speicher.js       Dateiablage in data/laufzeit
  auswertung.js     Kennzahlen der Messung
public/             Oberfläche (HTML, CSS, JavaScript)
data/               fiktive Beispielaufträge
test/               automatische Tests
docs/KONZEPT.md     Architektur und Ausbaustufen
```

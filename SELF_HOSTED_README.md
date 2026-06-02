# 🎯 SELF-HOSTED UPDATES - READY TO GO!

## ✅ Was wurde implementiert?

Ein **komplett eigenständiges Update-System** ohne externe Server:

### 🌐 **Web-App als Update-Quelle**
- Die Web-App hostet selbst alle Downloads
- Version-Check über `version.json` im Web-Verzeichnis
- Desktop/Mobile Apps laden Updates von der Web-URL

### 📦 **Automatische Build & Deploy Scripts**
- `build-deploy.sh` (Linux/macOS) 
- `build-deploy.bat` (Windows)
- Baut alle Plattformen + Web
- Deployt automatisch zu Firebase/GitHub/Netlify

### 🔄 **Smart Update-Dialog**
- Automatischer Check beim App-Start
- Schöner Material Design Dialog
- Release Notes anzeigen
- Force-Update Unterstützung

---

## 🚀 SOFORT STARTEN (3 Schritte)

### Schritt 1: Script ausführen

```bash
# Linux/macOS
chmod +x build-deploy.sh
./build-deploy.sh

# Windows (Doppelklick auf:)
build-deploy.bat
```

### Schritt 2: Deployment wählen

Das Script fragt:

```
Wähle Deployment-Option:
  1) 🔥 Firebase Hosting (empfohlen)
  2) 🐙 GitHub Pages
  3) 🌐 Netlify
  4) 🖥️  Lokaler Test-Server
```

**Empfehlung für Sie: Option 1 (Firebase) - kostenlos & einfach!**

### Schritt 3: URL in App eintragen

Nach dem Deployment öffne `lib/services/update_service.dart`:

```dart
// Zeile 31
static const String baseUrl = kIsWeb 
    ? '' 
    : 'https://DEINE-FIREBASE-URL.web.app'; // ← URL hier eintragen
```

---

## 💡 DEPLOYMENT-OPTIONEN

### 🔥 Firebase (Empfohlen!)

**Warum Firebase?**
- ✅ Komplett kostenlos
- ✅ HTTPS automatisch
- ✅ CDN weltweit
- ✅ Sehr schnell

**Erstmaliges Setup:**
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
```

**Dann immer:**
```bash
./build-deploy.sh  # → Option 1
```

**Deine URL:** `https://erfasser-app-xxxxx.web.app`

---

### 🐙 GitHub Pages (Auch gratis!)

**Setup:**
1. GitHub Repo erstellen
2. `./build-deploy.sh` → Option 2
3. Repo-URL eingeben
4. In GitHub: Settings → Pages → Source: gh-pages

**Deine URL:** `https://username.github.io/erfasser-app`

---

### 🖥️ Lokales Netzwerk (Firmen-intern)

**Für internen Gebrauch ohne Internet:**

```bash
./build-deploy.sh  # → Option 4

# Server läuft auf:
http://192.168.1.100:8000  # ← Deine lokale IP
```

**In App konfigurieren:**
```dart
static const String baseUrl = 'http://192.168.1.100:8000';
```

---

## 📱 SO FUNKTIONIERT ES

### Desktop/Mobile Apps:

```
1. App startet
   ↓
2. Lädt version.json von Web-App
   ↓
3. Vergleicht mit aktueller Version
   ↓
4. Bei neuer Version → Dialog zeigen
   ↓
5. User klickt "Update"
   ↓
6. Browser öffnet Download-Seite
   ↓
7. User lädt & installiert
   ↓
8. App neu starten → Fertig!
```

### Web-App:

```
1. User öffnet Web-App
   ↓
2. Service Worker prüft automatisch
   ↓
3. Neue Version? → Reload-Prompt
   ↓
4. Seite neu laden → Fertig!
```

---

## 🔄 UPDATE VERTEILEN (später)

### 1. Version erhöhen

```yaml
# pubspec.yaml
version: 1.2.0+3  # ← +1
```

### 2. Neu bauen & deployen

```bash
./build-deploy.sh
```

### 3. Fertig! 🎉

Alle Apps bekommen beim nächsten Start eine Benachrichtigung!

---

## 📂 DATEISTRUKTUR

```
erfasser_app/
├── build-deploy.sh            # ← HAUPTSCRIPT (Linux/macOS)
├── build-deploy.bat           # ← HAUPTSCRIPT (Windows)
├── lib/
│   ├── services/
│   │   └── update_service.dart   # Update-Logik
│   ├── widgets/
│   │   └── update_dialog.dart    # Update-Dialog
│   └── main.dart                  # UpdateChecker integriert
├── docs/
│   ├── SELF_HOSTED_UPDATES.md    # Ausführliche Anleitung
│   └── PRIVATE_DEPLOYMENT.md     # Alternative Methoden
└── UPDATE_QUICKSTART.md          # Diese Datei
```

---

## ⚙️ KONFIGURATION

### Base-URL (wichtigste Einstellung!)

```dart
// lib/services/update_service.dart, Zeile 31

// Firebase:
static const String baseUrl = 'https://erfasser-app-xxxxx.web.app';

// GitHub Pages:
static const String baseUrl = 'https://username.github.io/erfasser-app';

// Lokal:
static const String baseUrl = 'http://192.168.1.100:8000';
```

### Update-Check Intervall

```dart
// lib/main.dart, Zeile 24
UpdateChecker(
  checkInterval: Duration(hours: 24),  // Wie oft prüfen?
  checkOnStart: true,                  // Beim Start prüfen?
)
```

---

## 🐛 HÄUFIGE PROBLEME

### "Update-Check funktioniert nicht"

**Ursache:** baseUrl falsch  
**Lösung:** In `update_service.dart` Zeile 31 URL prüfen

**Test:**
```dart
// In update_service.dart ergänzen:
if (kDebugMode) print('Check URL: $updateCheckUrl');
```

### "Download startet nicht"

**Ursache:** Builds nicht kopiert  
**Lösung:** Script nochmal ausführen:
```bash
./build-deploy.sh
```

### "CORS-Fehler"

**Ursache:** Nur bei lokalem Server  
**Lösung:** Firebase/GitHub Pages nutzen (haben CORS)

---

## 📚 MEHR INFOS

- 📄 **[docs/SELF_HOSTED_UPDATES.md](docs/SELF_HOSTED_UPDATES.md)** - Ausführliche Anleitung
- 📄 **[docs/PRIVATE_DEPLOYMENT.md](docs/PRIVATE_DEPLOYMENT.md)** - Alternative Methoden
- 📄 **[docs/UPDATE_GUIDE.md](docs/UPDATE_GUIDE.md)** - Technische Details

---

## ✨ ZUSAMMENFASSUNG

✅ **KEIN externer Server nötig**  
✅ **KOSTENLOS** mit Firebase/GitHub  
✅ **EIN SCRIPT** für alles  
✅ **AUTOMATISCHE Updates** in allen Apps  
✅ **5 MINUTEN** Setup  

---

## 🎯 NÄCHSTER SCHRITT

```bash
# Starte jetzt:
./build-deploy.sh

# Wähle Firebase (Option 1)
# Kopiere die URL
# Trage URL in update_service.dart ein
# Fertig! 🎉
```

**Happy Self-Hosting! 🚀**

---

*Fragen? Siehe Dokumentation in `docs/` Ordner.*

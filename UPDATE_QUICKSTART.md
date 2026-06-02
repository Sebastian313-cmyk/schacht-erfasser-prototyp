# 🔄 Self-Hosted Updates - Direkt vom eigenen PC!

## ✅ Was ist das?

**Updates über die Web-App selbst - KEIN Server nötig!**

Die Web-Version hostet alle Downloads:
- ✅ **Kostenlos** mit Firebase/GitHub Pages/Netlify
- ✅ **Einfach** - Web-App ist gleichzeitig Update-Server
- ✅ **Schnell** - 5 Minuten Setup
- ✅ **Flexibel** - Auch lokal im Netzwerk nutzbar

```
Ihre Web-App
├── index.html         # Die App selbst
├── version.json       # Update-Info
└── downloads/         # Alle Plattform-Builds
    ├── erfasser-app.apk
    ├── erfasser-app-setup.exe
    ├── erfasser-app.AppImage
    └── erfasser-app.dmg
```

---

## 🚀 Quick Start (3 Schritte!)

### 1. Build erstellen & Deployen

```bash
# Linux/macOS
chmod +x build-deploy.sh
./build-deploy.sh

# Windows
build-deploy.bat
```

Wähle Deployment-Option:
- **Firebase Hosting** (empfohlen - gratis!)
- **GitHub Pages** (gratis!)
- **Netlify** (gratis!)
- **Lokaler Server** (zum Testen)

### 2. URL in App konfigurieren

```dart
// lib/services/update_service.dart, Zeile 31
static const String baseUrl = kIsWeb 
    ? '' 
    : 'https://erfasser-app-xxxxx.web.app'; // ← Deine URL
```

### 3. Fertig! 🎉

Desktop/Mobile Apps laden Updates jetzt automatisch von der Web-App!

---

## 📚 Deployment-Optionen

### Option 1: Firebase Hosting (Empfohlen!)

**Vorteile:**
- ✅ Komplett gratis
- ✅ HTTPS automatisch
- ✅ CDN weltweit
- ✅ Einfaches Deployment

**Setup:**
```bash
# 1. Firebase CLI installieren
npm install -g firebase-tools

# 2. Login & Init
firebase login
firebase init hosting

# 3. Deploy mit Script
./build-deploy.sh
# → Option 1 wählen
```

**URL:** `https://erfasser-app-xxxxx.web.app`

---

### Option 2: GitHub Pages

**Vorteile:**
- ✅ Gratis
- ✅ Direkt aus GitHub Repo
- ✅ Automatische Updates via git push

**Setup:**
```bash
# 1. GitHub Repo erstellen

# 2. Deploy mit Script
./build-deploy.sh
# → Option 2 wählen
# → Repo-URL eingeben

# 3. In GitHub: Settings → Pages → Source: gh-pages
```

**URL:** `https://username.github.io/erfasser-app`

---

### Option 3: Lokales Netzwerk

**Für interne Nutzung (z.B. Firmennetzwerk):**

```bash
# 1. Builds erstellen
./build-deploy.sh
# → Option 4 wählen (Lokaler Server)

# 2. Server läuft auf:
http://localhost:8000           # Lokal
http://192.168.1.100:8000      # Im Netzwerk

# 3. In App konfigurieren:
static const String baseUrl = 'http://192.168.1.100:8000';
```

**Dauerhaft laufen lassen (Linux):**
```bash
# Als systemd Service
sudo nano /etc/systemd/system/erfasser-app.service

# Inhalt:
[Unit]
Description=Erfasser App Server
After=network.target

[Service]
Type=simple
User=yourusername
WorkingDirectory=/home/yourusername/erfasser_app/build/web
ExecStart=/usr/bin/python3 -m http.server 8000
Restart=always

[Install]
WantedBy=multi-user.target

# Aktivieren:
sudo systemctl enable erfasser-app
sudo systemctl start erfasser-app
```

---

## 🔄 Updates verteilen

### Schritt 1: Version erhöhen

```yaml
# pubspec.yaml
version: 1.2.0+3  # ← Hochzählen
```

### Schritt 2: Neu bauen & deployen

```bash
./build-deploy.sh
```

### Schritt 3: Fertig!

Beim nächsten App-Start sehen alle User das Update! 🎉

---

## 📱 Wie es funktioniert

### Für Desktop/Mobile Apps:

1. **App startet** → Check `https://your-url.com/version.json`
2. **Neue Version?** → Dialog erscheint
3. **User klickt Update** → Browser öffnet Download
4. **Installation** → Manuell
5. **Neustart** → Neue Version!

### Für Web-App:

1. **User öffnet App** → Service Worker prüft
2. **Neue Version?** → Reload-Prompt
3. **Bestätigen** → Seite neu laden
4. **Fertig!** → Sofort aktuell

---

## 🎨 Download-Seite in App einbauen

**lib/screens/downloads_screen.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Downloads')),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          _DownloadCard(
            icon: '🤖',
            platform: 'Android',
            url: '/downloads/erfasser-app.apk',
          ),
          _DownloadCard(
            icon: '🪟',
            platform: 'Windows',
            url: '/downloads/erfasser-app-setup.exe',
          ),
          // ... weitere Plattformen
        ],
      ),
    );
  }
}
```

---

## 🔧 Konfiguration

### Base-URL ändern

```dart
// lib/services/update_service.dart

// Firebase:
static const String baseUrl = 'https://erfasser-app-xxxxx.web.app';

// GitHub Pages:
static const String baseUrl = 'https://username.github.io/erfasser-app';

// Lokal:
static const String baseUrl = 'http://192.168.1.100:8000';

// Web (immer):
static const String baseUrl = kIsWeb ? '' : 'https://...';
```

### Update-Intervall

```dart
// lib/main.dart
UpdateChecker(
  checkInterval: Duration(hours: 6),  // Alle 6 Stunden
  checkOnStart: true,                 // Beim Start
  // ...
)
```

### Force-Update

```json
// build/web/version.json
{
  "version": "2.0.0",
  "forceUpdate": true  // User MUSS updaten!
}
```

---

## 💡 Vorteile

✅ **Kostenlos** - Firebase/GitHub/Netlify gratis  
✅ **Keine Server** - Web-App hostet selbst  
✅ **Einfach** - Ein Script für alles  
✅ **Schnell** - CDN-Verteilung  
✅ **Flexibel** - Cloud oder lokal  
✅ **Sicher** - HTTPS automatisch  

---

## 🐛 Troubleshooting

### "Update-Check schlägt fehl"

1. **baseUrl korrekt?**
   ```dart
   // Prüfen in update_service.dart
   print('Update-URL: $updateCheckUrl');
   ```

2. **version.json erreichbar?**
   ```bash
   curl https://your-url.com/version.json
   # Sollte JSON zurückgeben
   ```

3. **CORS-Problem?** (nur bei lokalem Server)
   ```bash
   # Python mit CORS
   python -m http.server 8000 --bind 0.0.0.0
   ```

### "Downloads funktionieren nicht"

1. **Builds wirklich kopiert?**
   ```bash
   ls -lh build/web/downloads/
   ```

2. **Im Browser testen:**
   ```
   https://your-url.com/downloads/erfasser-app.apk
   ```

---

## 📖 Ausführliche Doku

Siehe **[docs/SELF_HOSTED_UPDATES.md](docs/SELF_HOSTED_UPDATES.md)** für:
- Detaillierte Setup-Anleitungen
- Deployment-Optionen
- Troubleshooting
- Best Practices

---

## ✨ Los geht's!

```bash
# Alles auf einmal:
./build-deploy.sh

# Oder Schritt für Schritt:
flutter build apk --release
flutter build web --release
cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/
firebase deploy
```

**Happy Self-Hosting! 🎉**

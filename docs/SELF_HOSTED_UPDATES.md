# 🚀 Self-Hosted Updates - Einfach vom eigenen PC!

## ✅ Das Konzept

**Keine Server-Infrastruktur nötig!** Die Web-App hostet Updates selbst:

```
Ihre Web-App (z.B. auf Firebase/Netlify/GitHub Pages)
├── index.html              # Die App
├── version.json            # Update-Info
└── downloads/              # Alle Builds
    ├── erfasser-app.apk           # Android
    ├── erfasser-app-setup.exe     # Windows
    ├── erfasser-app.AppImage      # Linux
    └── erfasser-app.dmg           # macOS
```

**Desktop/Mobile-Apps laden Updates direkt von der Web-Version!**

---

## 🎯 3 Deployment-Optionen

### Option 1: **Firebase Hosting** (Empfohlen - GRATIS!)

```bash
# 1. Firebase CLI installieren
npm install -g firebase-tools

# 2. Login
firebase login

# 3. Projekt initialisieren
cd erfasser_app
firebase init hosting

# Folgende Einstellungen wählen:
# - Public directory: build/web
# - Single-page app: Yes
# - Overwrites: No

# 4. Build erstellen
flutter build web --release

# 5. Builds in downloads/ kopieren
mkdir -p build/web/downloads
cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/erfasser-app.apk
# ... weitere Builds

# 6. version.json kopieren
cp version.json build/web/

# 7. Deployen!
firebase deploy --only hosting

# ✅ Fertig! URL: https://erfasser-app-xxxxx.web.app
```

**Konfiguration in App:**
```dart
// lib/services/update_service.dart, Zeile 31
static const String baseUrl = kIsWeb 
    ? '' // Relative URLs
    : 'https://erfasser-app-xxxxx.web.app'; // ← Ihre Firebase URL
```

---

### Option 2: **GitHub Pages** (GRATIS!)

```bash
# 1. GitHub Repo erstellen (z.B. "erfasser-app")

# 2. Build erstellen
flutter build web --release --base-href "/erfasser-app/"

# 3. Builds kopieren
mkdir -p build/web/downloads
cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/erfasser-app.apk
cp version.json build/web/

# 4. Zu GitHub pushen
cd build/web
git init
git add .
git commit -m "Deploy"
git branch -M gh-pages
git remote add origin https://github.com/USERNAME/erfasser-app.git
git push -u origin gh-pages

# 5. In Repo Settings → Pages → Source: gh-pages

# ✅ URL: https://USERNAME.github.io/erfasser-app
```

**Konfiguration:**
```dart
static const String baseUrl = kIsWeb 
    ? '' 
    : 'https://USERNAME.github.io/erfasser-app';
```

---

### Option 3: **Lokaler Dev-Server** (Zum Testen)

```bash
# 1. Build erstellen
flutter build web --release

# 2. Builds in downloads/ kopieren
mkdir -p build/web/downloads
cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/erfasser-app.apk
cp build/windows/x64/runner/Release/* build/web/downloads/ # Windows
cp version.json build/web/

# 3. Lokalen Server starten
cd build/web
python -m http.server 8000

# ODER mit Node.js:
npx serve -p 8000

# ✅ Läuft auf: http://localhost:8000
```

**Im lokalen Netzwerk verfügbar machen:**
```bash
# Deine lokale IP finden (Windows):
ipconfig
# Oder (Linux/macOS):
ifconfig

# Server mit spezifischer IP starten:
python -m http.server 8000 --bind 192.168.1.100

# ✅ Andere Geräte können zugreifen: http://192.168.1.100:8000
```

**Konfiguration für lokales Netzwerk:**
```dart
static const String baseUrl = kIsWeb 
    ? '' 
    : 'http://192.168.1.100:8000'; // ← Deine lokale IP
```

---

## 📦 Automatisches Build & Deploy Script

**build-and-deploy.sh:**
```bash
#!/bin/bash

echo "🚀 Erfasser App - Build & Deploy"
echo "================================="

# Version erhöhen
VERSION="1.2.0"
BUILD="3"

# 1. Alle Builds erstellen
echo "📱 Build Android..."
flutter build apk --release

echo "🪟 Build Windows..."
flutter build windows --release

echo "🌐 Build Web..."
flutter build web --release

# 2. Downloads-Ordner erstellen
echo "📁 Erstelle downloads/..."
mkdir -p build/web/downloads

# 3. Builds kopieren
echo "📋 Kopiere Builds..."
cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/erfasser-app.apk

# Windows (Installer muss vorher mit Inno Setup erstellt werden)
if [ -f "output/erfasser-app-setup.exe" ]; then
    cp output/erfasser-app-setup.exe build/web/downloads/
fi

# 4. version.json aktualisieren
cat > build/web/version.json << EOF
{
  "version": "$VERSION",
  "buildNumber": $BUILD,
  "releaseDate": "$(date +%Y-%m-%d)",
  "releaseNotes": "✨ Version $VERSION\n\n🐛 Bugfixes und Verbesserungen",
  "forceUpdate": false
}
EOF

echo "📄 version.json erstellt"

# 5. Deploy-Option wählen
echo ""
echo "Wähle Deployment:"
echo "1) Firebase Hosting"
echo "2) GitHub Pages"
echo "3) Nur lokal testen"
read -p "Option (1-3): " option

case $option in
    1)
        echo "🚀 Deploy zu Firebase..."
        firebase deploy --only hosting
        echo "✅ Deployed! Check: firebase hosting:sites:list"
        ;;
    2)
        echo "🚀 Deploy zu GitHub Pages..."
        cd build/web
        git init
        git add .
        git commit -m "Deploy v$VERSION"
        git branch -M gh-pages
        git push -f origin gh-pages
        echo "✅ Deployed! Check GitHub Pages Settings"
        ;;
    3)
        echo "🖥️  Starte lokalen Server..."
        cd build/web
        python3 -m http.server 8000
        ;;
    *)
        echo "❌ Ungültige Option"
        ;;
esac

echo "✨ Fertig!"
```

**Ausführbar machen:**
```bash
chmod +x build-and-deploy.sh
./build-and-deploy.sh
```

---

## 🎨 Download-Seite in Web-App integrieren

**lib/screens/downloads_screen.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📥 Downloads')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Erfasser App',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Version 1.1.0',
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          
          _buildDownloadCard(
            context,
            icon: Icons.android,
            title: 'Android',
            subtitle: 'APK Download (~25 MB)',
            url: '/downloads/erfasser-app.apk',
            color: Colors.green,
          ),
          
          _buildDownloadCard(
            context,
            icon: Icons.window,
            title: 'Windows',
            subtitle: 'Installer (~45 MB)',
            url: '/downloads/erfasser-app-setup.exe',
            color: Colors.blue,
          ),
          
          _buildDownloadCard(
            context,
            icon: Icons.computer,
            title: 'Linux',
            subtitle: 'AppImage (~40 MB)',
            url: '/downloads/erfasser-app.AppImage',
            color: Colors.orange,
          ),
          
          _buildDownloadCard(
            context,
            icon: Icons.apple,
            title: 'macOS',
            subtitle: 'DMG (~50 MB)',
            url: '/downloads/erfasser-app.dmg',
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        leading: Icon(icon, size: 40, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Download'),
          onPressed: () => _download(url),
        ),
      ),
    );
  }

  Future<void> _download(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
```

**In routes.dart hinzufügen:**
```dart
'/downloads': (context) => const DownloadsScreen(),
```

---

## 🔄 Update-Flow

### Für Desktop/Mobile Apps:

1. **App startet** → Automatischer Update-Check nach 2 Sekunden
2. **Neue Version gefunden** → Dialog erscheint
3. **User klickt "Update"** → Browser öffnet Download-Seite
4. **User lädt Datei** → Installiert manuell
5. **App neu starten** → Neue Version läuft!

### Für Web-App:

1. **User öffnet Web-App** → Service Worker prüft auf Updates
2. **Neue Version** → Prompt erscheint
3. **User bestätigt** → Seite lädt neu
4. **Fertig!** → Neue Version läuft sofort

---

## 📝 Version aktualisieren (Schritt für Schritt)

### 1. Version in pubspec.yaml erhöhen

```yaml
version: 1.2.0+3  # ← Erhöhen!
```

### 2. Builds erstellen

```bash
flutter build apk --release
flutter build windows --release
flutter build web --release
```

### 3. Builds in Web-Ordner kopieren

```bash
mkdir -p build/web/downloads
cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/erfasser-app.apk
# ... weitere
```

### 4. version.json aktualisieren

```json
{
  "version": "1.2.0",
  "buildNumber": 3,
  "releaseNotes": "Was ist neu..."
}
```

### 5. Deployen

```bash
firebase deploy --only hosting
# ODER
git push origin gh-pages
```

### 6. Fertig! 🎉

Alle Apps bekommen jetzt beim nächsten Start eine Update-Benachrichtigung!

---

## 💡 Vorteile dieser Lösung

✅ **Kostenlos** - Firebase/GitHub Pages sind gratis  
✅ **Einfach** - Kein Server-Setup nötig  
✅ **Schnell** - CDN-Verteilung weltweit  
✅ **Flexibel** - Auch lokal im Netzwerk nutzbar  
✅ **Sicher** - HTTPS automatisch (Firebase/GitHub)  
✅ **Wartungsarm** - Keine Server zu pflegen  

---

## 🐛 Troubleshooting

### "Update-Check schlägt fehl"

**Problem:** Desktop-App findet keine Updates  
**Lösung:** baseUrl in update_service.dart korrekt setzen

```dart
// Für Firebase:
static const String baseUrl = 'https://erfasser-app-xxxxx.web.app';

// Für GitHub Pages:
static const String baseUrl = 'https://USERNAME.github.io/erfasser-app';

// Für lokales Netzwerk:
static const String baseUrl = 'http://192.168.1.100:8000';
```

### "CORS-Fehler im Browser"

**Problem:** Web-App kann version.json nicht laden  
**Lösung:** Bei Firebase/GitHub automatisch gelöst. Bei lokalem Server:

```bash
# Python mit CORS:
python -m http.server 8000 --bind 0.0.0.0
```

### "Download startet nicht"

**Problem:** URL nicht erreichbar  
**Lösung:** 
1. Builds wirklich in `build/web/downloads/` kopiert?
2. Dateien mit deployed? (Check im Browser: `https://your-url.com/downloads/erfasser-app.apk`)

---

## ✨ Das war's!

Keine Server, keine Kosten, volle Kontrolle! 🎉

**Quick-Befehle:**
```bash
# Alles bauen
flutter build apk --release && flutter build web --release

# Builds kopieren
cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/

# Deployen
firebase deploy
```

Happy Deploying! 🚀

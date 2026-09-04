# 🌐 Private Web-Deployment - Kein App Store nötig!

## ✅ Was ist das?

Ein **komplett privates Update-System** für Ihre Erfasser-App:
- ✅ Alle Updates über **Ihren eigenen Webserver**
- ✅ **Keine App Store Registrierung** nötig
- ✅ **Volle Kontrolle** über Updates
- ✅ **Sofortige Deployments** ohne Store-Review
- ✅ **Intern/Privat** ohne öffentliche Veröffentlichung

---

## 🚀 Schnellstart (5 Minuten)

### 1. Server-Ordnerstruktur erstellen

Auf Ihrem Webserver (Apache, Nginx, Firebase Hosting, etc.):

```
/var/www/erfasser-app/
├── version.json          # Update-Info
└── downloads/
    ├── erfasser-app.apk           # Android
    ├── erfasser-app.ipa           # iOS (optional)
    ├── erfasser-app-setup.exe     # Windows
    ├── erfasser-app.msix          # Windows Store
    ├── erfasser-app.AppImage      # Linux
    ├── erfasser-app.deb           # Linux Debian/Ubuntu
    ├── erfasser-app.dmg           # macOS
    └── web/                       # Web-Version
        ├── index.html
        ├── main.dart.js
        └── ...
```

### 2. URL im Code konfigurieren

```dart
// lib/services/update_service.dart, Zeile 20
static const String updateCheckUrl = 'https://IHR-SERVER.com/erfasser-app/version.json';
```

### 3. Builds erstellen

```bash
# Android APK (für direkte Installation)
flutter build apk --release

# Windows Installer
flutter build windows --release

# Linux AppImage
flutter build linux --release

# macOS DMG
flutter build macos --release

# Web
flutter build web --release
```

### 4. Dateien hochladen

```bash
# Beispiel mit SCP
scp build/app/outputs/flutter-apk/app-release.apk user@server:/var/www/erfasser-app/downloads/erfasser-app.apk
scp version.json user@server:/var/www/erfasser-app/version.json
scp -r build/web/* user@server:/var/www/erfasser-app/downloads/web/
```

### 5. Server-Zugriff testen

```bash
curl https://IHR-SERVER.com/erfasser-app/version.json
# Sollte JSON zurückgeben mit version, downloadUrl etc.
```

---

## 📱 Plattform-spezifische Anleitung

### 🤖 **Android (APK)**

**Vorteile:**
- ✅ Keine Google Play Store Registrierung
- ✅ Direkte Installation per APK
- ✅ Sofortige Updates

**Nachteile:**
- ⚠️ User muss "Unbekannte Quellen" aktivieren (einmalig)

**Build:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**User-Anleitung:**
1. APK von Webserver herunterladen
2. "Installation aus unbekannten Quellen" aktivieren
3. APK öffnen → Installieren

**Alternative: Signierte APK für Firmen:**
```bash
# keystore.jks erstellen (einmalig)
keytool -genkey -v -keystore erfasser-app.keystore -alias erfasser -keyalg RSA -keysize 2048 -validity 10000

# In android/key.properties:
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=erfasser
storeFile=../erfasser-app.keystore

# Build
flutter build apk --release
```

---

### 🍎 **iOS (IPA/TestFlight)**

**Option A: TestFlight (empfohlen für iOS)**
- ✅ Apple-zertifiziert
- ✅ Einfache Installation
- ⚠️ Benötigt Apple Developer Account ($99/Jahr)

```bash
# Build für TestFlight
flutter build ios --release
# Upload über Xcode → Organizer → App Store Connect
```

**Option B: Enterprise IPA (für Firmen)**
- ✅ Privat ohne App Store
- ⚠️ Benötigt Enterprise Developer Program ($299/Jahr)

**Option C: Ad-Hoc Distribution**
- Für max. 100 Geräte
- UDIDs müssen registriert werden

---

### 🪟 **Windows (EXE/MSIX)**

**Option A: Selbstextrahierendes EXE (einfach)**

```bash
# Build
flutter build windows --release

# Mit Inno Setup ein Installer erstellen:
# Download: https://jrsoftware.org/isdl.php
```

**Inno Setup Script (erfasser-app.iss):**
```ini
[Setup]
AppName=Erfasser App
AppVersion=1.1.0
DefaultDirName={pf}\ErfasserApp
OutputDir=output
OutputBaseFilename=erfasser-app-setup

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{commondesktop}\Erfasser App"; Filename: "{app}\erfasser_app.exe"
```

```bash
# Installer kompilieren
iscc erfasser-app.iss
# Output: output/erfasser-app-setup.exe
```

**Option B: MSIX (für Microsoft Store ODER Sideloading)**

```bash
flutter build windows --release
# MSIX Package erstellen (benötigt Windows SDK)
```

---

### 🐧 **Linux**

**Option A: AppImage (empfohlen - portabel)**

```bash
# Build
flutter build linux --release

# AppImage mit linuxdeploy erstellen
wget https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage

./linuxdeploy-x86_64.AppImage \
  --executable=build/linux/x64/release/bundle/erfasser_app \
  --appdir=AppDir \
  --output appimage
```

**Option B: DEB Package (Debian/Ubuntu)**

```bash
# debian/control erstellen
mkdir -p debian/DEBIAN
cat > debian/DEBIAN/control << EOF
Package: erfasser-app
Version: 1.1.0
Architecture: amd64
Maintainer: Ihr Name <email@example.com>
Description: Erfasser App
EOF

# App kopieren
mkdir -p debian/opt/erfasser-app
cp -r build/linux/x64/release/bundle/* debian/opt/erfasser-app/

# DEB bauen
dpkg-deb --build debian erfasser-app.deb
```

---

### 🍏 **macOS (DMG)**

```bash
# Build
flutter build macos --release

# DMG mit create-dmg erstellen
npm install -g create-dmg
create-dmg build/macos/Build/Products/Release/erfasser_app.app
```

---

## 🌐 Web-Deployment (wichtigste Plattform!)

### Option A: Eigener Server (Apache/Nginx)

```bash
# Build
flutter build web --release

# Upload
scp -r build/web/* user@server:/var/www/erfasser-app/downloads/web/
```

**Nginx-Konfiguration:**
```nginx
server {
    listen 80;
    server_name your-server.com;
    
    location /erfasser-app {
        root /var/www;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        # CORS für version.json
        add_header Access-Control-Allow-Origin *;
    }
}
```

### Option B: Firebase Hosting (gratis!)

```bash
# Firebase CLI installieren
npm install -g firebase-tools

# Login
firebase login

# Init
firebase init hosting

# Deploy
firebase deploy --only hosting
```

### Option C: Netlify/Vercel (gratis!)

```bash
# Netlify CLI
npm install -g netlify-cli
netlify deploy --dir=build/web --prod
```

---

## 🔧 Automatisches Deployment mit Script

**deploy.sh:**
```bash
#!/bin/bash

VERSION="1.1.0"
SERVER="user@your-server.com"
SERVER_PATH="/var/www/erfasser-app"

echo "🚀 Building all platforms..."

# Android
flutter build apk --release
scp build/app/outputs/flutter-apk/app-release.apk $SERVER:$SERVER_PATH/downloads/erfasser-app.apk

# Windows
flutter build windows --release
# (Inno Setup manuell ausführen)
scp output/erfasser-app-setup.exe $SERVER:$SERVER_PATH/downloads/

# Linux
flutter build linux --release
# (AppImage manuell erstellen)
scp erfasser-app.AppImage $SERVER:$SERVER_PATH/downloads/

# Web
flutter build web --release
scp -r build/web/* $SERVER:$SERVER_PATH/downloads/web/

# version.json aktualisieren
sed -i "s/\"version\": \".*\"/\"version\": \"$VERSION\"/" version.json
scp version.json $SERVER:$SERVER_PATH/

echo "✅ Deployment abgeschlossen!"
```

---

## 🔒 Sicherheit (optional aber empfohlen)

### 1. HTTPS aktivieren

```bash
# Let's Encrypt (gratis)
sudo certbot --nginx -d your-server.com
```

### 2. Passwortschutz (für privaten Zugriff)

**Nginx .htpasswd:**
```bash
# Passwort-Datei erstellen
sudo htpasswd -c /etc/nginx/.htpasswd admin

# In nginx.conf:
location /erfasser-app/downloads {
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

### 3. Download-Token (fortgeschritten)

```dart
// In update_service.dart:
final token = 'YOUR_SECRET_TOKEN';
final url = '$downloadUrl?token=$token';
```

---

## 📊 Download-Statistiken tracken

**simple-stats.php:**
```php
<?php
$file = $_GET['file'] ?? '';
$ip = $_SERVER['REMOTE_ADDR'];
$date = date('Y-m-d H:i:s');

// Log schreiben
file_put_contents('downloads.log', "$date | $ip | $file\n", FILE_APPEND);

// Datei ausliefern
header('Content-Type: application/octet-stream');
readfile("downloads/$file");
?>
```

**URL dann:**
```dart
const androidApkUrl = 'https://your-server.com/download.php?file=erfasser-app.apk';
```

---

## ✅ Checkliste vor Deployment

- [ ] Server-URLs in `update_service.dart` eingetragen
- [ ] `version.json` auf Server hochgeladen
- [ ] Alle Plattform-Builds erstellt
- [ ] Download-Links getestet
- [ ] HTTPS aktiviert (empfohlen)
- [ ] CORS-Header gesetzt (für Web)
- [ ] Update-Dialog in App getestet

---

## 💡 Vorteile dieser Lösung

✅ **Keine Store-Gebühren** ($99-$299/Jahr gespart)  
✅ **Sofortige Updates** (keine Store-Review)  
✅ **Volle Kontrolle** über Verteilung  
✅ **Privat/Intern** nutzbar  
✅ **Einfaches Rollback** möglich  
✅ **Multi-Platform** aus einer Hand  

---

**Happy Private Deployment! 🎉**

#!/bin/bash

# ============================================================
# DEPLOYMENT SCRIPT - Erfasser App
# Baut alle Plattformen und deployt auf Webserver
# ============================================================

set -e  # Bei Fehler abbrechen

# ========== KONFIGURATION ==========
VERSION="1.1.0"
BUILD_NUMBER="2"
SERVER_USER="user"
SERVER_HOST="your-server.com"
SERVER_PATH="/var/www/erfasser-app"
LOCAL_DOWNLOADS="./releases"

echo "🚀 Erfasser App Deployment v$VERSION+$BUILD_NUMBER"
echo "================================================"

# ========== VORBEREITUNG ==========
echo ""
echo "📁 Erstelle Release-Ordner..."
mkdir -p "$LOCAL_DOWNLOADS"
rm -rf "$LOCAL_DOWNLOADS"/*

# ========== VERSION AKTUALISIEREN ==========
echo ""
echo "📝 Aktualisiere Version in pubspec.yaml..."
sed -i "s/version: .*/version: $VERSION+$BUILD_NUMBER/" pubspec.yaml

# ========== ANDROID BUILD ==========
echo ""
echo "🤖 Build Android APK..."
flutter clean
flutter pub get
flutter build apk --release

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-release.apk "$LOCAL_DOWNLOADS/erfasser-app.apk"
    echo "✅ Android APK erstellt ($(du -h "$LOCAL_DOWNLOADS/erfasser-app.apk" | cut -f1))"
else
    echo "❌ Android Build fehlgeschlagen!"
    exit 1
fi

# ========== WINDOWS BUILD ==========
echo ""
echo "🪟 Build Windows..."
flutter build windows --release

if [ -d "build/windows/x64/runner/Release" ]; then
    echo "✅ Windows Build erstellt"
    echo "ℹ️  Bitte Inno Setup manuell ausführen um Installer zu erstellen!"
    # Optional: Automatisch mit Inno Setup CLI
    # iscc erfasser-app.iss
else
    echo "⚠️  Windows Build fehlgeschlagen (nur auf Windows möglich)"
fi

# ========== LINUX BUILD ==========
echo ""
echo "🐧 Build Linux..."
flutter build linux --release

if [ -d "build/linux/x64/release/bundle" ]; then
    echo "✅ Linux Build erstellt"
    echo "ℹ️  Bitte AppImage manuell erstellen (siehe docs/PRIVATE_DEPLOYMENT.md)"
    
    # Optional: DEB Package erstellen
    # ./create-deb.sh
else
    echo "⚠️  Linux Build fehlgeschlagen"
fi

# ========== MACOS BUILD ==========
echo ""
echo "🍏 Build macOS..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    flutter build macos --release
    
    if [ -d "build/macos/Build/Products/Release/erfasser_app.app" ]; then
        echo "✅ macOS Build erstellt"
        echo "ℹ️  Bitte DMG manuell erstellen (siehe docs/PRIVATE_DEPLOYMENT.md)"
    else
        echo "❌ macOS Build fehlgeschlagen"
    fi
else
    echo "⚠️  macOS Build übersprungen (nur auf macOS möglich)"
fi

# ========== WEB BUILD ==========
echo ""
echo "🌐 Build Web..."
flutter build web --release

if [ -d "build/web" ]; then
    mkdir -p "$LOCAL_DOWNLOADS/web"
    cp -r build/web/* "$LOCAL_DOWNLOADS/web/"
    echo "✅ Web Build erstellt"
else
    echo "❌ Web Build fehlgeschlagen!"
    exit 1
fi

# ========== VERSION.JSON AKTUALISIEREN ==========
echo ""
echo "📄 Erstelle version.json..."
cat > "$LOCAL_DOWNLOADS/version.json" << EOF
{
  "version": "$VERSION",
  "buildNumber": $BUILD_NUMBER,
  "releaseDate": "$(date +%Y-%m-%d)",
  "releaseNotes": "Version $VERSION\n\n✨ Neue Features und Verbesserungen\n🐛 Bugfixes",
  "forceUpdate": false,
  "platforms": {
    "android": {
      "downloadUrl": "https://$SERVER_HOST/erfasser-app/downloads/erfasser-app.apk",
      "minVersion": "1.0.0"
    },
    "windows": {
      "downloadUrl": "https://$SERVER_HOST/erfasser-app/downloads/erfasser-app-setup.exe",
      "minVersion": "1.0.0"
    },
    "linux": {
      "downloadUrl": "https://$SERVER_HOST/erfasser-app/downloads/erfasser-app.AppImage",
      "minVersion": "1.0.0"
    },
    "macos": {
      "downloadUrl": "https://$SERVER_HOST/erfasser-app/downloads/erfasser-app.dmg",
      "minVersion": "1.0.0"
    },
    "web": {
      "cacheBustingEnabled": true
    }
  }
}
EOF

echo "✅ version.json erstellt"

# ========== DATEIGRÖSSEN ANZEIGEN ==========
echo ""
echo "📊 Release-Dateien:"
echo "==================="
ls -lh "$LOCAL_DOWNLOADS" | tail -n +2

# ========== UPLOAD BESTÄTIGUNG ==========
echo ""
echo "🚀 Bereit zum Upload auf Server!"
read -p "Möchten Sie jetzt auf $SERVER_HOST hochladen? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📤 Upload auf Server..."
    
    # APK
    if [ -f "$LOCAL_DOWNLOADS/erfasser-app.apk" ]; then
        scp "$LOCAL_DOWNLOADS/erfasser-app.apk" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/downloads/"
        echo "✅ APK hochgeladen"
    fi
    
    # Web
    if [ -d "$LOCAL_DOWNLOADS/web" ]; then
        scp -r "$LOCAL_DOWNLOADS/web/"* "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/downloads/web/"
        echo "✅ Web hochgeladen"
    fi
    
    # version.json
    scp "$LOCAL_DOWNLOADS/version.json" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/"
    echo "✅ version.json hochgeladen"
    
    echo ""
    echo "🎉 Deployment abgeschlossen!"
    echo "📱 App-URL: https://$SERVER_HOST/erfasser-app/downloads/web/"
    echo "📄 Version-Info: https://$SERVER_HOST/erfasser-app/version.json"
else
    echo ""
    echo "📦 Dateien befinden sich in: $LOCAL_DOWNLOADS"
    echo "ℹ️  Manueller Upload:"
    echo "   scp -r $LOCAL_DOWNLOADS/* $SERVER_USER@$SERVER_HOST:$SERVER_PATH/downloads/"
fi

echo ""
echo "✨ Fertig!"

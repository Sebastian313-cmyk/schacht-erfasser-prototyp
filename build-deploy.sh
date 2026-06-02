#!/bin/bash

# ============================================================
# SELF-HOSTED BUILD & DEPLOY - Erfasser App
# Baut alle Plattformen und deployed zu Firebase/GitHub/Lokal
# ============================================================

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║   🚀 Erfasser App - Self-Hosted Deployment           ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# ========== KONFIGURATION ==========
VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUILD=$(grep 'version:' pubspec.yaml | sed 's/.*+//')

echo "📦 Version: $VERSION (Build $BUILD)"
echo ""

# ========== CLEANUP ==========
echo "[1/7] 🧹 Cleanup..."
flutter clean
rm -rf build/web/downloads
mkdir -p build/web/downloads

# ========== DEPENDENCIES ==========
echo ""
echo "[2/7] 📥 Dependencies aktualisieren..."
flutter pub get

# ========== ANDROID BUILD ==========
echo ""
echo "[3/7] 🤖 Build Android APK..."
flutter build apk --release

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/erfasser-app.apk
    SIZE=$(du -h build/web/downloads/erfasser-app.apk | cut -f1)
    echo "   ✅ APK erstellt ($SIZE)"
else
    echo "   ❌ APK Build fehlgeschlagen!"
fi

# ========== WINDOWS BUILD ==========
echo ""
echo "[4/7] 🪟 Build Windows..."
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    flutter build windows --release
    echo "   ✅ Windows Build erstellt"
    echo "   ℹ️  Bitte Inno Setup manuell ausführen: iscc erfasser-app.iss"
else
    echo "   ⚠️  Windows Build übersprungen (nur auf Windows möglich)"
fi

# ========== WEB BUILD ==========
echo ""
echo "[5/7] 🌐 Build Web..."
flutter build web --release

if [ -d "build/web" ]; then
    echo "   ✅ Web Build erstellt"
else
    echo "   ❌ Web Build fehlgeschlagen!"
    exit 1
fi

# ========== VERSION.JSON ERSTELLEN ==========
echo ""
echo "[6/7] 📄 Erstelle version.json..."

cat > build/web/version.json << EOF
{
  "version": "$VERSION",
  "buildNumber": $BUILD,
  "releaseDate": "$(date +%Y-%m-%d)",
  "releaseNotes": "✨ Version $VERSION\n\n🔄 Automatisches Update\n🐛 Bugfixes und Verbesserungen\n⚡ Performance-Optimierungen",
  "forceUpdate": false,
  "platform": {
    "android": {
      "url": "/downloads/erfasser-app.apk",
      "size": "$(du -h build/web/downloads/erfasser-app.apk 2>/dev/null | cut -f1 || echo '~25')"
    },
    "windows": {
      "url": "/downloads/erfasser-app-setup.exe",
      "size": "~45 MB"
    },
    "linux": {
      "url": "/downloads/erfasser-app.AppImage",
      "size": "~40 MB"
    },
    "macos": {
      "url": "/downloads/erfasser-app.dmg",
      "size": "~50 MB"
    }
  }
}
EOF

echo "   ✅ version.json erstellt"

# ========== DEPLOYMENT WÄHLEN ==========
echo ""
echo "[7/7] 🚀 Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Wähle Deployment-Option:"
echo ""
echo "  1) 🔥 Firebase Hosting (empfohlen)"
echo "  2) 🐙 GitHub Pages"
echo "  3) 🌐 Netlify"
echo "  4) 🖥️  Lokaler Test-Server"
echo "  5) ❌ Nur Build (kein Deploy)"
echo ""
read -p "Option (1-5): " option

case $option in
    1)
        echo ""
        echo "🔥 Deploying zu Firebase Hosting..."
        
        # Check ob Firebase CLI installiert ist
        if ! command -v firebase &> /dev/null; then
            echo "❌ Firebase CLI nicht gefunden!"
            echo "   Installation: npm install -g firebase-tools"
            echo "   Dann: firebase login && firebase init hosting"
            exit 1
        fi
        
        firebase deploy --only hosting
        
        if [ $? -eq 0 ]; then
            echo ""
            echo "╔════════════════════════════════════════════════════════╗"
            echo "║   ✅ DEPLOYMENT ERFOLGREICH!                          ║"
            echo "╚════════════════════════════════════════════════════════╝"
            echo ""
            echo "🌐 Deine App ist live!"
            echo "📱 Teste Updates in Desktop/Mobile Apps"
            echo ""
            echo "URLs:"
            firebase hosting:sites:list
        else
            echo "❌ Firebase Deployment fehlgeschlagen!"
        fi
        ;;
        
    2)
        echo ""
        echo "🐙 Deploying zu GitHub Pages..."
        
        cd build/web
        
        # Check ob git repo existiert
        if [ ! -d ".git" ]; then
            git init
            echo "ℹ️  Neues Git-Repo erstellt"
        fi
        
        git add .
        git commit -m "Deploy v$VERSION+$BUILD - $(date +%Y-%m-%d)"
        
        # Branch gh-pages erstellen/wechseln
        git branch -M gh-pages
        
        echo ""
        read -p "GitHub Repo URL (z.B. https://github.com/user/repo.git): " repo_url
        
        if [ -n "$repo_url" ]; then
            git remote remove origin 2>/dev/null || true
            git remote add origin "$repo_url"
            git push -f origin gh-pages
            
            echo ""
            echo "╔════════════════════════════════════════════════════════╗"
            echo "║   ✅ PUSH ERFOLGREICH!                                ║"
            echo "╚════════════════════════════════════════════════════════╝"
            echo ""
            echo "Aktiviere GitHub Pages:"
            echo "1. Gehe zu: https://github.com/USER/REPO/settings/pages"
            echo "2. Source: gh-pages"
            echo "3. Warte ~1 Minute"
            echo "4. URL: https://USER.github.io/REPO"
        fi
        
        cd ../..
        ;;
        
    3)
        echo ""
        echo "🌐 Deploying zu Netlify..."
        
        if ! command -v netlify &> /dev/null; then
            echo "❌ Netlify CLI nicht gefunden!"
            echo "   Installation: npm install -g netlify-cli"
            echo "   Dann: netlify login"
            exit 1
        fi
        
        netlify deploy --dir=build/web --prod
        
        echo ""
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║   ✅ DEPLOYMENT ERFOLGREICH!                          ║"
        echo "╚════════════════════════════════════════════════════════╝"
        ;;
        
    4)
        echo ""
        echo "🖥️  Starte lokalen Test-Server..."
        echo ""
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║   🌐 SERVER LÄUFT                                     ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        echo "Zugriff:"
        echo "  Lokal:    http://localhost:8000"
        echo "  Netzwerk: http://$(hostname -I | awk '{print $1}'):8000"
        echo ""
        echo "Drücke Strg+C zum Beenden"
        echo ""
        
        cd build/web
        
        # Python Server starten
        if command -v python3 &> /dev/null; then
            python3 -m http.server 8000 --bind 0.0.0.0
        elif command -v python &> /dev/null; then
            python -m http.server 8000 --bind 0.0.0.0
        else
            echo "❌ Python nicht gefunden!"
            echo "   Alternative: npx serve -p 8000"
        fi
        ;;
        
    5)
        echo ""
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║   ✅ BUILD ABGESCHLOSSEN                              ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        echo "📦 Builds befinden sich in: build/web/"
        echo ""
        echo "Manuelles Deployment:"
        echo "  Firebase:  firebase deploy --only hosting"
        echo "  GitHub:    cd build/web && git push origin gh-pages"
        echo "  Netlify:   netlify deploy --dir=build/web --prod"
        echo "  Lokal:     cd build/web && python -m http.server 8000"
        ;;
        
    *)
        echo "❌ Ungültige Option!"
        exit 1
        ;;
esac

echo ""
echo "🎉 Fertig!"

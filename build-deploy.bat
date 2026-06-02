@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM SELF-HOSTED BUILD & DEPLOY - Erfasser App (Windows)
REM ============================================================

echo ╔════════════════════════════════════════════════════════╗
echo ║   🚀 Erfasser App - Self-Hosted Deployment           ║
echo ╚════════════════════════════════════════════════════════╝
echo.

REM ========== VERSION AUSLESEN ==========
for /f "tokens=2 delims=: " %%a in ('findstr /C:"version:" pubspec.yaml') do set FULL_VERSION=%%a
for /f "tokens=1 delims=+" %%a in ("%FULL_VERSION%") do set VERSION=%%a
for /f "tokens=2 delims=+" %%a in ("%FULL_VERSION%") do set BUILD=%%a

echo 📦 Version: %VERSION% (Build %BUILD%)
echo.

REM ========== CLEANUP ==========
echo [1/7] 🧹 Cleanup...
call flutter clean
if exist build\web\downloads rmdir /s /q build\web\downloads
mkdir build\web\downloads

REM ========== DEPENDENCIES ==========
echo.
echo [2/7] 📥 Dependencies aktualisieren...
call flutter pub get

REM ========== ANDROID BUILD ==========
echo.
echo [3/7] 🤖 Build Android APK...
call flutter build apk --release

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy "build\app\outputs\flutter-apk\app-release.apk" "build\web\downloads\erfasser-app.apk"
    echo    ✅ APK erstellt
) else (
    echo    ❌ APK Build fehlgeschlagen!
)

REM ========== WINDOWS BUILD ==========
echo.
echo [4/7] 🪟 Build Windows...
call flutter build windows --release

if exist "build\windows\x64\runner\Release" (
    echo    ✅ Windows Build erstellt
    
    REM Optional: Inno Setup automatisch ausführen
    if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
        if exist "erfasser-app.iss" (
            echo    📦 Erstelle Installer mit Inno Setup...
            "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" erfasser-app.iss
            
            if exist "output\erfasser-app-setup.exe" (
                copy "output\erfasser-app-setup.exe" "build\web\downloads\"
                echo    ✅ Installer erstellt
            )
        ) else (
            echo    ℹ️  erfasser-app.iss nicht gefunden
        )
    ) else (
        echo    ℹ️  Inno Setup nicht gefunden - Installer muss manuell erstellt werden
    )
) else (
    echo    ❌ Windows Build fehlgeschlagen!
)

REM ========== WEB BUILD ==========
echo.
echo [5/7] 🌐 Build Web...
call flutter build web --release

if exist "build\web" (
    echo    ✅ Web Build erstellt
) else (
    echo    ❌ Web Build fehlgeschlagen!
    exit /b 1
)

REM ========== VERSION.JSON ERSTELLEN ==========
echo.
echo [6/7] 📄 Erstelle version.json...

(
echo {
echo   "version": "%VERSION%",
echo   "buildNumber": %BUILD%,
echo   "releaseDate": "%date:~-4%-%date:~3,2%-%date:~0,2%",
echo   "releaseNotes": "✨ Version %VERSION%\n\n🔄 Automatisches Update\n🐛 Bugfixes\n⚡ Performance",
echo   "forceUpdate": false,
echo   "platform": {
echo     "android": {
echo       "url": "/downloads/erfasser-app.apk",
echo       "size": "~25 MB"
echo     },
echo     "windows": {
echo       "url": "/downloads/erfasser-app-setup.exe",
echo       "size": "~45 MB"
echo     }
echo   }
echo }
) > build\web\version.json

echo    ✅ version.json erstellt

REM ========== DEPLOYMENT WÄHLEN ==========
echo.
echo [7/7] 🚀 Deployment
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Wähle Deployment-Option:
echo.
echo   1^) 🔥 Firebase Hosting (empfohlen^)
echo   2^) 🐙 GitHub Pages
echo   3^) 🖥️  Lokaler Test-Server
echo   4^) ❌ Nur Build (kein Deploy^)
echo.
set /p option="Option (1-4): "

if "%option%"=="1" goto firebase
if "%option%"=="2" goto github
if "%option%"=="3" goto local
if "%option%"=="4" goto build_only

echo ❌ Ungültige Option!
exit /b 1

:firebase
echo.
echo 🔥 Deploying zu Firebase Hosting...

where firebase >nul 2>nul
if errorlevel 1 (
    echo ❌ Firebase CLI nicht gefunden!
    echo    Installation: npm install -g firebase-tools
    echo    Dann: firebase login ^&^& firebase init hosting
    exit /b 1
)

firebase deploy --only hosting

if errorlevel 0 (
    echo.
    echo ╔════════════════════════════════════════════════════════╗
    echo ║   ✅ DEPLOYMENT ERFOLGREICH!                          ║
    echo ╚════════════════════════════════════════════════════════╝
    echo.
    echo 🌐 Deine App ist live!
    echo 📱 Teste Updates in Desktop/Mobile Apps
    echo.
    firebase hosting:sites:list
) else (
    echo ❌ Firebase Deployment fehlgeschlagen!
)
goto end

:github
echo.
echo 🐙 Deploying zu GitHub Pages...
cd build\web

if not exist ".git" (
    git init
    echo ℹ️  Neues Git-Repo erstellt
)

git add .
git commit -m "Deploy v%VERSION%+%BUILD% - %date%"
git branch -M gh-pages

echo.
set /p repo_url="GitHub Repo URL (z.B. https://github.com/user/repo.git): "

if not "%repo_url%"=="" (
    git remote remove origin 2>nul
    git remote add origin %repo_url%
    git push -f origin gh-pages
    
    echo.
    echo ╔════════════════════════════════════════════════════════╗
    echo ║   ✅ PUSH ERFOLGREICH!                                ║
    echo ╚════════════════════════════════════════════════════════╝
    echo.
    echo Aktiviere GitHub Pages:
    echo 1. Gehe zu: https://github.com/USER/REPO/settings/pages
    echo 2. Source: gh-pages
    echo 3. Warte ~1 Minute
)

cd ..\..
goto end

:local
echo.
echo 🖥️  Starte lokalen Test-Server...
echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║   🌐 SERVER LÄUFT                                     ║
echo ╚════════════════════════════════════════════════════════╝
echo.
echo Zugriff:
echo   Lokal:    http://localhost:8000
echo   Netzwerk: http://[DEINE-IP]:8000
echo.
echo Drücke Strg+C zum Beenden
echo.

cd build\web

where python >nul 2>nul
if errorlevel 0 (
    python -m http.server 8000
) else (
    where npx >nul 2>nul
    if errorlevel 0 (
        npx serve -p 8000
    ) else (
        echo ❌ Weder Python noch Node.js gefunden!
        echo    Bitte installiere Python oder Node.js
    )
)

cd ..\..
goto end

:build_only
echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║   ✅ BUILD ABGESCHLOSSEN                              ║
echo ╚════════════════════════════════════════════════════════╝
echo.
echo 📦 Builds befinden sich in: build\web\
echo.
echo Manuelles Deployment:
echo   Firebase:  firebase deploy --only hosting
echo   GitHub:    cd build\web ^&^& git push origin gh-pages
echo   Lokal:     cd build\web ^&^& python -m http.server 8000
goto end

:end
echo.
echo 🎉 Fertig!
pause

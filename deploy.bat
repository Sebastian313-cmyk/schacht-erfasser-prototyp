@echo off
REM ============================================================
REM DEPLOYMENT SCRIPT - Erfasser App (Windows)
REM Baut alle Plattformen und deployt auf Webserver
REM ============================================================

setlocal enabledelayedexpansion

REM ========== KONFIGURATION ==========
set VERSION=1.1.0
set BUILD_NUMBER=2
set SERVER_USER=user
set SERVER_HOST=your-server.com
set SERVER_PATH=/var/www/erfasser-app
set LOCAL_DOWNLOADS=.\releases

echo ============================================================
echo    Erfasser App Deployment v%VERSION%+%BUILD_NUMBER%
echo ============================================================
echo.

REM ========== VORBEREITUNG ==========
echo [1/7] Erstelle Release-Ordner...
if exist "%LOCAL_DOWNLOADS%" rmdir /s /q "%LOCAL_DOWNLOADS%"
mkdir "%LOCAL_DOWNLOADS%"

REM ========== ANDROID BUILD ==========
echo.
echo [2/7] Build Android APK...
call flutter clean
call flutter pub get
call flutter build apk --release

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy "build\app\outputs\flutter-apk\app-release.apk" "%LOCAL_DOWNLOADS%\erfasser-app.apk"
    echo ✅ Android APK erstellt
) else (
    echo ❌ Android Build fehlgeschlagen!
    exit /b 1
)

REM ========== WINDOWS BUILD ==========
echo.
echo [3/7] Build Windows...
call flutter build windows --release

if exist "build\windows\x64\runner\Release" (
    echo ✅ Windows Build erstellt
    
    REM Optional: Inno Setup automatisch ausführen
    if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
        echo ℹ️  Erstelle Windows Installer...
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" erfasser-app.iss
        
        if exist "output\erfasser-app-setup.exe" (
            copy "output\erfasser-app-setup.exe" "%LOCAL_DOWNLOADS%\"
            echo ✅ Windows Installer erstellt
        )
    ) else (
        echo ⚠️  Inno Setup nicht gefunden - Installer muss manuell erstellt werden
    )
) else (
    echo ❌ Windows Build fehlgeschlagen!
)

REM ========== WEB BUILD ==========
echo.
echo [4/7] Build Web...
call flutter build web --release

if exist "build\web" (
    xcopy "build\web" "%LOCAL_DOWNLOADS%\web\" /E /I /Y
    echo ✅ Web Build erstellt
) else (
    echo ❌ Web Build fehlgeschlagen!
    exit /b 1
)

REM ========== VERSION.JSON ERSTELLEN ==========
echo.
echo [5/7] Erstelle version.json...
(
echo {
echo   "version": "%VERSION%",
echo   "buildNumber": %BUILD_NUMBER%,
echo   "releaseDate": "%date:~-4%-%date:~3,2%-%date:~0,2%",
echo   "releaseNotes": "Version %VERSION%\n\n✨ Neue Features\n🐛 Bugfixes",
echo   "forceUpdate": false,
echo   "platforms": {
echo     "android": {
echo       "downloadUrl": "https://%SERVER_HOST%/erfasser-app/downloads/erfasser-app.apk"
echo     },
echo     "windows": {
echo       "downloadUrl": "https://%SERVER_HOST%/erfasser-app/downloads/erfasser-app-setup.exe"
echo     },
echo     "web": {
echo       "cacheBustingEnabled": true
echo     }
echo   }
echo }
) > "%LOCAL_DOWNLOADS%\version.json"

echo ✅ version.json erstellt

REM ========== DATEIGRÖSSEN ANZEIGEN ==========
echo.
echo [6/7] Release-Dateien:
echo ====================================
dir /B "%LOCAL_DOWNLOADS%"

REM ========== UPLOAD-ANLEITUNG ==========
echo.
echo [7/7] Upload auf Server
echo ====================================
echo.
echo 📦 Dateien befinden sich in: %LOCAL_DOWNLOADS%
echo.
echo 📤 Upload mit WinSCP, FileZilla oder SCP:
echo    scp -r %LOCAL_DOWNLOADS%\* %SERVER_USER%@%SERVER_HOST%:%SERVER_PATH%/downloads/
echo.
echo Oder nutzen Sie das beiliegende upload.ps1 PowerShell-Script.
echo.
echo 🎉 Build abgeschlossen!
echo.

pause

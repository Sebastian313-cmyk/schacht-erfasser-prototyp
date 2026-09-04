@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM One-click Android install for local devices (no Play Store required).
set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"

echo ==============================================
echo   Erfasser App - Android Direktinstallation
echo ==============================================
echo.

where adb >nul 2>nul
if errorlevel 1 (
  echo [FEHLER] adb wurde nicht gefunden.
  echo Installiere Android Platform-Tools und stelle sicher, dass adb im PATH ist.
  echo Download: https://developer.android.com/tools/releases/platform-tools
  echo.
  pause
  exit /b 1
)

if not exist "%APK_PATH%" (
  echo [INFO] Keine Release-APK gefunden: %APK_PATH%
  echo [INFO] Erstelle jetzt eine neue APK ...
  call flutter build apk --release
  if errorlevel 1 (
    echo [FEHLER] APK-Build fehlgeschlagen.
    echo.
    pause
    exit /b 1
  )
)

echo [INFO] Suche angeschlossene Android-Geraete ...
set "DEVICE_FOUND="
for /f "skip=1 tokens=1,2" %%A in ('adb devices') do (
  if "%%B"=="device" set "DEVICE_FOUND=1"
)

if not defined DEVICE_FOUND (
  echo [FEHLER] Kein freigeschaltetes Android-Geraet gefunden.
  echo - USB-Debugging aktivieren
  echo - USB-Verbindung bestaetigen (RSA-Fingerprint)
  echo - Treiber pruefen
  echo.
  adb devices
  echo.
  pause
  exit /b 1
)

echo [INFO] Installiere APK auf dem Geraet ...
adb install -r "%APK_PATH%"
if errorlevel 1 (
  echo [FEHLER] Installation fehlgeschlagen.
  echo.
  pause
  exit /b 1
)

echo.
echo [OK] Installation erfolgreich.
echo APK: %APK_PATH%
echo.
pause

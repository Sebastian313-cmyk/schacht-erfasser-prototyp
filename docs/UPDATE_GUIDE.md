# ============================================================
# ERFASSER APP - CROSS-PLATFORM UPDATE GUIDE
# ============================================================

## 📦 Update-System Übersicht

Die App unterstützt automatische Updates auf allen Plattformen:

### ✅ Unterstützte Plattformen
- 🌐 **Web**: Service Worker + Cache-Invalidation
- 🤖 **Android**: Google Play Store / APK Sideloading
- 🍎 **iOS**: Apple App Store
- 🪟 **Windows**: Microsoft Store / MSIX / EXE-Installer
- 🐧 **Linux**: Snap / Flatpak / AppImage
- 🍏 **macOS**: Mac App Store / DMG

---

## 🚀 Implementierung

### 1. Dependencies installieren

```bash
cd erfasser_app
flutter pub get
```

### 2. Server-Setup (version.json)

Erstellen Sie eine `version.json` auf Ihrem Server:

```json
{
  "version": "1.1.0",
  "buildNumber": 2,
  "releaseNotes": "Neue Features und Bugfixes",
  "downloadUrl": "https://your-server.com/downloads/latest",
  "forceUpdate": false
}
```

**URL im Code anpassen:**
```dart
// lib/services/update_service.dart, Zeile 21
static const String _updateCheckUrl = 'https://IHR-SERVER.com/api/version.json';
```

### 3. Platform-Specific Configuration

#### 🌐 **Web**

**Service Worker aktivieren:**
```bash
# web/sw.js erstellen (optional für besseres Caching)
flutter build web --release
```

Die Web-Version lädt automatisch neu, wenn eine neue Version verfügbar ist.

#### 🤖 **Android**

**Option A: Google Play Store (empfohlen)**
1. App in Google Play Console hochladen
2. URL in `update_service.dart` anpassen:
   ```dart
   'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME'
   ```

**Option B: APK Sideloading**
1. APK auf Server hochladen
2. Nutzer muss "Unbekannte Quellen" aktivieren

**Build:**
```bash
flutter build apk --release
# oder
flutter build appbundle --release
```

#### 🍎 **iOS**

**App Store:**
1. App in App Store Connect hochladen
2. URL in `update_service.dart` anpassen:
   ```dart
   'https://apps.apple.com/app/idYOUR_APP_ID'
   ```

**Build:**
```bash
flutter build ios --release
```

#### 🪟 **Windows**

**Option A: Microsoft Store (empfohlen)**
```bash
flutter build windows --release
# MSIX-Paket erstellen
```

**Option B: EXE-Installer**
1. Inno Setup / WiX verwenden
2. Installer auf Server hochladen

**Build:**
```bash
flutter build windows --release
```

#### 🐧 **Linux**

**Option A: Snap Store**
```bash
# snapcraft.yaml erstellen
snapcraft
sudo snap install erfasser-app_*.snap
```

**Option B: Flatpak**
```bash
# com.yourcompany.erfasser.yml erstellen
flatpak-builder build-dir com.yourcompany.erfasser.yml
```

**Option C: AppImage**
```bash
# AppImage mit linuxdeploy erstellen
flutter build linux --release
./linuxdeploy --appdir=build/linux/x64/release/bundle --output appimage
```

#### 🍏 **macOS**

**Option A: Mac App Store**
```bash
flutter build macos --release
```

**Option B: DMG**
1. DMG mit `create-dmg` oder `appdmg` erstellen
2. DMG auf Server hochladen

---

## 🔧 Konfiguration

### Update-Check Intervall anpassen

```dart
// lib/main.dart
UpdateChecker(
  checkOnStart: true,              // Beim Start prüfen
  checkInterval: Duration(hours: 24), // Alle 24 Stunden
  child: child ?? const SizedBox.shrink(),
)
```

### Forced Updates aktivieren

```json
{
  "version": "2.0.0",
  "forceUpdate": true,  // ← Nutzer MUSS updaten
  "releaseNotes": "Kritische Sicherheits-Updates"
}
```

### Manuellen Update-Button hinzufügen

```dart
// In beliebigem Screen (z.B. Einstellungen)
IconButton(
  icon: const Icon(Icons.system_update),
  onPressed: () async {
    final info = await UpdateService.checkForUpdates();
    if (info != null) {
      showDialog(
        context: context,
        builder: (_) => UpdateDialog(updateInfo: info),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ App ist auf dem neuesten Stand')),
      );
    }
  },
)
```

---

## 📝 Deployment-Workflow

### 1. Version erhöhen

```yaml
# pubspec.yaml
version: 1.1.0+2  # Format: MAJOR.MINOR.PATCH+BUILD
```

### 2. Server aktualisieren

```json
// version.json auf Server hochladen
{
  "version": "1.1.0",
  "buildNumber": 2,
  "releaseNotes": "..."
}
```

### 3. Builds erstellen

```bash
# Alle Plattformen
flutter build web --release
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
flutter build windows --release
flutter build linux --release
flutter build macos --release
```

### 4. Veröffentlichen

- **Web**: Auf Webserver deployen (z.B. Firebase Hosting, Netlify)
- **Android**: Google Play Console
- **iOS**: App Store Connect
- **Windows**: Microsoft Store / Server-Download
- **Linux**: Snap Store / Flathub / Server-Download
- **macOS**: Mac App Store / Server-Download

---

## 🐛 Troubleshooting

### Update-Check funktioniert nicht

1. **Server-URL prüfen:**
   ```dart
   print(await http.get(Uri.parse(_updateCheckUrl)));
   ```

2. **Internet-Verbindung testen:**
   ```dart
   final info = await UpdateService.checkForUpdates();
   print('Update-Info: $info');
   ```

3. **CORS bei Web aktivieren** (falls nötig):
   ```
   Access-Control-Allow-Origin: *
   ```

### Platform-spezifische Probleme

- **Android**: Permissions in `AndroidManifest.xml` prüfen
- **iOS**: `Info.plist` auf `NSAppTransportSecurity` prüfen
- **Web**: Service Worker registriert? (`chrome://serviceworker-internals/`)
- **Windows**: Firewall-Einstellungen prüfen

---

## 🔒 Sicherheit

### Best Practices

1. **HTTPS verwenden** für version.json
2. **Signature-Checks** für Downloads implementieren
3. **Rate-Limiting** auf Server-Seite
4. **Fallback-Mechanismus** bei Netzwerkfehlern

### Code-Signing

- **Android**: APK signieren mit Keystore
- **iOS**: Xcode Developer Certificate
- **Windows**: Authenticode-Signatur
- **macOS**: Apple Developer ID

---

## 📚 Weitere Ressourcen

- [Flutter Upgrader Package](https://pub.dev/packages/upgrader)
- [Package Info Plus](https://pub.dev/packages/package_info_plus)
- [URL Launcher](https://pub.dev/packages/url_launcher)
- [Flutter Deployment Docs](https://docs.flutter.dev/deployment)

---

## 💡 Tipps

1. **Testumgebung einrichten**: Separate version-beta.json für Tests
2. **Analytics hinzufügen**: Update-Erfolgsrate tracken
3. **User-Feedback**: Option zum Überspringen von Updates (außer forceUpdate)
4. **Staged Rollout**: Nicht alle User gleichzeitig updaten (Play Store bietet das)

---

**Viel Erfolg mit dem Update-System! 🚀**

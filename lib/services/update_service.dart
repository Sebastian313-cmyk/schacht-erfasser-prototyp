import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// ============================================================
/// SELF-HOSTED UPDATE SERVICE
/// ============================================================
/// 
/// Updates direkt über die Web-App oder vom Entwickler-PC:
/// - Web-App hostet selbst die version.json
/// - Alle Downloads liegen im gleichen Web-Verzeichnis
/// - KEIN separater Server nötig!
/// - Entwickler-PC kann als lokaler Update-Server dienen
/// 
/// Setup:
/// 1. flutter build web --release
/// 2. Alle Builds in build/web/downloads/ ablegen
/// 3. Web-App deployen (Firebase, Netlify, GitHub Pages, etc.)
/// 4. ODER: python -m http.server 8000 -d build/web
/// ============================================================

class UpdateService {
  // ========== KONFIGURATION ==========
  
  /// Basis-URL: Wo läuft die Web-App?
  /// - Produktion: 'https://meine-domain.com'
  /// - Lokal/Dev: 'http://localhost:8000' oder 'http://192.168.1.100:8000'
  /// - GitHub Pages: 'https://username.github.io/erfasser-app'
  /// - Firebase: 'https://erfasser-app.web.app'
  /// - Netlify: 'https://erfasser-app.netlify.app'
  static const String baseUrl = kIsWeb 
      ? '' // Web: Relative URLs (gleiche Domain)
      : 'http://localhost:8000'; // Desktop/Mobile: Zu lokalem Dev-Server
  
  /// Update-Check URL (relativ zur Web-App)
  static String get updateCheckUrl => '$baseUrl/version.json';
  
  /// Download-Pfade (alle im gleichen Verzeichnis wie Web-App)
  static String get androidApkUrl => '$baseUrl/downloads/erfasser-app.apk';
  static String get windowsInstallerUrl => '$baseUrl/downloads/erfasser-app-setup.exe';
  static String get linuxAppImageUrl => '$baseUrl/downloads/erfasser-app.AppImage';
  static String get macOsDmgUrl => '$baseUrl/downloads/erfasser-app.dmg';
  
  // ========== Version Check ==========
  
  /// Prüft, ob eine neue Version verfügbar ist
  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;

      if (kDebugMode) {
        print('📦 Aktuelle Version: $currentVersion+$buildNumber');
        print('🔍 Prüfe Updates von: $updateCheckUrl');
      }

      // Version abrufen (mit Cache-Busting)
      final url = Uri.parse('$updateCheckUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final latestVersion = data['version'] as String?;
        final latestBuild = data['buildNumber'] as int?;
        final releaseNotes = data['releaseNotes'] as String?;
        final forceUpdate = data['forceUpdate'] as bool? ?? false;

        if (latestVersion == null) {
          if (kDebugMode) print('⚠️ Keine Version-Info gefunden');
          return null;
        }

        // Version vergleichen
        final isNewer = _isVersionNewer(currentVersion, latestVersion) ||
            (currentVersion == latestVersion && 
             latestBuild != null && 
             int.tryParse(buildNumber) != null && 
             latestBuild > int.parse(buildNumber));

        if (isNewer) {
          if (kDebugMode) {
            print('✨ Neue Version verfügbar: $latestVersion (aktuell: $currentVersion)');
          }
          
          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            releaseNotes: releaseNotes ?? 'Neue Version verfügbar',
            downloadUrl: _getPlatformDownloadUrl(),
            forceUpdate: forceUpdate,
          );
        } else {
          if (kDebugMode) print('✅ App ist auf dem neuesten Stand');
        }
      } else {
        if (kDebugMode) print('❌ Server-Fehler: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Update-Check fehlgeschlagen: $e');
      }
      return null;
    }
  }

  static bool _isVersionNewer(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ========== Platform-Specific Download URLs ==========

  static String _getPlatformDownloadUrl() {
    if (kIsWeb) {
      // Web: Seite neu laden
      return Uri.base.toString();
    } else if (Platform.isAndroid) {
      return androidApkUrl;
    } else if (Platform.isWindows) {
      return windowsInstallerUrl;
    } else if (Platform.isLinux) {
      return linuxAppImageUrl;
    } else if (Platform.isMacOS) {
      return macOsDmgUrl;
    }
    return baseUrl;
  }

  // ========== Update durchführen ==========

  static Future<void> performUpdate(UpdateInfo info) async {
    if (kDebugMode) {
      print('🚀 Starte Update für ${getPlatformName()}');
      print('📥 Download-URL: ${info.downloadUrl}');
    }

    if (kIsWeb) {
      await _updateWeb();
    } else {
      // Desktop/Mobile: Download-Seite im Browser öffnen
      await _openUrl(info.downloadUrl);
      
      if (kDebugMode) {
        print('ℹ️  Datei wird heruntergeladen...');
        print('ℹ️  Bitte nach Download installieren und App neu starten');
      }
    }
  }

  // ========== Web Update ==========
  
  static Future<void> _updateWeb() async {
    if (kIsWeb) {
      if (kDebugMode) print('🌐 Web-App wird neu geladen...');
      // Seite neu laden (Service Worker cached neue Version)
      final currentUrl = Uri.base.toString();
      await launchUrl(Uri.parse(currentUrl), mode: LaunchMode.platformDefault);
    }
  }

  // ========== Helper ==========

  static Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (kDebugMode) print('✅ URL geöffnet: $url');
    } else {
      if (kDebugMode) print('❌ Konnte URL nicht öffnen: $url');
      throw Exception('Konnte URL nicht öffnen: $url');
    }
  }

  static String getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return 'Unknown';
  }

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}

// ========== Data Model ==========

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final bool forceUpdate;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    this.forceUpdate = false,
  });

  @override
  String toString() {
    return 'UpdateInfo(current: $currentVersion, latest: $latestVersion, url: $downloadUrl, force: $forceUpdate)';
  }
}

# Änderungen für Medien-Export aus Assets

## Problem
Test-Daten speichern Medien als Datei-Pfade (`'mediaFotos': ['App/ES/ES_Bild.png']`), 
aber `_decodeDataUrl` kann nur Data URLs dekodieren.

## Lösung
`_decodeDataUrl` zu async machen und Asset-Dateien laden.

## Benötigte Änderungen in `lib/services/export_service.dart`:

### 1. Ändere die Funktion `_decodeDataUrl` (Zeile 741):

**VON:**
```dart
static Uint8List? _decodeDataUrl(String dataUrl) {
  // Handle data URLs (data:image/png;base64,...)
  final idx = dataUrl.indexOf(',');
  if (idx != -1) {
    final base64Part = dataUrl.substring(idx + 1);
    try {
      return Uint8List.fromList(base64Decode(base64Part));
    } catch (_) {
      return null;
    }
  }
  
  // Handle file paths (App/ES/ES_Bild.png) - for test data and legacy data
  // that stored file paths instead of data URLs
  debugPrint('[_decodeDataUrl] Warning: dataUrl is a file path, not a data URL: $dataUrl');
  return null; // For now, we can't load from assets in ZIP export, but we log the warning
}
```

**ZU:**
```dart
static Future<Uint8List?> _decodeDataUrl(String dataUrl) async {
  // Handle data URLs (data:image/png;base64,...)
  final idx = dataUrl.indexOf(',');
  if (idx != -1) {
    final base64Part = dataUrl.substring(idx + 1);
    try {
      return Uint8List.fromList(base64Decode(base64Part));
    } catch (_) {
      return null;
    }
  }
  
  // Handle asset file paths (App/ES/ES_Bild.png) - for test data
  if (dataUrl.startsWith('App/') || dataUrl.startsWith('assets/')) {
    try {
      final assetPath = dataUrl.startsWith('assets/') ? dataUrl : 'assets/$dataUrl';
      final ByteData data = await rootBundle.load(assetPath);
      debugPrint('[_decodeDataUrl] Loaded asset: $assetPath (${data.lengthInBytes} bytes)');
      return data.buffer.asUint8List();
    } catch (e) {
      debugPrint('[_decodeDataUrl] Error loading asset $dataUrl: $e');
      return null;
    }
  }
  
  debugPrint('[_decodeDataUrl] Warning: Unknown format for dataUrl: $dataUrl');
  return null;
}
```

### 2. Füge `await` bei allen Aufrufen hinzu:

**Zeile 362:** `final bytes = _decodeDataUrl(f.dataUrl);` 
→ `final bytes = await _decodeDataUrl(f.dataUrl);`

**Zeile 372:** `final bytes = _decodeDataUrl(v.dataUrl);`
→ `final bytes = await _decodeDataUrl(v.dataUrl);`

**Zeile 417:** `final bytes = _decodeDataUrl(f.dataUrl);`
→ `final bytes = await _decodeDataUrl(f.dataUrl);`

**Zeile 427:** `final bytes = _decodeDataUrl(v.dataUrl);`
→ `final bytes = await _decodeDataUrl(v.dataUrl);`

### 3. Stelle sicher, dass `assets/` in pubspec.yaml steht:

```yaml
flutter:
  assets:
    - App/ES/
    - App/Grube/
    # ... alle anderen Asset-Ordner
```

## Test
Nach den Änderungen:
1. App neu starten
2. Export durchführen
3. Prüfen ob Medien in den Positions-Ordnern sind

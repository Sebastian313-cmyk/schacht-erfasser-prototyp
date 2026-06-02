import 'dart:io';

void main() {
  final file = File('lib/services/export_service.dart');
  var content = file.readAsStringSync();
  
  // 1. Ändere Funktion-Signatur
  content = content.replaceAll(
    'static Uint8List? _decodeDataUrl(String dataUrl) {',
    'static Future<Uint8List?> _decodeDataUrl(String dataUrl) async {'
  );
  
  // 2. Ersetze die Return-Logik für Asset-Pfade
  content = content.replaceAll(
    '''  // Handle file paths (App/ES/ES_Bild.png) - for test data and legacy data
    // that stored file paths instead of data URLs
    debugPrint('[_decodeDataUrl] Warning: dataUrl is a file path, not a data URL: \$dataUrl');
    return null; // For now, we can't load from assets in ZIP export, but we log the warning''',
    '''  // Handle asset file paths (App/ES/ES_Bild.png) - for test data
    if (dataUrl.startsWith('App/') || dataUrl.startsWith('assets/')) {
      try {
        final assetPath = dataUrl.startsWith('assets/') ? dataUrl : 'assets/\$dataUrl';
        final ByteData data = await rootBundle.load(assetPath);
        debugPrint('[_decodeDataUrl] Loaded asset: \$assetPath (\${data.lengthInBytes} bytes)');
        return data.buffer.asUint8List();
      } catch (e) {
        debugPrint('[_decodeDataUrl] Error loading asset \$dataUrl: \$e');
        return null;
      }
    }
    
    debugPrint('[_decodeDataUrl] Warning: Unknown format for dataUrl: \$dataUrl');
    return null'''
  );
  
  // 3. Füge await zu allen Aufrufen hinzu
  content = content.replaceAll(
    'final bytes = _decodeDataUrl(',
    'final bytes = await _decodeDataUrl('
  );
  
  file.writeAsStringSync(content);
  // print('✅ Änderungen erfolgreich angewendet!');
  // print('   - _decodeDataUrl ist jetzt async');
  // print('   - Asset-Loading hinzugefügt');
  // print('   - 4 await-Aufrufe hinzugefügt');
}

import 'dart:io';

void main() {
  final file = File('lib/services/export_service.dart');
  var content = file.readAsStringSync();
  
  // Add debug logs to _rfActive
  content = content.replaceAll(
    '''  static bool _rfActive(Map<String, dynamic> meta) {
    final schaeden = meta['schaeden'];
    
    // Handle both List<dynamic> and String formats
    if (schaeden is List) {
      return schaeden.map((e) => e.toString().trim()).contains('Keine Rückenfreiheit');
    } else if (schaeden is String) {
      // If stored as CSV string, split and check
      return schaeden.split(',').map((e) => e.trim()).contains('Keine Rückenfreiheit');
    }
    
    return false;
  }''',
    '''  static bool _rfActive(Map<String, dynamic> meta) {
    final schaeden = meta['schaeden'];
    debugPrint('[_rfActive] schaeden type: \${schaeden.runtimeType}, value: \$schaeden');
    
    // Handle both List<dynamic> and String formats
    if (schaeden is List) {
      final hasRF = schaeden.map((e) => e.toString().trim()).contains('Keine Rückenfreiheit');
      debugPrint('[_rfActive] List contains "Keine Rückenfreiheit": \$hasRF');
      return hasRF;
    } else if (schaeden is String) {
      // If stored as CSV string, split and check
      final hasRF = schaeden.split(',').map((e) => e.trim()).contains('Keine Rückenfreiheit');
      debugPrint('[_rfActive] String contains "Keine Rückenfreiheit": \$hasRF');
      return hasRF;
    }
    
    debugPrint('[_rfActive] schaeden is neither List nor String, returning false');
    return false;
  }'''
  );
  
  // Add debug log when calling PdfMiniKit.esSteckbrief
  content = content.replaceAll(
    '''      case 'ES':
        final rf = _rfActive(meta);
        final bytes = await PdfMiniKit.esSteckbrief(fields: fields, rf: rf, notes: notes);
        return Uint8List.fromList(bytes);''',
    '''      case 'ES':
        final rf = _rfActive(meta);
        debugPrint('[buildEinzelPdfFromMeta] ES: rf=\$rf, fields keys: \${fields.keys.where((k) => k.contains('Steig') || k.contains('Rück')).toList()}');
        final bytes = await PdfMiniKit.esSteckbrief(fields: fields, rf: rf, notes: notes);
        return Uint8List.fromList(bytes);'''
  );
  
  file.writeAsStringSync(content);
  // print('✅ Debug-Logs hinzugefügt!');
}

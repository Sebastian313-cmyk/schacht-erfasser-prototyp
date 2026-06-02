import 'dart:io';

void main() {
  final file = File('lib/services/export_service.dart');
  var content = file.readAsStringSync();
  
  // Fix missing semicolon
  content = content.replaceAll(
    "debugPrint('[_decodeDataUrl] Warning: Unknown format for dataUrl: \$dataUrl');\n    return null\n  }",
    "debugPrint('[_decodeDataUrl] Warning: Unknown format for dataUrl: \$dataUrl');\n    return null;\n  }"
  );
  
  file.writeAsStringSync(content);
  // print('✅ Semikolon hinzugefügt!');
}

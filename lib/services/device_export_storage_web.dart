import 'dart:typed_data';

import 'web_download.dart';

Future<String?> saveExportToDevice({
  required Uint8List bytes,
  required String fileName,
  required String exportFolderName,
  bool inErfassungen = false,
}) async {
  downloadBytesWeb(bytes, fileName);
  return 'Downloads/$fileName';
}

Future<int> saveZipStructureToDevice(Uint8List zipBytes) async {
  return 0;
}

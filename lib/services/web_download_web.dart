import 'dart:typed_data';
// ignore: deprecated_member_use,avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadBytesWeb(Uint8List bytes, String suggestedFileName) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = suggestedFileName;
  html.document.body!.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}

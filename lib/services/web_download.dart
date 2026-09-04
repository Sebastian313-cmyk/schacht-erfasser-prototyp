// Plattformabhängiger Download:
// Unter Flutter Web echte Browser-Download-Implementierung,
// unter VM/Test/anderen Plattformen: Stub (kein Fehler beim Testlauf).
export 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';

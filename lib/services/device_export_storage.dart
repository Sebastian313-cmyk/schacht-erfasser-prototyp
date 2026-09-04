// Plattformabhängiger Export-Speicher.
// Auf Android wird versucht, in den sichtbaren Download-Ordner zu schreiben.
// Im Web werden die erzeugten Dateien als echte Browser-Downloads ausgegeben.
export 'device_export_storage_stub.dart'
    if (dart.library.io) 'device_export_storage_io.dart'
    if (dart.library.html) 'device_export_storage_web.dart';

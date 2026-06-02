// Plattformabhängiger Export-Speicher.
// Auf Android wird versucht, in den sichtbaren Download-Ordner zu schreiben.
export 'device_export_storage_stub.dart' if (dart.library.io) 'device_export_storage_io.dart';

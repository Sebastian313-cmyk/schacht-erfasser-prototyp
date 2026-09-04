// Dart conditionally imports for web/non-web support
export 'pdf_viewer_impl_web.dart' if (dart.library.io) 'pdf_viewer_impl_stub.dart';

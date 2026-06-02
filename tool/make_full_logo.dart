import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main(List<String> args) async {
  final inputPath = 'App/Logo/3f39f55e-78f4-473f-b6c2-69f9ffc486b9-md.jpeg';
  final outputPath = 'App/Logo/logo_full.png';

  if (!File(inputPath).existsSync()) {
    stdout.writeln('Input file not found: $inputPath');
    exit(2);
  }

  final bytes = await File(inputPath).readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) {
    stdout.writeln('Could not decode image');
    exit(3);
  }

  const size = 1024;
  // Light blue background (same as earlier): #E6F2FF
  final bg = img.ColorRgb8(0xE6, 0xF2, 0xFF);
  final out = img.Image(width: size, height: size);
  // fill background
  img.fill(out, color: bg);

  // Fit the source image into the square, cover entire area (like BoxFit.cover)
  // Compute scale to fill
  final scale = math.max(size / image.width, size / image.height);
  final targetW = (image.width * scale).round();
  final targetH = (image.height * scale).round();
  final resized = img.copyResize(image, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);

  // Center it
  final x = (size - resized.width) ~/ 2;
  final y = (size - resized.height) ~/ 2;
  img.compositeImage(out, resized, dstX: x, dstY: y);

  final outBytes = img.encodePng(out);
  await File(outputPath).writeAsBytes(outBytes);
  stdout.writeln('Wrote $outputPath');
}

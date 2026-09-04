import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final inputPath = 'App/Logo/3f39f55e-78f4-473f-b6c2-69f9ffc486b9-md.jpeg';
  final outputPath = 'App/Logo/splash_padded.png';

  final bytes = await File(inputPath).readAsBytes();
  final original = img.decodeImage(bytes)!;

  // Zielgröße (z.B. 1024x1024)
  const size = 1024;
  // Padding (z.B. 20% rundum)
  final pad = (size * 0.2).toInt();
  final padded = img.Image(width: size, height: size);
  img.fill(padded, color: img.ColorRgba8(255, 255, 255, 0)); // transparent

  // Logo mittig platzieren
  final scaleW = (size - 2 * pad) / original.width;
  final scaleH = (size - 2 * pad) / original.height;
  final scale = scaleW < scaleH ? scaleW : scaleH;
  final newW = (original.width * scale).toInt();
  final newH = (original.height * scale).toInt();
  final resized = img.copyResize(original, width: newW, height: newH);

  img.compositeImage(
    padded,
    resized,
    dstX: ((size - newW) ~/ 2),
    dstY: ((size - newH) ~/ 2),
    blend: img.BlendMode.direct,
  );

  await File(outputPath).writeAsBytes(img.encodePng(padded));
  stdout.writeln('Splash-Bild mit Padding gespeichert: $outputPath');
}

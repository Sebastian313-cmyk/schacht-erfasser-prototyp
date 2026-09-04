import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class PdfAssets {
  static pw.MemoryImage? _cam;
  static pw.MemoryImage? _vid;

  static Future<void> preload() async {
    try {
      final camBytes = (await rootBundle.load('assets/icons/camera.png')).buffer.asUint8List();
      final vidBytes = (await rootBundle.load('assets/icons/video.png')).buffer.asUint8List();
      _cam = pw.MemoryImage(camBytes);
      _vid = pw.MemoryImage(vidBytes);
    } catch (e) {
      // fallback: leave images null; code using mediaLine must handle nulls
    }
  }

  static pw.Widget mediaLine({required int fotos, required int videos}) {
    final widgets = <pw.Widget>[];

    if (fotos > 0 && _cam != null) {
      widgets.add(pw.Image(_cam!, width: 12, height: 12));
      widgets.add(pw.SizedBox(width: 4));
      widgets.add(pw.Text('$fotos Foto(s)', style: const pw.TextStyle(fontSize: 10)));
      widgets.add(pw.SizedBox(width: 10));
    } else if (fotos > 0) {
      widgets.add(pw.Text('Fotos: $fotos', style: const pw.TextStyle(fontSize: 10)));
      widgets.add(pw.SizedBox(width: 10));
    }

    if (videos > 0 && _vid != null) {
      widgets.add(pw.Image(_vid!, width: 12, height: 12));
      widgets.add(pw.SizedBox(width: 4));
      widgets.add(pw.Text('$videos Video(s)', style: const pw.TextStyle(fontSize: 10)));
    } else if (videos > 0) {
      widgets.add(pw.Text('Videos: $videos', style: const pw.TextStyle(fontSize: 10)));
    }

    if (widgets.isEmpty) return pw.SizedBox();

    return pw.Row(children: widgets);
  }
}

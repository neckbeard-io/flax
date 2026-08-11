// Tool script to generate app icon PNGs from the FlaxLogo painter.
// Run: dart run tool/generate_icon.dart
//
// This requires a Flutter environment. For now, the SVG in assets/flax_logo.svg
// can be used with any SVG-to-PNG converter to generate the icons.
//
// Required sizes for macOS:
//   16, 32, 64, 128, 256, 512, 1024

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';

Future<void> main() async {
  final sizes = [16, 32, 64, 128, 256, 512, 1024];

  for (final size in sizes) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final s = size.toDouble();

    // Background
    final bgPaint = ui.Paint()..color = const ui.Color(0xFF1A1A2E);
    final bgRRect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(0, 0, s, s),
      ui.Radius.circular(s * 0.22),
    );
    canvas.drawRRect(bgRRect, bgPaint);

    // Draw flower
    _drawFlower(canvas, s);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    if (bytes != null) {
      final file = File(
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      print('Generated ${file.path}');
    }
  }
}

void _drawFlower(ui.Canvas canvas, double size) {
  final cx = size / 2;
  final cy = size * 0.44;
  final petalLength = size * 0.28;
  final petalWidth = size * 0.16;

  for (int i = 0; i < 5; i++) {
    final angle = (i * 72 - 90) * pi / 180;
    final pcx = cx + cos(angle) * petalLength * 0.52;
    final pcy = cy + sin(angle) * petalLength * 0.52;

    final paint = ui.Paint()
      ..color = i.isEven
          ? const ui.Color(0xFF4A6CF7)
          : const ui.Color(0xFF5B7DF2);

    canvas.save();
    canvas.translate(pcx, pcy);
    canvas.rotate(angle + pi / 2);

    final petalRect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: petalWidth,
        height: petalLength,
      ),
      ui.Radius.circular(petalWidth * 0.5),
    );
    canvas.drawRRect(petalRect, paint);
    canvas.restore();
  }

  canvas.drawCircle(
    ui.Offset(cx, cy),
    size * 0.07,
    ui.Paint()..color = const ui.Color(0xFFE8D44D),
  );
  canvas.drawCircle(
    ui.Offset(cx, cy),
    size * 0.04,
    ui.Paint()..color = const ui.Color(0xFFD4A017),
  );
}

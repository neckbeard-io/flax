import 'dart:math';
import 'package:flutter/material.dart';

class FlaxLogo extends StatelessWidget {
  final double size;
  const FlaxLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FlaxLogoPainter()),
    );
  }
}

class _FlaxLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.44;
    final petalLength = size.height * 0.28;
    final petalWidth = size.height * 0.16;

    // Draw 5 petals
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 - 90) * pi / 180;
      final pcx = cx + cos(angle) * petalLength * 0.52;
      final pcy = cy + sin(angle) * petalLength * 0.52;

      final paint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: i.isEven
                  ? [const Color(0xFF93B1F5), const Color(0xFF4A6CF7)]
                  : [const Color(0xFF7C9DED), const Color(0xFF5B7DF2)],
            ).createShader(
              Rect.fromCenter(
                center: Offset(pcx, pcy),
                width: petalWidth * 2,
                height: petalLength * 2,
              ),
            );

      canvas.save();
      canvas.translate(pcx, pcy);
      canvas.rotate(angle + pi / 2);

      final petalRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: petalWidth,
          height: petalLength,
        ),
        Radius.circular(petalWidth * 0.5),
      );
      canvas.drawRRect(petalRect, paint);
      canvas.restore();
    }

    // Center dot
    final centerPaint = Paint()..color = const Color(0xFFE8D44D);
    canvas.drawCircle(Offset(cx, cy), size.height * 0.07, centerPaint);
    final innerPaint = Paint()..color = const Color(0xFFD4A017);
    canvas.drawCircle(Offset(cx, cy), size.height * 0.04, innerPaint);

    // Stem
    final stemPaint = Paint()
      ..color = const Color(0xFF5CAD5C)
      ..strokeWidth = size.width * 0.025
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(cx, cy + petalLength * 0.6)
      ..quadraticBezierTo(
        cx - size.width * 0.02,
        size.height * 0.78,
        cx,
        size.height * 0.92,
      );
    canvas.drawPath(stemPath, stemPaint);

    // Left leaf
    final leafPaint = Paint()..color = const Color(0xFF6BC06B);
    final leftLeaf = Path()
      ..moveTo(cx - size.width * 0.02, size.height * 0.7)
      ..quadraticBezierTo(
        cx - size.width * 0.18,
        size.height * 0.64,
        cx - size.width * 0.22,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        cx - size.width * 0.12,
        size.height * 0.7,
        cx - size.width * 0.02,
        size.height * 0.73,
      )
      ..close();
    canvas.drawPath(leftLeaf, leafPaint);

    // Right leaf
    final rightLeaf = Path()
      ..moveTo(cx + size.width * 0.01, size.height * 0.78)
      ..quadraticBezierTo(
        cx + size.width * 0.18,
        size.height * 0.72,
        cx + size.width * 0.22,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        cx + size.width * 0.12,
        size.height * 0.78,
        cx + size.width * 0.01,
        size.height * 0.81,
      )
      ..close();
    canvas.drawPath(rightLeaf, leafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

class BalloonPainter extends CustomPainter {
  final Color color;
  final bool isActive;
  final bool isPower;

  BalloonPainter(
      {required this.color, required this.isActive, required this.isPower});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.5, h * 0.97);
    path.cubicTo(w * 0.28, h * 0.84, 0, h * 0.63, 0, h * 0.36);
    path.cubicTo(0, h * 0.08, w * 0.18, 0, w * 0.5, 0);
    path.cubicTo(w * 0.82, 0, w, h * 0.08, w, h * 0.36);
    path.cubicTo(w, h * 0.63, w * 0.72, h * 0.84, w * 0.5, h * 0.97);
    path.close();

    canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.28)
          ..style = PaintingStyle.fill);

    final shinePath = Path();
    shinePath.moveTo(w * 0.22, h * 0.09);
    shinePath.cubicTo(
        w * 0.12, h * 0.07, w * 0.08, h * 0.22, w * 0.18, h * 0.33);
    shinePath.cubicTo(
        w * 0.28, h * 0.43, w * 0.42, h * 0.36, w * 0.38, h * 0.2);
    shinePath.cubicTo(w * 0.36, h * 0.1, w * 0.3, h * 0.09, w * 0.22, h * 0.09);
    shinePath.close();
    canvas.drawPath(
        shinePath,
        Paint()
          ..color = Colors.white.withOpacity(0.2)
          ..style = PaintingStyle.fill);

    canvas.drawPath(
        path,
        Paint()
          ..color = isActive ? Colors.white : color.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 3.0 : 2.0);

    if (isActive) {
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }

    if (isPower) {
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.amber.withOpacity(0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    }

    final knotPath = Path();
    knotPath.moveTo(w * 0.5, h * 0.96);
    knotPath.cubicTo(w * 0.41, h * 0.91, w * 0.41, h * 0.87, w * 0.5, h * 0.85);
    knotPath.cubicTo(w * 0.59, h * 0.87, w * 0.59, h * 0.91, w * 0.5, h * 0.96);
    canvas.drawPath(
        knotPath,
        Paint()
          ..color = color.withOpacity(0.8)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant BalloonPainter old) =>
      old.color != color || old.isActive != isActive;
}

class SpikesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    final path = Path();
    int count = 14;
    double sw = size.width / count;
    path.moveTo(0, 0);
    for (int i = 0; i < count; i++) {
      double x = i * sw;
      path.lineTo(x + sw / 2, size.height);
      path.lineTo(x + sw, 0);
    }
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

import 'package:flutter/material.dart';

class KnotPainter extends CustomPainter {
  final Color color;
  KnotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.cubicTo(
      size.width * 0.2,
      size.height * 0.3,
      size.width * 0.8,
      size.height * 0.6,
      size.width / 2,
      size.height,
    );
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.15),
      4,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

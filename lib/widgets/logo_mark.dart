import 'dart:math' as math;
import 'package:flutter/material.dart';

const kGreen = Color(0xFF1B6B4F);
const kGold = Color(0xFFD9B66A);

/// App logo: Rub el Hizb (eight-pointed star) inside a double ring.
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 120});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  void _star(Canvas c, Offset o, double r, Paint p) {
    for (final rot in [0.0, 45.0]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = (rot + 45 + 90 * i) * math.pi / 180;
        final pt = Offset(o.dx + r * math.cos(a), o.dy + r * math.sin(a));
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      c.drawPath(path..close(), p);
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final o = s.center(Offset.zero);
    final u = s.width / 1024;
    final gold = Paint()..color = kGold;
    final green = Paint()..color = kGreen;
    c.drawCircle(o, 340 * u, Paint()..color = kGold..style = PaintingStyle.stroke..strokeWidth = 10 * u);
    c.drawCircle(o, 316 * u, Paint()..color = kGold..style = PaintingStyle.stroke..strokeWidth = 3 * u);
    _star(c, o, 330 * u, gold);
    _star(c, o, 270 * u, green);
    _star(c, o, 215 * u, gold);
    c.drawCircle(o, 95 * u, green);
    c.drawCircle(o, 70 * u, Paint()..color = kGold..style = PaintingStyle.stroke..strokeWidth = 8 * u);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

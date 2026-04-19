import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/theme.dart';

/// LUMA brand mark — a rounded-square tile with the aurora gradient,
/// a stylised white "L" and two sparkle accents. Rendered with a
/// [CustomPainter] so it stays sharp at any size.
class LumaLogo extends StatelessWidget {
  const LumaLogo({
    super.key,
    this.size = 64,
    this.showWordmark = false,
  });

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LumaMarkPainter()),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: size * 0.22),
        ShaderMask(
          shaderCallback: (r) => AppColors.primaryGradient.createShader(r),
          blendMode: BlendMode.srcIn,
          child: Text(
            'LUMA',
            style: TextStyle(
              fontSize: size * 0.74,
              fontWeight: FontWeight.w800,
              letterSpacing: -size * 0.02,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _LumaMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Rect.fromLTWH(0, 0, s, s);
    final radius = Radius.circular(s * 0.234);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // Aurora gradient background.
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF6366F1),
          Color(0xFF8B5CF6),
          Color(0xFFEC4899),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // Top-right soft highlight.
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.45, -0.55),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect)
      ..blendMode = BlendMode.plus;
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, highlightPaint);
    canvas.restore();

    // Draw the stylised "L" — two capsule strokes that overlap.
    // Use the same 512-unit design space as the PNG assets.
    final u = s / 512.0;
    final stroke = 64.0 * u;
    final whitePaint = Paint()..color = Colors.white;

    final vertical = RRect.fromRectAndRadius(
      Rect.fromLTWH(176 * u - stroke / 2, 128 * u - stroke / 2,
          stroke, (372 - 128) * u + stroke),
      Radius.circular(stroke / 2),
    );
    canvas.drawRRect(vertical, whitePaint);

    final horizontal = RRect.fromRectAndRadius(
      Rect.fromLTWH(176 * u - stroke / 2, 372 * u - stroke / 2,
          (360 - 176) * u + stroke, stroke),
      Radius.circular(stroke / 2),
    );
    canvas.drawRRect(horizontal, whitePaint);

    // Sparkles.
    _drawSparkle(canvas, Offset(372 * u, 148 * u), 50 * u, 13 * u);
    canvas.drawCircle(Offset(372 * u, 148 * u), 9 * u, whitePaint);
    _drawSparkle(canvas, Offset(312 * u, 88 * u), 20 * u, 5 * u);
  }

  void _drawSparkle(Canvas canvas, Offset c, double rOuter, double rInner) {
    final path = Path();
    const points = 4;
    const total = points * 2;
    for (var i = 0; i < total; i++) {
      final r = i.isEven ? rOuter : rInner;
      final a = -math.pi / 2 + i * math.pi / points;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _LumaMarkPainter oldDelegate) => false;
}

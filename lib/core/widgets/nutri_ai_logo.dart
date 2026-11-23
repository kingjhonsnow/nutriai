import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';

class NutriAILogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double fontSize;

  const NutriAILogo({
    super.key,
    this.size = 72,
    this.showText = false,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (!showText) {
      return _buildIcon();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontFamily: 'Montserrat',
            ),
            children: const [
              TextSpan(
                text: 'NUTRI',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'AI',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'INTELLIGENT NUTRITION & FITNESS',
          style: TextStyle(
            fontSize: fontSize * 0.38,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: size * 0.4,
            spreadRadius: size * 0.05,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _NutriAILogoPainter(),
      ),
    );
  }
}

class _NutriAILogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Background Rounded Shield Hexagon
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF1E2836),
          Color(0xFF111722),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF2ECC71),
          Color(0xFF00E676),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04;

    // Draw circular shield container
    canvas.drawCircle(center, w * 0.46, bgPaint);
    canvas.drawCircle(center, w * 0.46, borderPaint);

    // 2. Leaf Curve (Nutrition symbol)
    final leafPath = Path();
    leafPath.moveTo(w * 0.32, h * 0.65);
    leafPath.cubicTo(
      w * 0.18, h * 0.38,
      w * 0.45, h * 0.22,
      w * 0.68, h * 0.28,
    );
    leafPath.cubicTo(
      w * 0.76, h * 0.52,
      w * 0.52, h * 0.72,
      w * 0.32, h * 0.65,
    );
    leafPath.close();

    final leafPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF27AE60),
          Color(0xFF2ECC71),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(leafPath, leafPaint);

    // 3. Lightning / Energy Spark (Fitness & AI symbol)
    final boltPath = Path();
    boltPath.moveTo(w * 0.56, h * 0.26);
    boltPath.lineTo(w * 0.40, h * 0.52);
    boltPath.lineTo(w * 0.52, h * 0.52);
    boltPath.lineTo(w * 0.44, h * 0.76);
    boltPath.lineTo(w * 0.64, h * 0.46);
    boltPath.lineTo(w * 0.52, h * 0.46);
    boltPath.close();

    final boltPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.white,
          Color(0xFF00E676),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(boltPath, boltPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pointer_app/core/theme/app_text_styles.dart';
import 'package:pointer_app/core/theme/compass_painter_theme.dart';

class CompassPainter extends CustomPainter {
  CompassPainter({
    required this.theme,
    required this.angle,
    required this.distanceMeters,
    required this.targetName,
    required this.offlineFactor,
    required this.offlineColor,
  });

  final CompassTheme theme;
  final double angle;
  final double distanceMeters;
  final String targetName;
  final double offlineFactor;
  final Color offlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.85 * 0.5;

    final dialPaint = Paint()
      ..color = theme.dialColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, dialPaint);

    final tickPaint = Paint()
      ..color = theme.tickColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (var deg = 0; deg < 360; deg += 10) {
      final isMajor = deg % 30 == 0;
      final tickLen = isMajor ? radius * 0.08 : radius * 0.04;
      tickPaint.strokeWidth = isMajor ? 2 : 1;

      final a = (deg - 90) * math.pi / 180.0;
      final dir = Offset(math.cos(a), math.sin(a));
      final p2 = center + dir * radius;
      final p1 = center + dir * (radius - tickLen);
      canvas.drawLine(p1, p2, tickPaint);
    }

    _paintCardinals(canvas, center, radius);
    _paintNeedle(canvas, center, radius);
    _paintTexts(canvas, center, radius);
  }

  void _paintCardinals(Canvas canvas, Offset center, double radius) {
    final distance = radius * 0.78;
    final styleBase = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.0,
    );

    void paintLetter(String text, Offset pos, Color color) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: styleBase.copyWith(color: color),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    final nColor = Color.lerp(
      theme.centerDotColor,
      offlineColor,
      offlineFactor,
    )!;
    final otherColor = Color.lerp(
      theme.tickColor,
      offlineColor,
      offlineFactor,
    )!;

    paintLetter('N', center + Offset(0, -distance), nColor);
    paintLetter('S', center + Offset(0, distance), otherColor);
    paintLetter('E', center + Offset(distance, 0), otherColor);
    paintLetter('W', center + Offset(-distance, 0), otherColor);
  }

  void _paintNeedle(Canvas canvas, Offset center, double radius) {
    final angleRad = angle * math.pi / 180.0;

    final topH = radius * 0.55;
    final tailH = radius * 0.20;
    final topW = radius * 0.055;
    final tailW = radius * 0.075;

    final topColor = Color.lerp(
      theme.needleColor,
      offlineColor,
      offlineFactor,
    )!;
    final tailColor = Color.lerp(theme.tickColor, offlineColor, offlineFactor)!;
    final dotColor = Color.lerp(
      theme.centerDotColor,
      offlineColor,
      offlineFactor,
    )!;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angleRad);

    final topPath = Path()
      ..moveTo(0, -topH)
      ..lineTo(-topW, 0)
      ..lineTo(topW, 0)
      ..close();
    canvas.drawPath(
      topPath,
      Paint()
        ..color = topColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    final tailPath = Path()
      ..moveTo(0, tailH)
      ..lineTo(-tailW, 0)
      ..lineTo(tailW, 0)
      ..close();
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = tailColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    canvas.restore();

    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  void _paintTexts(Canvas canvas, Offset center, double radius) {
    final distanceText = _formatDistance(distanceMeters);

    final distanceStyle = AppTextStyles.displayDistance.copyWith(
      color: Color.lerp(theme.needleColor, offlineColor, offlineFactor),
    );

    final nameStyle = AppTextStyles.bodySecondary.copyWith(
      color: Color.lerp(theme.tickColor, offlineColor, offlineFactor),
    );

    final distanceTp = TextPainter(
      text: TextSpan(text: distanceText, style: distanceStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final nameTp = TextPainter(
      text: TextSpan(text: targetName, style: nameStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: radius * 1.6);

    final distanceOffset = center + Offset(0, radius * 0.35);
    final distanceTopLeft =
        distanceOffset - Offset(distanceTp.width / 2, distanceTp.height / 2);
    distanceTp.paint(canvas, distanceTopLeft);

    final nameOffset = Offset(
      center.dx - nameTp.width / 2,
      distanceTopLeft.dy - 6 - nameTp.height,
    );
    nameTp.paint(canvas, nameOffset);
  }

  static String _formatDistance(double meters) {
    if (!meters.isFinite) return '--';
    if (meters < 1000) return '${meters.round()}m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(2)} km';
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.distanceMeters != distanceMeters ||
        oldDelegate.offlineFactor != offlineFactor ||
        oldDelegate.targetName != targetName;
  }
}

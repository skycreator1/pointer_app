import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pointer_app/core/theme/compass_painter_theme.dart';

class CompassDialPainter extends CustomPainter {
  CompassDialPainter({required CompassTheme theme})
    : _dialPaint = Paint()
        ..color = theme.dialColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
      _tickPaint = Paint()
        ..color = theme.tickColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
      _nTextPainter = TextPainter(
        text: TextSpan(
          text: 'N',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.0,
            color: theme.centerDotColor,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      ),
      _sTextPainter = TextPainter(
        text: TextSpan(
          text: 'S',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.0,
            color: theme.tickColor,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      ),
      _eTextPainter = TextPainter(
        text: TextSpan(
          text: 'E',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.0,
            color: theme.tickColor,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      ),
      _wTextPainter = TextPainter(
        text: TextSpan(
          text: 'W',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.0,
            color: theme.tickColor,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

  final Paint _dialPaint;
  final Paint _tickPaint;
  final TextPainter _nTextPainter;
  final TextPainter _sTextPainter;
  final TextPainter _eTextPainter;
  final TextPainter _wTextPainter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.85 * 0.5;

    canvas.drawCircle(center, radius, _dialPaint);

    for (var deg = 0; deg < 360; deg += 10) {
      final isMajor = deg % 30 == 0;
      final tickLen = isMajor ? radius * 0.08 : radius * 0.04;
      _tickPaint.strokeWidth = isMajor ? 2 : 1;

      final a = (deg - 90) * math.pi / 180.0;
      final dir = Offset(math.cos(a), math.sin(a));
      final p2 = center + dir * radius;
      final p1 = center + dir * (radius - tickLen);
      canvas.drawLine(p1, p2, _tickPaint);
    }

    final distance = radius * 0.78;
    _nTextPainter.layout();
    _sTextPainter.layout();
    _eTextPainter.layout();
    _wTextPainter.layout();

    _nTextPainter.paint(
      canvas,
      center +
          Offset(0, -distance) -
          Offset(_nTextPainter.width / 2, _nTextPainter.height / 2),
    );
    _sTextPainter.paint(
      canvas,
      center +
          Offset(0, distance) -
          Offset(_sTextPainter.width / 2, _sTextPainter.height / 2),
    );
    _eTextPainter.paint(
      canvas,
      center +
          Offset(distance, 0) -
          Offset(_eTextPainter.width / 2, _eTextPainter.height / 2),
    );
    _wTextPainter.paint(
      canvas,
      center +
          Offset(-distance, 0) -
          Offset(_wTextPainter.width / 2, _wTextPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CompassNeedlePainter extends CustomPainter {
  CompassNeedlePainter({
    required this.theme,
    required this.angle,
    required this.offlineFactor,
    required this.offlineColor,
  }) : _needlePaint = Paint()
         ..style = PaintingStyle.fill
         ..isAntiAlias = true,
       _tailPaint = Paint()
         ..style = PaintingStyle.fill
         ..isAntiAlias = true,
       _dotPaint = Paint()
         ..style = PaintingStyle.fill
         ..isAntiAlias = true;

  final CompassTheme theme;
  final double angle;
  final double offlineFactor;
  final Color offlineColor;

  final Paint _needlePaint;
  final Paint _tailPaint;
  final Paint _dotPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.85 * 0.5;
    final angleRad = angle * math.pi / 180.0;

    final topH = radius * 0.55;
    final tailH = radius * 0.20;
    final topW = radius * 0.055;
    final tailW = radius * 0.075;

    _needlePaint.color = Color.lerp(
      theme.needleColor,
      offlineColor,
      offlineFactor,
    )!;
    _tailPaint.color = Color.lerp(
      theme.tickColor,
      offlineColor,
      offlineFactor,
    )!;
    _dotPaint.color = Color.lerp(
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
    canvas.drawPath(topPath, _needlePaint);

    final tailPath = Path()
      ..moveTo(0, tailH)
      ..lineTo(-tailW, 0)
      ..lineTo(tailW, 0)
      ..close();
    canvas.drawPath(tailPath, _tailPaint);

    canvas.restore();

    canvas.drawCircle(center, 6, _dotPaint);
  }

  @override
  bool shouldRepaint(covariant CompassNeedlePainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.offlineFactor != offlineFactor ||
        oldDelegate.offlineColor != offlineColor ||
        oldDelegate.theme != theme;
  }
}

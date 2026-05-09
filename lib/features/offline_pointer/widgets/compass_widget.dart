import 'package:flutter/material.dart';
import 'package:pointer_app/core/theme/app_colors.dart';
import 'package:pointer_app/core/theme/compass_painter_theme.dart';
import 'package:pointer_app/features/offline_pointer/widgets/compass_painter.dart';

class CompassWidget extends StatefulWidget {
  const CompassWidget({
    super.key,
    required this.angle,
    required this.dialRotation,
    required this.isOnline,
    this.theme,
    this.showOverlay = true,
    this.showTopIndicator = true,
  });

  final double angle;
  final double dialRotation;
  final bool isOnline;
  final CompassTheme? theme;
  final bool showOverlay;
  final bool showTopIndicator;

  @override
  State<CompassWidget> createState() => _CompassWidgetState();
}

class _CompassWidgetState extends State<CompassWidget> {
  double _frozenAngle = 0;
  double _latestAngle = 0;
  double _frozenDialRotation = 0;
  double _latestDialRotation = 0;

  @override
  void didUpdateWidget(covariant CompassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline && !widget.isOnline) {
      _frozenAngle = _latestAngle;
      _frozenDialRotation = _latestDialRotation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final theme =
        widget.theme ??
        (brightness == Brightness.dark
            ? CompassTheme.dark()
            : CompassTheme.light());
    final offlineColor = brightness == Brightness.dark
        ? AppColorsDark.offline
        : AppColorsLight.offline;

    final targetAngle = widget.isOnline ? widget.angle : _frozenAngle;
    final endAngle = _shortestEndAngle(from: _latestAngle, to: targetAngle);

    final targetDialRotation = widget.isOnline
        ? widget.dialRotation
        : _frozenDialRotation;
    final endDialRotation =
        _shortestEndAngle(from: _latestDialRotation, to: targetDialRotation);

    final duration = widget.isOnline
        ? const Duration(milliseconds: 420)
        : const Duration(milliseconds: 220);

    return Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: endDialRotation),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final normalized = _normalizeDegrees(value);
            _latestDialRotation = normalized;
            return Transform.rotate(
              angle: -normalized * 3.141592653589793 / 180.0,
              child: child,
            );
          },
          child: RepaintBoundary(
            child: CustomPaint(
              painter: CompassDialPainter(theme: theme),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: endAngle),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final normalized = _normalizeDegrees(value);
            _latestAngle = normalized;
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: widget.isOnline ? 0.0 : 1.0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, offlineFactor, _) {
                return RepaintBoundary(
                  child: CustomPaint(
                    painter: CompassNeedlePainter(
                      theme: theme,
                      angle: normalized,
                      offlineFactor: offlineFactor,
                      offlineColor: offlineColor,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            );
          },
        ),
        if (widget.showOverlay)
          IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.15, -0.4),
                  radius: 1.1,
                  colors: [
                    Color(0x22FFFFFF),
                    Color(0x0AFFFFFF),
                    Color(0x00111111),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        if (widget.showTopIndicator)
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: SizedBox(
                width: 18,
                height: 26,
                child: CustomPaint(painter: _TopIndicatorPainter()),
              ),
            ),
          ),
      ],
    );
  }

  static double _shortestEndAngle({required double from, required double to}) {
    final a = _normalizeDegrees(from);
    final b = _normalizeDegrees(to);
    var delta = (b - a) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return a + delta;
  }

  static double _normalizeDegrees(double degrees) {
    if (!degrees.isFinite) return 0;
    final normalized = degrees % 360;
    if (normalized < 0) return normalized + 360;
    return normalized;
  }
}

class _TopIndicatorPainter extends CustomPainter {
  const _TopIndicatorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final linePaint = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(
      Offset(centerX, 4),
      Offset(centerX, size.height - 10),
      linePaint,
    );

    final tri = Path()
      ..moveTo(centerX, size.height)
      ..lineTo(centerX - 5, size.height - 10)
      ..lineTo(centerX + 5, size.height - 10)
      ..close();
    final triPaint = Paint()
      ..color = const Color(0xFFE11D48)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(tri, triPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

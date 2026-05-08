import 'package:flutter/material.dart';
import 'package:pointer_app/core/theme/app_colors.dart';
import 'package:pointer_app/core/theme/compass_painter_theme.dart';
import 'package:pointer_app/features/offline_pointer/widgets/compass_painter.dart';

class CompassWidget extends StatefulWidget {
  const CompassWidget({
    super.key,
    required this.angle,
    required this.distanceMeters,
    required this.targetName,
    required this.isOnline,
    this.theme,
  });

  final double angle;
  final double distanceMeters;
  final String targetName;
  final bool isOnline;
  final CompassTheme? theme;

  @override
  State<CompassWidget> createState() => _CompassWidgetState();
}

class _CompassWidgetState extends State<CompassWidget> {
  double _frozenAngle = 0;
  double _latestAngle = 0;

  @override
  void didUpdateWidget(covariant CompassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline && !widget.isOnline) {
      _frozenAngle = _latestAngle;
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

    final duration = widget.isOnline
        ? const Duration(milliseconds: 420)
        : const Duration(milliseconds: 220);

    return TweenAnimationBuilder<double>(
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
            return CustomPaint(
              painter: CompassPainter(
                theme: theme,
                angle: normalized,
                distanceMeters: widget.distanceMeters,
                targetName: widget.targetName,
                offlineFactor: offlineFactor,
                offlineColor: offlineColor,
              ),
            );
          },
        );
      },
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

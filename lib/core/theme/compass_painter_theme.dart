import 'package:flutter/material.dart';
import 'package:pointer_app/core/theme/app_colors.dart';

final class CompassTheme {
  const CompassTheme({
    required this.dialColor,
    required this.needleColor,
    required this.tickColor,
    required this.centerDotColor,
  });

  final Color dialColor;
  final Color needleColor;
  final Color tickColor;
  final Color centerDotColor;

  factory CompassTheme.dark() {
    return const CompassTheme(
      dialColor: AppColorsDark.surface,
      needleColor: AppColorsDark.primary,
      tickColor: AppColorsDark.textSecondary,
      centerDotColor: AppColorsDark.accent,
    );
  }

  factory CompassTheme.light() {
    return const CompassTheme(
      dialColor: AppColorsLight.surface,
      needleColor: AppColorsLight.primary,
      tickColor: AppColorsLight.textSecondary,
      centerDotColor: AppColorsLight.accent,
    );
  }
}

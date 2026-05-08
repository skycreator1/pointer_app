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
      needleColor: AppColorsDark.accent,
      tickColor: AppColorsDark.textSecondary,
      centerDotColor: AppColorsDark.primary,
    );
  }

  factory CompassTheme.light() {
    return const CompassTheme(
      dialColor: AppColorsLight.surface,
      needleColor: AppColorsLight.accent,
      tickColor: AppColorsLight.textSecondary,
      centerDotColor: AppColorsLight.primary,
    );
  }
}


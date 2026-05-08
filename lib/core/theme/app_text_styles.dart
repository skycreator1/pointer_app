import 'package:flutter/material.dart';

final class AppTextStyles {
  const AppTextStyles._();

  static final displayDistance = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w200,
    fontFeatures: const [FontFeature.tabularFigures()],
    height: 1.0,
  );

  static const compassLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.2,
    height: 1.0,
  );

  static const inviteCode = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    fontFamily: 'monospace',
    height: 1.0,
  );

  static const bodyPrimary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
}

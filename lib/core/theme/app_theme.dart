import 'package:flutter/material.dart';
import 'package:pointer_app/core/theme/app_colors.dart';
import 'package:pointer_app/core/theme/app_text_styles.dart';

final class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => _buildLight();
  static ThemeData get darkTheme => _buildDark();

  static ThemeData _buildLight() {
    final scheme = ColorScheme.light(
      primary: AppColorsLight.primary,
      onPrimary: AppColorsLight.background,
      secondary: AppColorsLight.accent,
      onSecondary: AppColorsLight.background,
      error: AppColorsLight.accent,
      onError: AppColorsLight.background,
      surface: AppColorsLight.surface,
      onSurface: AppColorsLight.textPrimary,
    ).copyWith(outline: AppColorsLight.border);

    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColorsLight.background,
      dividerColor: AppColorsLight.border,
      textTheme: _textTheme(
        textPrimary: AppColorsLight.textPrimary,
        textSecondary: AppColorsLight.textSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsLight.background,
        foregroundColor: AppColorsLight.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColorsLight.surface,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  static ThemeData _buildDark() {
    final scheme = ColorScheme.dark(
      primary: AppColorsDark.primary,
      onPrimary: AppColorsDark.background,
      secondary: AppColorsDark.accent,
      onSecondary: AppColorsDark.background,
      error: AppColorsDark.accent,
      onError: AppColorsDark.background,
      surface: AppColorsDark.surface,
      onSurface: AppColorsDark.textPrimary,
    ).copyWith(outline: AppColorsDark.border);

    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColorsDark.background,
      dividerColor: AppColorsDark.border,
      textTheme: _textTheme(
        textPrimary: AppColorsDark.textPrimary,
        textSecondary: AppColorsDark.textSecondary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsDark.background,
        foregroundColor: AppColorsDark.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColorsDark.surface,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  static TextTheme _textTheme({
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return TextTheme(
      bodyLarge: AppTextStyles.bodyPrimary.copyWith(color: textPrimary),
      bodyMedium: AppTextStyles.bodyPrimary.copyWith(color: textPrimary),
      bodySmall: AppTextStyles.bodySecondary.copyWith(color: textSecondary),
      titleMedium: AppTextStyles.bodyPrimary.copyWith(color: textPrimary),
      titleSmall: AppTextStyles.bodySecondary.copyWith(color: textSecondary),
      labelLarge: AppTextStyles.bodyPrimary.copyWith(color: textPrimary),
      labelMedium: AppTextStyles.bodySecondary.copyWith(color: textPrimary),
      labelSmall: AppTextStyles.caption.copyWith(color: textSecondary),
    );
  }
}

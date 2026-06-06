import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

abstract final class AppTheme {
  static const _fontFamily = 'Involve';
  static const _package = 'clean_disk_design_system';

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryPurple,
      brightness: Brightness.light,
    ).copyWith(surface: Colors.white, outlineVariant: AppColors.lavenderBorder);

    return _build(
      colorScheme: colorScheme,
    ).copyWith(scaffoldBackgroundColor: AppColors.pageBackground);
  }

  static ThemeData dark() {
    const surface = Color(0xFF080D1B);
    const surfaceContainer = Color(0xFF10172A);
    const outline = Color(0xFF24304A);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.actionBlue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF22E7F2),
          onPrimary: const Color(0xFF031216),
          secondary: const Color(0xFF8B5CF6),
          onSecondary: Colors.white,
          surface: surface,
          surfaceContainerHighest: surfaceContainer,
          outline: outline,
          outlineVariant: outline,
          error: const Color(0xFFFF5C8A),
        );

    return _build(
      colorScheme: colorScheme,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFF050914));
  }

  static ThemeData _build({required ColorScheme colorScheme}) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      package: _package,
      colorScheme: colorScheme,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}

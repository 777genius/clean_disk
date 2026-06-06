import 'package:flutter/material.dart';
import 'package:headless/headless.dart';

import '../tokens/app_colors.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isExpanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final style = _AppButtonStyle.resolve(
      colorScheme: Theme.of(context).colorScheme,
      variant: variant,
      enabled: enabled,
    );

    final child = Theme(
      data: _withButtonStyle(Theme.of(context), style),
      child: RTextButton(
        onPressed: onPressed,
        variant: _toHeadlessVariant(variant),
        size: RButtonSize.large,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );

    if (!isExpanded) {
      return child;
    }

    return SizedBox(width: double.infinity, child: child);
  }

  RButtonVariant _toHeadlessVariant(AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => RButtonVariant.filled,
      AppButtonVariant.secondary => RButtonVariant.tonal,
      AppButtonVariant.ghost => RButtonVariant.text,
    };
  }

  ThemeData _withButtonStyle(ThemeData theme, _AppButtonStyle style) {
    final buttonStyle = ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(style.foregroundColor),
      backgroundColor: WidgetStatePropertyAll(style.backgroundColor),
      side: WidgetStatePropertyAll(BorderSide(color: style.borderColor)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
    );
  }
}

final class _AppButtonStyle {
  const _AppButtonStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  static _AppButtonStyle resolve({
    required ColorScheme colorScheme,
    required AppButtonVariant variant,
    required bool enabled,
  }) {
    if (!enabled) {
      return const _AppButtonStyle(
        backgroundColor: Color(0xFFE2DEE8),
        foregroundColor: AppColors.textSoft,
        borderColor: Colors.transparent,
      );
    }

    return switch (variant) {
      AppButtonVariant.primary => _AppButtonStyle(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        borderColor: Colors.transparent,
      ),
      AppButtonVariant.secondary => _AppButtonStyle(
        backgroundColor: AppColors.lavenderSurface,
        foregroundColor: colorScheme.primary,
        borderColor: Colors.transparent,
      ),
      AppButtonVariant.ghost => _AppButtonStyle(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.primary,
        borderColor: Colors.transparent,
      ),
    };
  }
}

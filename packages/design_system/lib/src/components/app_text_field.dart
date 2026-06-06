import 'package:flutter/material.dart';
import 'package:headless/headless.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.minLines,
    this.maxLines = 1,
    this.height,
    this.focusNode,
    this.textStyle,
    this.placeholderColor,
    this.prefixIcon,
    this.prefixIconSize = 24,
    this.prefixIconColor,
    this.containerPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? minLines;
  final int? maxLines;
  final double? height;
  final FocusNode? focusNode;
  final TextStyle? textStyle;
  final Color? placeholderColor;
  final IconData? prefixIcon;
  final double prefixIconSize;
  final Color? prefixIconColor;
  final EdgeInsetsGeometry containerPadding;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(8);
    final effectiveHeight = height ?? 52;
    final effectiveTextStyle =
        textStyle ?? theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    final effectivePlaceholderColor =
        placeholderColor ?? colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    final effectiveIconColor = prefixIconColor ?? colorScheme.onSurfaceVariant;
    final iconSlotWidth = prefixIcon == null ? 0.0 : prefixIconSize + 24;
    final baseBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: errorText == null
            ? colorScheme.outlineVariant
            : colorScheme.error,
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: errorText == null ? colorScheme.primary : colorScheme.error,
        width: 1.4,
      ),
    );

    final field = RTextField(
      controller: controller,
      label: label,
      placeholder: placeholder,
      errorText: errorText,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      clearButtonMode: RTextFieldOverlayVisibilityMode.whileEditing,
      variant: RTextFieldVariant.outlined,
      overrides: RenderOverrides({
        MaterialTextFieldOverrides: MaterialTextFieldOverrides(
          filled: false,
          contentPadding: containerPadding,
          border: baseBorder,
          enabledBorder: baseBorder,
          focusedBorder: focusedBorder,
          errorBorder: baseBorder.copyWith(
            borderSide: BorderSide(color: colorScheme.error),
          ),
          focusedErrorBorder: focusedBorder.copyWith(
            borderSide: BorderSide(color: colorScheme.error, width: 1.4),
          ),
        ),
      }),
      slots: prefixIcon == null
          ? null
          : RTextFieldSlots(
              leading: SizedBox(
                width: iconSlotWidth,
                height: effectiveHeight,
                child: Center(
                  child: Icon(
                    prefixIcon,
                    size: prefixIconSize,
                    color: effectiveIconColor,
                  ),
                ),
              ),
            ),
      style: RTextFieldStyle(
        containerRadius: 8,
        containerBorderColor: errorText == null
            ? colorScheme.outlineVariant
            : colorScheme.error,
        containerBorderWidth: 1,
        containerBackgroundColor: colorScheme.surface,
        containerPadding: containerPadding,
        textStyle: effectiveTextStyle,
        placeholderColor: effectivePlaceholderColor,
        minSize: Size.fromHeight(effectiveHeight),
      ),
    );

    final themedField = Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: false,
          isDense: true,
          hintStyle: effectiveTextStyle.copyWith(
            color: effectivePlaceholderColor,
          ),
          prefixIconColor: effectiveIconColor,
          prefixIconConstraints: prefixIcon == null
              ? null
              : BoxConstraints(
                  minWidth: iconSlotWidth,
                  minHeight: effectiveHeight,
                ),
          suffixIconConstraints: BoxConstraints(
            minWidth: effectiveHeight,
            minHeight: effectiveHeight,
          ),
        ),
      ),
      child: field,
    );

    if (height == null) {
      return themedField;
    }

    return SizedBox(height: height, child: themedField);
  }
}

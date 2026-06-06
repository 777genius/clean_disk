import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppSelectionPill extends StatelessWidget {
  const AppSelectionPill({
    super.key,
    required this.label,
    this.isSelected = false,
    this.height = 36,
    this.horizontalPadding = 18,
    this.borderRadius = 22,
    this.textStyle,
    this.selectedGradient,
  });

  final String label;
  final bool isSelected;
  final double height;
  final double horizontalPadding;
  final double borderRadius;
  final TextStyle? textStyle;
  final Gradient? selectedGradient;

  @override
  Widget build(BuildContext context) {
    final baseTextStyle = textStyle ?? Theme.of(context).textTheme.labelLarge;

    if (isSelected) {
      return Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient:
              selectedGradient ??
              const LinearGradient(
                colors: [Color(0xFFB79BFF), AppColors.primaryPurple],
              ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: baseTextStyle?.copyWith(color: Colors.white, letterSpacing: 0),
        ),
      );
    }

    return Align(
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseTextStyle?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

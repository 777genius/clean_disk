import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppGradientButton extends StatelessWidget {
  const AppGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 44,
    this.minWidth = 120,
    this.borderRadius = 22,
    this.isExpanded = true,
    this.textStyle,
    this.gradientColors,
    this.disabledGradientColors,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double minWidth;
  final double borderRadius;
  final bool isExpanded;
  final TextStyle? textStyle;
  final List<Color>? gradientColors;
  final List<Color>? disabledGradientColors;

  @override
  Widget build(BuildContext context) {
    final button = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                colors: onPressed == null
                    ? disabledGradientColors ??
                          const [Color(0xFFD8D5DD), Color(0xFFD8D5DD)]
                    : gradientColors ??
                          const [
                            AppColors.actionBlueLight,
                            AppColors.actionBlue,
                          ],
              ),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style:
                      textStyle ??
                      Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!isExpanded) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

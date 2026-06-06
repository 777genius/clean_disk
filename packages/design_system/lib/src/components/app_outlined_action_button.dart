import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppOutlinedActionButton extends StatelessWidget {
  const AppOutlinedActionButton({
    super.key,
    required this.onPressed,
    this.width,
    this.height,
    this.minSize,
    this.padding,
    this.foregroundColor = AppColors.primaryPurple,
    this.borderColor,
    this.borderRadius = 22,
    this.alignment = Alignment.center,
    this.textStyle,
    required this.child,
  });

  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final Size? minSize;
  final EdgeInsetsGeometry? padding;
  final Color foregroundColor;
  final Color? borderColor;
  final double borderRadius;
  final AlignmentGeometry alignment;
  final TextStyle? textStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: alignment,
        minimumSize: minSize,
        padding: padding,
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor ?? foregroundColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        textStyle: textStyle,
      ),
      child: child,
    );

    if (width == null && height == null) {
      return button;
    }

    return SizedBox(width: width, height: height, child: button);
  }
}

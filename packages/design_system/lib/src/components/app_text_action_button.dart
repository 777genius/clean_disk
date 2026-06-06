import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppTextActionButton extends StatelessWidget {
  const AppTextActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconSize = 18,
    this.foregroundColor = AppColors.primaryPurple,
    this.padding = EdgeInsets.zero,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double iconSize;
  final Color foregroundColor;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: foregroundColor,
      padding: padding,
      textStyle: textStyle,
    );

    if (icon == null) {
      return TextButton(onPressed: onPressed, style: style, child: Text(label));
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      label: Text(label),
      style: style,
    );
  }
}

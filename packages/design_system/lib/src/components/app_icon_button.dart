import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.ink,
    this.size = 24,
    this.padding,
    this.alignment = Alignment.center,
    this.visualDensity = VisualDensity.compact,
    this.constraints,
  }) : child = null;

  const AppIconButton.custom({
    super.key,
    required this.child,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.ink,
    this.size = 24,
    this.padding,
    this.alignment = Alignment.center,
    this.visualDensity = VisualDensity.compact,
    this.constraints,
  }) : icon = null;

  final IconData? icon;
  final Widget? child;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;
  final VisualDensity? visualDensity;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: child ?? Icon(icon, color: color, size: size),
      onPressed: onPressed,
      color: color,
      padding: padding,
      alignment: alignment,
      visualDensity: visualDensity,
      constraints: constraints,
    );
  }
}

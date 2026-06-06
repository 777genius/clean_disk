import 'package:flutter/material.dart';

class AppTapSurface extends StatelessWidget {
  const AppTapSurface({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.customBorder,
    this.shape,
    this.color = Colors.transparent,
    this.clipBehavior = Clip.none,
    this.semanticButton,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final ShapeBorder? shape;
  final Color color;
  final Clip clipBehavior;
  final bool? semanticButton;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget surface = Material(
      color: color,
      shape: shape ?? customBorder,
      borderRadius: shape == null && customBorder == null ? borderRadius : null,
      clipBehavior: clipBehavior,
      child: InkWell(
        onTap: onTap,
        borderRadius: customBorder == null ? borderRadius : null,
        customBorder: customBorder,
        child: child,
      ),
    );

    if (semanticButton != null || semanticLabel != null) {
      surface = Semantics(
        button: semanticButton ?? onTap != null,
        enabled: onTap != null,
        label: semanticLabel,
        child: surface,
      );
    }

    return surface;
  }
}

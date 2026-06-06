import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppSkeletonBlock extends StatelessWidget {
  const AppSkeletonBlock({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 10,
    this.color = AppColors.lavenderSurfaceMuted,
    this.borderColor,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
    );
  }
}

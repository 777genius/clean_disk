import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color = AppColors.primaryPurple,
    this.backgroundColor,
    this.displacement = 40,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final Color color;
  final Color? backgroundColor;
  final double displacement;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: color,
      backgroundColor: backgroundColor,
      displacement: displacement,
      onRefresh: onRefresh,
      child: child,
    );
  }
}

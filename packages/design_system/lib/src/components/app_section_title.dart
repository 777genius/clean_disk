import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(
    this.text, {
    this.color = AppColors.ink,
    this.fontSize = 24,
    this.height = 1.08,
    super.key,
  });

  final String text;
  final Color color;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: color,
        fontSize: fontSize,
        height: height,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

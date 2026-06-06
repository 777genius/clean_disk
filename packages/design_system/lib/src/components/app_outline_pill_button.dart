import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppOutlinePillButton extends StatelessWidget {
  const AppOutlinePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 36,
    this.minWidth = 120,
    this.foregroundColor = AppColors.primaryPurple,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double minWidth;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(minWidth, height),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          foregroundColor: foregroundColor,
          side: BorderSide(color: foregroundColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        child: icon == null
            ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

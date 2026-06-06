import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

class AppUnavailableStatePanel extends StatelessWidget {
  const AppUnavailableStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lavenderBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryPurple, size: 46),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
                height: 1.3,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

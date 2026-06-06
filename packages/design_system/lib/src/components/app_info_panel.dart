import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import 'app_gradient_button.dart';

class AppInfoPanel extends StatelessWidget {
  const AppInfoPanel({
    super.key,
    this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.borderRadius,
    this.titleFontWeight,
    this.titleTextGap,
    this.actionTopGap,
    this.actionHeight,
    this.actionBorderRadius,
    this.isActionExpanded,
    this.iconTileSize = 42,
    this.iconGap = 14,
  });

  final IconData? icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double? borderRadius;
  final FontWeight? titleFontWeight;
  final double? titleTextGap;
  final double? actionTopGap;
  final double? actionHeight;
  final double? actionBorderRadius;
  final bool? isActionExpanded;
  final double iconTileSize;
  final double iconGap;

  @override
  Widget build(BuildContext context) {
    final hasIcon = icon != null;
    final content = hasIcon
        ? _buildIconContent(context)
        : _buildTextContent(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lavenderSurfaceMuted,
        borderRadius: BorderRadius.circular(
          borderRadius ?? (hasIcon ? 14 : 10),
        ),
        border: Border.all(color: AppColors.lavenderBorder),
      ),
      child: content,
    );
  }

  Widget _buildIconContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppInfoPanelIconTile(icon: icon!, size: iconTileSize),
        SizedBox(width: iconGap),
        Expanded(child: _buildTextContent(context)),
      ],
    );
  }

  Widget _buildTextContent(BuildContext context) {
    final hasIcon = icon != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.ink,
            fontWeight:
                titleFontWeight ??
                (hasIcon ? FontWeight.w700 : FontWeight.w800),
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: titleTextGap ?? (hasIcon ? 5 : 6)),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            height: 1.3,
            letterSpacing: 0,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(
            height: actionTopGap ?? (hasIcon ? AppSpacing.sm : AppSpacing.md),
          ),
          AppGradientButton(
            label: actionLabel!,
            onPressed: onAction,
            height: actionHeight ?? (hasIcon ? 38 : 40),
            borderRadius: actionBorderRadius ?? (hasIcon ? 20 : 22),
            isExpanded: isActionExpanded ?? !hasIcon,
          ),
        ],
      ],
    );
  }
}

class _AppInfoPanelIconTile extends StatelessWidget {
  const _AppInfoPanelIconTile({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.lavenderSurfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppColors.primaryPurple, size: size * 0.62),
    );
  }
}

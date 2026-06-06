import 'package:flutter/material.dart';

import 'app_icon_button.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.topGap = 54,
    this.backIcon = Icons.arrow_back_ios_new_rounded,
    this.backColor = Colors.black26,
    this.backTooltip = 'Назад',
    this.titleColor = const Color(0xFF2B2B2F),
    this.titleFontSize = 40,
  });

  final String title;
  final VoidCallback? onBack;
  final double topGap;
  final IconData backIcon;
  final Color backColor;
  final String backTooltip;
  final Color titleColor;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconButton(
          onPressed: onBack,
          icon: backIcon,
          color: backColor,
          tooltip: backTooltip,
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
        SizedBox(height: topGap),
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: titleColor,
            fontSize: titleFontSize,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

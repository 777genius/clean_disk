import 'package:flutter/material.dart';

class AppBottomSheetOverlay extends StatelessWidget {
  const AppBottomSheetOverlay({
    super.key,
    required this.child,
    this.maxWidth = 430,
    this.horizontalPadding = 18,
    this.topPadding = 18,
    this.bottomPadding = 22,
    this.topRadius = 28,
    this.barrierColor,
    this.surfaceColor = Colors.white,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double topRadius;
  final Color? barrierColor;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: barrierColor ?? Colors.black.withValues(alpha: 0.34),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(topRadius),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    MediaQuery.viewInsetsOf(context).bottom + bottomPadding,
                  ),
                  child: SingleChildScrollView(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

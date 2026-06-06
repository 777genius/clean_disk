import 'package:flutter/material.dart';

class AppInlineFailure extends StatelessWidget {
  const AppInlineFailure({
    super.key,
    required this.message,
    this.backgroundColor = const Color(0xFFFFF4F4),
    this.foregroundColor = const Color(0xFFC0392B),
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: foregroundColor,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

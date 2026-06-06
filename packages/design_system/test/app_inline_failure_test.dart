import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders inline failure with app colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppInlineFailure(message: 'Something went wrong'),
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AppInlineFailure),
        matching: find.byType(DecoratedBox),
      ),
    );
    final text = tester.widget<Text>(find.text('Something went wrong'));
    final decoration = decoratedBox.decoration as BoxDecoration;

    expect(decoration.color, const Color(0xFFFFF4F4));
    expect(decoration.borderRadius, BorderRadius.circular(10));
    expect(text.style?.color, const Color(0xFFC0392B));
    expect(text.style?.letterSpacing, 0);
  });
}

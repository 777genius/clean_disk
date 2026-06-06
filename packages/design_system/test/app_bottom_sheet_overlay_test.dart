import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders app bottom sheet overlay with shared defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [AppBottomSheetOverlay(child: Text('Sheet content'))],
          ),
        ),
      ),
    );

    expect(find.text('Sheet content'), findsOneWidget);
    expect(find.byType(Positioned), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    final constrainedBox = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(AppBottomSheetOverlay),
        matching: find.byType(ConstrainedBox),
      ),
    );
    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AppBottomSheetOverlay),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;

    expect(constrainedBox.constraints.maxWidth, 430);
    expect(decoration.color, Colors.white);
    expect(
      decoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );
  });

  testWidgets('allows sheet padding customization', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AppBottomSheetOverlay(
                horizontalPadding: 12,
                topPadding: 10,
                bottomPadding: 30,
                child: Text('Sheet content'),
              ),
            ],
          ),
        ),
      ),
    );

    final sheetPadding = find.descendant(
      of: find.byType(AppBottomSheetOverlay),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.fromLTRB(12, 10, 12, 30),
      ),
    );

    expect(sheetPadding, findsOneWidget);
  });
}

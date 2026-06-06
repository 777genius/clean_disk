import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders selected pill with app gradient', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppSelectionPill(label: 'Рекомендуемые', isSelected: true),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Рекомендуемые'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.gradient, isA<LinearGradient>());
    expect(find.text('Рекомендуемые'), findsOneWidget);
  });

  testWidgets('renders plain pill as centered text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AppSelectionPill(label: 'Маникюр')),
      ),
    );

    final text = tester.widget<Text>(find.text('Маникюр'));
    final align = tester.widget<Align>(
      find.ancestor(of: find.text('Маникюр'), matching: find.byType(Align)),
    );

    expect(align.alignment, Alignment.center);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}

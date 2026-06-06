import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders label and reports selected value', (tester) async {
    var selected = 'male';
    final theme = AppTheme.light();

    await tester.pumpWidget(
      AppHeadlessScope(
        theme: theme,
        appBuilder: (overlayBuilder) => MaterialApp(
          theme: theme,
          builder: overlayBuilder,
          home: Scaffold(
            body: AppSelectField<String>(
              label: 'Пол',
              value: selected,
              values: const ['male', 'female'],
              itemLabel: (value) => switch (value) {
                'male' => 'Мужской',
                'female' => 'Женский',
                _ => value,
              },
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Пол'), findsOneWidget);
    expect(find.text('Мужской'), findsOneWidget);

    await tester.tap(find.text('Мужской'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Женский').last);
    await tester.pumpAndSettle();

    expect(selected, 'female');
  });
}

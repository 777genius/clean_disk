import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders unavailable state panel with shared app styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppUnavailableStatePanel(
            icon: Icons.favorite_border_rounded,
            title: 'Избранное пока недоступно',
            message: 'Синхронизация избранного появится позже.',
          ),
        ),
      ),
    );

    expect(find.text('Избранное пока недоступно'), findsOneWidget);
    expect(
      find.text('Синхронизация избранного появится позже.'),
      findsOneWidget,
    );

    final icon = tester.widget<Icon>(
      find.byIcon(Icons.favorite_border_rounded),
    );
    expect(icon.color, AppColors.primaryPurple);
    expect(icon.size, 46);

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AppUnavailableStatePanel),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(decoration.border, Border.all(color: AppColors.lavenderBorder));

    final panelPadding = find.descendant(
      of: find.byType(AppUnavailableStatePanel),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.fromLTRB(22, 26, 22, 28),
      ),
    );
    expect(panelPadding, findsOneWidget);
  });
}

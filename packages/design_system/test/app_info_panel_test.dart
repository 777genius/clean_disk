import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders text info panel with shared defaults', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppInfoPanel(
            title: 'Запись пока недоступна',
            text: 'У этой компании пока нет услуг для онлайн-записи.',
          ),
        ),
      ),
    );

    expect(find.text('Запись пока недоступна'), findsOneWidget);
    expect(
      find.text('У этой компании пока нет услуг для онлайн-записи.'),
      findsOneWidget,
    );

    final panel = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppInfoPanel),
        matching: find.byType(Container).first,
      ),
    );
    final decoration = panel.decoration as BoxDecoration;

    expect(decoration.color, AppColors.lavenderSurfaceMuted);
    expect(decoration.borderRadius, BorderRadius.circular(10));
    expect(decoration.border, Border.all(color: AppColors.lavenderBorder));
  });

  testWidgets('renders icon info panel with compact action', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppInfoPanel(
            icon: Icons.wifi_off,
            title: 'Не удалось обновить данные',
            text: 'Проверьте подключение.',
            actionLabel: 'Повторить',
            onAction: () {
              tapCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    final panel = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppInfoPanel),
        matching: find.byType(Container).first,
      ),
    );
    final decoration = panel.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(14));

    final button = tester.widget<AppGradientButton>(
      find.byType(AppGradientButton),
    );
    expect(button.height, 38);
    expect(button.borderRadius, 20);
    expect(button.isExpanded, isFalse);

    await tester.tap(find.text('Повторить'));
    expect(tapCount, 1);
  });
}

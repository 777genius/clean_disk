import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders icon and custom child variants', (tester) async {
    var iconPressedCount = 0;
    var customPressedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            children: [
              AppIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Закрыть',
                onPressed: () => iconPressedCount += 1,
                color: AppColors.textMuted,
                size: 32,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              AppIconButton.custom(
                tooltip: 'Загрузка',
                onPressed: () => customPressedCount += 1,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('Закрыть'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byTooltip('Закрыть'));
    await tester.tap(find.byTooltip('Загрузка'));

    expect(iconPressedCount, 1);
    expect(customPressedCount, 1);
  });
}

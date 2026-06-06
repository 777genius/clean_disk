import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app button can move from disabled to enabled', (tester) async {
    var enabled = false;
    var pressedCount = 0;
    late StateSetter setInnerState;

    await tester.pumpWidget(
      _designSystemTestApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setInnerState = setState;

              return AppButton(
                label: 'Продолжить',
                onPressed: enabled ? () => pressedCount += 1 : null,
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    expect(pressedCount, 0);

    setInnerState(() {
      enabled = true;
    });
    await tester.pump();

    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    expect(pressedCount, 1);
  });

  testWidgets('renders text action button variants', (tester) async {
    var plainPressedCount = 0;
    var iconPressedCount = 0;

    await tester.pumpWidget(
      _designSystemTestApp(
        Scaffold(
          body: Row(
            children: [
              AppTextActionButton(
                label: 'Изменить',
                onPressed: () => plainPressedCount += 1,
              ),
              AppTextActionButton(
                label: 'Повторить',
                icon: Icons.edit_outlined,
                onPressed: () => iconPressedCount += 1,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Изменить'));
    await tester.tap(find.text('Повторить'));

    expect(plainPressedCount, 1);
    expect(iconPressedCount, 1);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('renders outlined action button with custom child', (
    tester,
  ) async {
    var pressedCount = 0;

    await tester.pumpWidget(
      _designSystemTestApp(
        Scaffold(
          body: AppOutlinedActionButton(
            onPressed: () => pressedCount += 1,
            width: 54,
            height: 40,
            padding: EdgeInsets.zero,
            child: const Icon(Icons.calendar_today_outlined),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));

    expect(pressedCount, 1);
  });
}

Widget _designSystemTestApp(Widget home) {
  final theme = AppTheme.light();

  return AppHeadlessScope(
    theme: theme,
    appBuilder: (overlayBuilder) =>
        MaterialApp(theme: theme, builder: overlayBuilder, home: home),
  );
}

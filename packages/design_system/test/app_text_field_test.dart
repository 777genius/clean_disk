import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders prefix icon and reports text changes', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changedValue = '';
    final theme = AppTheme.light();

    await tester.pumpWidget(
      AppHeadlessScope(
        theme: theme,
        appBuilder: (overlayBuilder) {
          return MaterialApp(
            theme: theme,
            builder: overlayBuilder,
            home: Scaffold(
              body: AppTextField(
                controller: controller,
                placeholder: 'Адрес',
                prefixIcon: Icons.search_rounded,
                height: 66,
                onChanged: (value) => changedValue = value,
              ),
            ),
          );
        },
      ),
    );

    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.text('Адрес'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Москва');

    expect(changedValue, 'Москва');
    expect(controller.text, 'Москва');
  });

  testWidgets('keeps compact single-line field vertically centered', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final theme = AppTheme.dark();

    await tester.pumpWidget(
      AppHeadlessScope(
        theme: theme,
        appBuilder: (overlayBuilder) {
          return MaterialApp(
            theme: theme,
            builder: overlayBuilder,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: const ValueKey('compact-field-frame'),
                  width: 320,
                  height: 36,
                  child: AppTextField(
                    controller: controller,
                    placeholder: 'Поиск файлов и папок...',
                    height: 36,
                    prefixIcon: Icons.search_rounded,
                    prefixIconSize: 18,
                    textStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.2,
                    ),
                    containerPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    final frameRect = tester.getRect(
      find.byKey(const ValueKey('compact-field-frame')),
    );
    final editableRect = tester.getRect(find.byType(EditableText));
    final iconRect = tester.getRect(find.byIcon(Icons.search_rounded));
    final hintRect = tester.getRect(find.text('Поиск файлов и папок...'));

    expect(editableRect.height, greaterThanOrEqualTo(16));
    expect(
      (editableRect.center.dy - frameRect.center.dy).abs(),
      lessThanOrEqualTo(3),
    );
    expect(
      (iconRect.center.dy - frameRect.center.dy).abs(),
      lessThanOrEqualTo(2),
    );
    expect(
      (hintRect.center.dy - frameRect.center.dy).abs(),
      lessThanOrEqualTo(3),
    );
    expect(hintRect.left, greaterThan(iconRect.right));
  });
}

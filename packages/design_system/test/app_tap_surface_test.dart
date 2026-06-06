import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wraps tap surfaces with app Material defaults', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppTapSurface(
              color: AppColors.lavenderSurface,
              borderRadius: BorderRadius.circular(8),
              semanticLabel: 'Open company',
              onTap: () {
                tapCount += 1;
              },
              child: const SizedBox(
                width: 120,
                height: 48,
                child: Center(child: Text('Open')),
              ),
            ),
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppTapSurface),
        matching: find.byType(Material),
      ),
    );
    final inkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(AppTapSurface),
        matching: find.byType(InkWell),
      ),
    );

    expect(material.color, AppColors.lavenderSurface);
    expect(material.borderRadius, BorderRadius.circular(8));
    expect(inkWell.borderRadius, BorderRadius.circular(8));
    final semanticLabel = find.descendant(
      of: find.byType(AppTapSurface),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Open company',
      ),
    );

    expect(semanticLabel, findsOneWidget);

    await tester.tap(find.text('Open'));
    expect(tapCount, 1);
  });

  testWidgets('supports custom shape hit areas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppTapSurface(
            color: Colors.white,
            customBorder: CircleBorder(),
            child: SizedBox(width: 36, height: 36),
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppTapSurface),
        matching: find.byType(Material),
      ),
    );
    final inkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(AppTapSurface),
        matching: find.byType(InkWell),
      ),
    );

    expect(material.shape, isA<CircleBorder>());
    expect(material.borderRadius, isNull);
    expect(inkWell.customBorder, isA<CircleBorder>());
  });
}

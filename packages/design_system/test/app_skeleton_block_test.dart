import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders skeleton block with shared app defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppSkeletonBlock(width: 120, height: 48)),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;

    expect(container.constraints?.maxWidth, 120);
    expect(container.constraints?.maxHeight, 48);
    expect(decoration.color, AppColors.lavenderSurfaceMuted);
    expect(decoration.borderRadius, BorderRadius.circular(10));
    expect(decoration.border, isNull);
  });

  testWidgets('supports card-style skeleton border and radius', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppSkeletonBlock(
            width: 166,
            borderRadius: 14,
            borderColor: AppColors.lavenderBorder,
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;

    expect(container.constraints?.maxWidth, 166);
    expect(decoration.borderRadius, BorderRadius.circular(14));
    expect(decoration.border, Border.all(color: AppColors.lavenderBorder));
  });
}

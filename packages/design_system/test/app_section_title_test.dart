import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders section title with shared defaults', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AppSectionTitle('Отзывы')),
      ),
    );

    final text = tester.widget<Text>(find.text('Отзывы'));
    expect(text.style?.color, AppColors.ink);
    expect(text.style?.fontSize, 24);
    expect(text.style?.height, 1.08);
    expect(text.style?.fontWeight, FontWeight.w800);
    expect(text.style?.letterSpacing, 0);
  });

  testWidgets('supports exact visual overrides', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppSectionTitle(
            'Услуги',
            color: Color(0xFF303030),
            fontSize: 30,
            height: 1.05,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Услуги'));
    expect(text.style?.color, const Color(0xFF303030));
    expect(text.style?.fontSize, 30);
    expect(text.style?.height, 1.05);
  });
}

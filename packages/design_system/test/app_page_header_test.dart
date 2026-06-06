import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders app page title and back action', (tester) async {
    var backCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppPageHeader(title: 'Профиль', onBack: () => backCount += 1),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));

    final text = tester.widget<Text>(find.text('Профиль'));

    expect(backCount, 1);
    expect(text.style?.fontSize, 40);
    expect(text.style?.fontWeight, FontWeight.w800);
    expect(text.style?.letterSpacing, 0);
  });
}

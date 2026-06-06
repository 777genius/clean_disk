import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wraps pull to refresh behavior with app defaults', (
    tester,
  ) async {
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppRefreshIndicator(
            onRefresh: () async {
              refreshCount += 1;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 600, child: Text('Content'))],
            ),
          ),
        ),
      ),
    );

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );

    expect(indicator.color, AppColors.primaryPurple);
    expect(find.text('Content'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshCount, 1);
  });
}

import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = AppTreeTableStyle(
    backgroundColor: Color(0xFF0A1020),
    headerColor: Color(0xFF10172B),
    borderColor: Color(0xFF263148),
    rowBorderColor: Color(0xFF263148),
    selectedRowColor: Color(0xFF14265E),
    textColor: Color(0xFFDCE6FF),
    selectedTextColor: Colors.white,
    mutedTextColor: Color(0xFF93A0BF),
    iconColor: Color(0xFF3B82F6),
    progressTrackColor: Color(0xFF20283D),
    progressColor: Color(0xFF3B82F6),
    selectedProgressColor: Color(0xFF22E7F2),
  );
  const columns = AppTreeTableColumnLabels(
    name: 'Name',
    size: 'Size',
    percent: '%',
    items: 'Items',
  );

  testWidgets('renders tree rows and reports row taps', (tester) async {
    String? selectedId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 220,
            child: AppTreeTable(
              columns: columns,
              rows: const [
                AppTreeTableRow(
                  id: '1',
                  name: 'Caches',
                  sizeText: '38.7 GB',
                  percentText: '57.0%',
                  itemsText: '24',
                  progress: 0.57,
                  depth: 1,
                  selected: true,
                  hasChildren: true,
                  expanded: false,
                  icon: Icons.folder_outlined,
                ),
              ],
              emptyState: const Text('Empty'),
              style: style,
              onRowTap: (row) {
                selectedId = row.id;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Caches'), findsOneWidget);
    expect(find.text('38.7 GB'), findsOneWidget);

    await tester.tap(find.text('Caches'));
    expect(selectedId, '1');
  });

  testWidgets('can hide header for empty first-run states', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SizedBox(
            width: 720,
            height: 220,
            child: AppTreeTable(
              columns: columns,
              rows: [],
              emptyState: Text('Empty'),
              style: style,
              showHeader: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Name'), findsNothing);
    expect(find.text('Size'), findsNothing);
    expect(find.text('Empty'), findsOneWidget);
  });

  testWidgets('keeps 50k-row table virtualized by visible viewport', (
    tester,
  ) async {
    final rows = List<AppTreeTableRow>.generate(50000, (index) {
      return AppTreeTableRow(
        id: '$index',
        name: 'Folder $index',
        sizeText: '${index + 1} GB',
        percentText: '1%',
        itemsText: '$index',
        progress: 0.01,
        depth: index % 4,
        selected: index == 0,
        hasChildren: true,
        expanded: false,
        icon: Icons.folder_outlined,
      );
    }, growable: false);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 260,
            child: AppTreeTable(
              columns: columns,
              rows: rows,
              emptyState: const Text('Empty'),
              style: style,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Folder 0'), findsOneWidget);
    expect(find.text('Folder 49999'), findsNothing);
  });

  testWidgets('moves focus with keyboard and activates focused row', (
    tester,
  ) async {
    String? selectedId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 220,
            child: AppTreeTable(
              columns: columns,
              rows: const [
                AppTreeTableRow(
                  id: '1',
                  name: 'Users',
                  sizeText: '120 GB',
                  percentText: '80%',
                  itemsText: '120',
                  progress: 0.8,
                  depth: 0,
                  selected: true,
                  hasChildren: true,
                  expanded: true,
                  icon: Icons.folder_outlined,
                ),
                AppTreeTableRow(
                  id: '2',
                  name: 'Library',
                  sizeText: '38 GB',
                  percentText: '25%',
                  itemsText: '24',
                  progress: 0.25,
                  depth: 1,
                  selected: false,
                  hasChildren: true,
                  expanded: false,
                  icon: Icons.folder_outlined,
                ),
              ],
              emptyState: const Text('Empty'),
              style: style,
              onRowTap: (row) {
                selectedId = row.id;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Users'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(selectedId, '2');
  });

  testWidgets('toggles expansion separately from row selection', (
    tester,
  ) async {
    String? selectedId;
    String? toggledId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 220,
            child: AppTreeTable(
              columns: columns,
              rows: const [
                AppTreeTableRow(
                  id: '1',
                  name: 'Users',
                  sizeText: '120 GB',
                  percentText: '80%',
                  itemsText: '120',
                  progress: 0.8,
                  depth: 0,
                  selected: true,
                  hasChildren: true,
                  expanded: false,
                  icon: Icons.folder_outlined,
                ),
              ],
              emptyState: const Text('Empty'),
              style: style,
              onRowTap: (row) {
                selectedId = row.id;
              },
              onRowToggleExpansion: (row) {
                toggledId = row.id;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('app-tree-table-toggle-1')));
    await tester.pump();

    expect(toggledId, '1');
    expect(selectedId, isNull);

    await tester.tap(find.text('Users'));
    expect(selectedId, '1');
  });

  testWidgets('reports row context menu requests', (tester) async {
    String? contextRowId;
    Offset? contextPosition;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 220,
            child: AppTreeTable(
              columns: columns,
              rows: const [
                AppTreeTableRow(
                  id: '1',
                  name: 'Users',
                  sizeText: '120 GB',
                  percentText: '80%',
                  itemsText: '120',
                  progress: 0.8,
                  depth: 0,
                  selected: true,
                  hasChildren: true,
                  expanded: false,
                  icon: Icons.folder_outlined,
                ),
              ],
              emptyState: const Text('Empty'),
              style: style,
              onRowContextMenu: (row, position) {
                contextRowId = row.id;
                contextPosition = position;
              },
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.text('Users'));
    await tester.tapAt(center, buttons: kSecondaryMouseButton);

    expect(contextRowId, '1');
    expect(contextPosition, isNotNull);
  });

  testWidgets('expands focused tree row with keyboard', (tester) async {
    String? toggledId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 220,
            child: AppTreeTable(
              columns: columns,
              rows: const [
                AppTreeTableRow(
                  id: '1',
                  name: 'Users',
                  sizeText: '120 GB',
                  percentText: '80%',
                  itemsText: '120',
                  progress: 0.8,
                  depth: 0,
                  selected: true,
                  hasChildren: true,
                  expanded: false,
                  icon: Icons.folder_outlined,
                ),
              ],
              emptyState: const Text('Empty'),
              style: style,
              onRowToggleExpansion: (row) {
                toggledId = row.id;
              },
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

    expect(toggledId, '1');
  });
}

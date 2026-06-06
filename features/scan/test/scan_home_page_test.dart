import 'dart:async';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:clean_disk_localization/clean_disk_localization.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:clean_disk_scan/clean_disk_scan_data.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders scan workspace shell and fake scan data', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    expect(find.text('Clean Disk'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('scan-toolbar-scan-action')),
      findsOneWidget,
    );
    expect(find.text('No scan data yet'), findsOneWidget);
    expect(find.text('Permission Proof'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Probe pending'), findsNothing);
    expect(find.text('Unverified'), findsNothing);
    expect(find.text('Current process'), findsNothing);
    expect(find.textContaining('Development build'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('permission-proof-compact')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('permission-proof-compact')))
          .height,
      lessThanOrEqualTo(96),
    );
    expect(
      find.byKey(const ValueKey('permission-warning-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('permission-warning-prominent')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('permission-proof-neutral')),
      findsNothing,
    );
    expect(
      find.textContaining(
        'Access is verified. Full Disk Access may differ in a signed build.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Reduced dev package - verify signed build'),
      findsNothing,
    );
    expect(find.text('Dev shell / Unsigned'), findsNothing);
    expect(find.text('Not checked'), findsNothing);

    await tester.tap(find.byTooltip('Re-check'));
    await tester.pumpAndSettle();
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Not checked'), findsNothing);

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.text('Scan again'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-tree-table-row-8')), findsOneWidget);
    expect(find.text('196.7 GB - 1 items'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Modified'), findsOneWidget);
    expect(find.text('Accounting'), findsOneWidget);
    expect(find.text('Confidence'), findsOneWidget);
    expect(find.text('Flags'), findsOneWidget);
  });

  testWidgets('unknown permission proof stays neutral before probe', (
    tester,
  ) async {
    final fixture = FakeScanFeatureFixture();
    fixture.repository.capabilities = fixture.repository.capabilities.copyWith(
      runtimeProof: RuntimeProof.unknown,
    );
    fixture.repository.permissionProbe = const PermissionProbe(
      status: PermissionProbeStatus.unknown,
      checkedAtUnixMs: null,
      requiredAction: PermissionRequiredAction.unknown,
    );

    await _pumpScanHome(tester, size: const Size(1440, 900), fixture: fixture);

    expect(
      find.byKey(const ValueKey('permission-proof-neutral')),
      findsOneWidget,
    );
    expect(find.text('Access not verified'), findsNothing);
    expect(
      find.byKey(const ValueKey('permission-warning-compact')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('permission-warning-prominent')),
      findsNothing,
    );
    expect(find.text('Access checks before scanning.'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('permission-proof-neutral')))
          .height,
      lessThanOrEqualTo(34),
    );
    expect(find.byTooltip('Re-check'), findsNothing);
    expect(find.text('Development build'), findsNothing);
    expect(find.text('Not checked'), findsNothing);
  });

  testWidgets('compact layout fits narrow desktop width', (tester) async {
    await _pumpScanHome(tester, size: const Size(430, 900));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('scan-footer')), findsNothing);
    expect(find.byKey(const ValueKey('scan-footer-hidden')), findsOneWidget);
    expect(find.text('Select a row'), findsNothing);
    expect(find.text('Folder'), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('scan-target-chip-current')))
          .width,
      greaterThanOrEqualTo(380),
    );
    final compactScanButton = tester.widget<IconButton>(
      find
          .descendant(
            of: find.byKey(const ValueKey('scan-toolbar-scan-action')),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(compactScanButton.color, const Color(0xFF011216));
    expect(
      compactScanButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF22E7F2),
    );
    expect(
      find.byKey(const ValueKey('scan-empty-scan-action')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Scan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('scan-footer')), findsNothing);
    expect(find.byKey(const ValueKey('scan-footer-hidden')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('details-reveal-action')), findsOneWidget);
  });

  testWidgets(
    'wide running footer stays dense while keeping progress and stats',
    (tester) async {
      final fixture = FakeScanFeatureFixture(
        repository: FakeScanRepository()..deferStartCompletion = true,
      );
      final result = await _pumpScanHome(
        tester,
        fixture: fixture,
        size: const Size(1440, 900),
      );
      await result.store.start(_scanCommand());
      await tester.pump();
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const ValueKey('scan-footer'))).height,
        lessThanOrEqualTo(58),
      );
      expect(
        find.byKey(const ValueKey('scan-footer-progress')),
        findsOneWidget,
      );
      expect(find.text('Files Scanned'), findsOneWidget);
      expect(find.text('Elapsed'), findsOneWidget);
      expect(find.text('Throughput'), findsOneWidget);
    },
  );

  testWidgets('running footer progress is determinate and monotonic', (
    tester,
  ) async {
    final fixture = FakeScanFeatureFixture(
      repository: FakeScanRepository()..deferStartCompletion = true,
    );
    final result = await _pumpScanHome(
      tester,
      fixture: fixture,
      size: const Size(1440, 900),
    );
    await result.store.start(_scanCommand());
    await tester.pump();

    expect(result.store.sessionStatus?.state, SessionState.running);
    await tester.pump();
    await tester.pump();

    final progressAtStart = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('scan-footer-progress')),
    );
    expect(progressAtStart.value, isNotNull);
    expect(progressAtStart.value, greaterThanOrEqualTo(0));
    expect(
      find.byKey(const ValueKey('scan-footer-running-indicator')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));
    final progressLater = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('scan-footer-progress')),
    );
    expect(progressLater.value, isNotNull);
    expect(progressLater.value, greaterThan(progressAtStart.value!));
    expect(progressLater.value, lessThan(1));

    result.fixture.eventClient.add(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('2'),
        emittedAtUnixMs: BigInt.from(1700000000002),
        event: ScanSnapshotPublished(
          sessionId: FakeScanRepository.sessionId,
          snapshotId: FakeScanRepository.snapshotId,
        ),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('metric strip stays hidden until scan data is useful', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    expect(find.text('TOTAL SCANNED'), findsNothing);
    expect(find.text('LARGEST FOLDER'), findsNothing);
    expect(find.text('REVIEW LIST'), findsNothing);
    expect(find.text('SKIPPED'), findsNothing);
    expect(find.byKey(const ValueKey('scan-drive-summary')), findsNothing);
    expect(find.text('0 B'), findsNothing);

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL SCANNED'), findsOneWidget);
    expect(find.text('LARGEST FOLDER'), findsOneWidget);
    expect(find.text('REVIEW LIST'), findsOneWidget);
    expect(find.text('SKIPPED'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-drive-summary')), findsOneWidget);
  });

  testWidgets('wide empty table avoids duplicate scan action', (tester) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    expect(find.byKey(const ValueKey('scan-footer')), findsNothing);
    expect(find.byKey(const ValueKey('scan-footer-hidden')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-empty-scan-action')), findsNothing);
    expect(find.text('Name'), findsNothing);
    expect(find.text('Size'), findsNothing);

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Size'), findsWidgets);
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-footer')), findsNothing);
    expect(find.byKey(const ValueKey('scan-footer-hidden')), findsOneWidget);
  });

  testWidgets('wide empty state stays compact and above visual center', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    final tableRect = tester.getRect(find.byType(AppTreeTable));
    final contentFinder = find.byKey(
      const ValueKey('scan-empty-state-content'),
    );
    final contentRect = tester.getRect(contentFinder);

    expect(contentFinder, findsOneWidget);
    expect(contentRect.width, lessThanOrEqualTo(520));
    expect(contentRect.height, lessThanOrEqualTo(140));
    expect(contentRect.center.dy, lessThan(tableRect.center.dy));
    expect(
      contentRect.center.dy,
      lessThan(tableRect.top + tableRect.height * 0.44),
    );
  });

  testWidgets('wide target rail leaves room for the tree workspace', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    final railSize = tester.getSize(
      find.byKey(const ValueKey('scan-target-rail')),
    );
    final tableRect = tester.getRect(find.byType(AppTreeTable));

    expect(railSize.width, lessThanOrEqualTo(300));
    expect(tableRect.width, greaterThanOrEqualTo(900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide toolbar gives search enough room on common desktop width', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1272, 900));
    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    final searchSize = tester.getSize(
      find.byKey(const ValueKey('scan-search-field')),
    );

    expect(searchSize.width, greaterThanOrEqualTo(260));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide toolbar groups scan action with target', (tester) async {
    await _pumpScanHome(tester, size: const Size(1272, 900));

    final targetRect = tester.getRect(
      find.byKey(const ValueKey('scan-target-breadcrumb')),
    );
    final scanRect = tester.getRect(
      find.byKey(const ValueKey('scan-toolbar-scan-action')),
    );
    final scanLabel = tester.widget<Text>(find.text('Scan'));

    expect(scanRect.left - targetRect.right, lessThanOrEqualTo(24));
    expect(scanRect.right, lessThan(720));
    expect(scanLabel.style?.fontWeight, FontWeight.w800);
    expect(scanLabel.style?.color, const Color(0xFF011216));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout hides empty details pane before first scan', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    expect(find.text('Select a row'), findsNothing);
    expect(
      find.byKey(const ValueKey('details-pane-collapse-action')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('details-pane-collapsed-rail')),
      findsNothing,
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('details-pane-collapse-action')),
      findsOneWidget,
    );
  });

  testWidgets('search appears only after scan data is available', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1272, 900));

    expect(find.byKey(const ValueKey('scan-search-field')), findsNothing);
    expect(find.text('Search after scan'), findsNothing);
    expect(find.text('Search files and folders...'), findsNothing);
    expect(
      find.byKey(const ValueKey('scan-toolbar-sort-action')),
      findsNothing,
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('scan-search-field')), findsOneWidget);
    expect(find.text('Search files and folders...'), findsOneWidget);
    expect(find.text('Search after scan'), findsNothing);
    expect(
      find.byKey(const ValueKey('scan-toolbar-sort-action')),
      findsOneWidget,
    );
  });

  testWidgets('sort menu changes the tree query explicitly', (tester) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('scan-toolbar-sort-action')));
    await tester.pumpAndSettle();

    expect(find.text('Largest first'), findsOneWidget);
    expect(find.text('Smallest first'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan-sort-option-sizeAsc')));
    await tester.pumpAndSettle();

    expect(result.store.viewport.sort, ChildSort.sizeAsc);
    expect(result.store.visibleRows.first.name, 'System');
  });

  testWidgets('permission repair shows guidance before opening settings', (
    tester,
  ) async {
    final fixture = FakeScanFeatureFixture();
    fixture.repository.capabilities = fixture.repository.capabilities.copyWith(
      runtimeProof: fixture.repository.capabilities.runtimeProof.copyWith(
        permissionProbe: const PermissionProbe(
          status: PermissionProbeStatus.denied,
          checkedAtUnixMs: null,
          requiredAction: PermissionRequiredAction.openMacosFullDiskAccess,
        ),
      ),
    );
    fixture.repository.permissionProbe = const PermissionProbe(
      status: PermissionProbeStatus.denied,
      checkedAtUnixMs: null,
      requiredAction: PermissionRequiredAction.openMacosFullDiskAccess,
    );
    final launcher = _RecordingPermissionRepairLauncher(
      onLaunch: () {
        fixture.repository.permissionProbe = PermissionProbe(
          status: PermissionProbeStatus.verified,
          checkedAtUnixMs: BigInt.from(1700000000001),
          requiredAction: PermissionRequiredAction.none,
        );
      },
    );

    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      config: const ScanWorkspaceConfig(
        defaultTargetPath: '/tmp/clean-disk-fixture',
        defaultTargetScope: TargetScope.localPath,
      ),
      fixture: fixture,
      permissionRepairLauncher: launcher,
    );

    expect(find.text('Current process'), findsOneWidget);
    expect(find.text('Guide Full Disk Access, then re-check'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('permission-warning-prominent')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('permission-warning-compact')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('permission-proof-neutral')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('permission-repair-action')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('permission-repair-dialog')),
      findsOneWidget,
    );
    expect(
      find.text('Open Privacy & Security > Full Disk Access.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Enable Clean Disk, or clean-disk-server if macOS lists the bundled helper.',
      ),
      findsOneWidget,
    );
    expect(launcher.targets, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('permission-repair-open-settings-action')),
    );
    await tester.pumpAndSettle();

    expect(launcher.targets.single.path.value, '/tmp/clean-disk-fixture');
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets(
    'permission repair does not verify access without re-probe proof',
    (tester) async {
      final fixture = FakeScanFeatureFixture();
      const deniedProbe = PermissionProbe(
        status: PermissionProbeStatus.denied,
        checkedAtUnixMs: null,
        requiredAction: PermissionRequiredAction.openMacosFullDiskAccess,
      );
      fixture.repository.capabilities = fixture.repository.capabilities
          .copyWith(
            runtimeProof: fixture.repository.capabilities.runtimeProof.copyWith(
              permissionProbe: deniedProbe,
            ),
          );
      fixture.repository.permissionProbe = deniedProbe;
      final launcher = _RecordingPermissionRepairLauncher();

      await _pumpScanHome(
        tester,
        size: const Size(1440, 900),
        config: const ScanWorkspaceConfig(
          defaultTargetPath: '/tmp/clean-disk-fixture',
          defaultTargetScope: TargetScope.localPath,
        ),
        fixture: fixture,
        permissionRepairLauncher: launcher,
      );

      await tester.tap(find.byKey(const ValueKey('permission-repair-action')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('permission-repair-open-settings-action')),
      );
      await tester.pumpAndSettle();

      expect(launcher.targets.single.path.value, '/tmp/clean-disk-fixture');
      expect(find.text('Denied'), findsOneWidget);
      expect(find.text('Verified'), findsNothing);
    },
  );

  testWidgets('search field queries paged scan results', (tester) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    final searchField = find.byKey(const ValueKey('scan-search-field'));
    final editable = find.descendant(
      of: searchField,
      matching: find.byType(EditableText),
    );
    await tester.enterText(editable, 'app');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(result.fixture.repository.searchQueries.single.searchText, 'app');
    expect(find.byKey(const ValueKey('app-tree-table-row-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-tree-table-row-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsNothing);
    expect(find.text('Search results for "app"'), findsOneWidget);

    await tester.enterText(editable, '  app   ');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(result.fixture.repository.searchQueries, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('scan-query-clear-action')));
    await tester.pumpAndSettle();

    final editableAfterClear = tester.widget<EditableText>(editable);
    expect(editableAfterClear.controller.text, isEmpty);
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsOneWidget);
    expect(find.text('Search results for "app"'), findsNothing);
  });

  testWidgets('keyboard shortcut focuses search after scan data is ready', (
    tester,
  ) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    final searchField = find.byKey(const ValueKey('scan-search-field'));
    final editable = find.descendant(
      of: searchField,
      matching: find.byType(EditableText),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);

    tester.testTextInput.enterText('app');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(result.fixture.repository.searchQueries.single.searchText, 'app');
    expect(find.text('Search results for "app"'), findsOneWidget);
  });

  testWidgets('tree disclosure loads nested folders without selecting row', (
    tester,
  ) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.text('332.8 GB'), findsWidgets);
    expect(find.byKey(const ValueKey('app-tree-table-row-3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app-tree-table-toggle-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-tree-table-row-3')), findsOneWidget);
    expect(result.store.selectedNodeId, NodeId('2'));
    expect(find.text('332.8 GB'), findsWidgets);
    expect(find.text('508.0 GB'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app-tree-table-toggle-3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-tree-table-row-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-tree-table-row-7')), findsOneWidget);
    expect(result.store.selectedNodeId, NodeId('2'));
  });

  testWidgets('fake scan publishes a fresh snapshot when run again', (
    tester,
  ) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    final firstSessionId = result.store.sessionId;
    final firstSnapshotId = result.store.activeSnapshotId;
    expect(firstSessionId, FakeScanRepository.sessionId);
    expect(firstSnapshotId, FakeScanRepository.snapshotId);
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsOneWidget);

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(result.store.sessionId, isNot(firstSessionId));
    expect(result.store.activeSnapshotId, isNot(firstSnapshotId));
    expect(result.store.sessionId, ScanSessionId('2'));
    expect(result.store.activeSnapshotId, SnapshotId('101'));
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsOneWidget);
  });

  testWidgets('configured home target starts tree at target children', (
    tester,
  ) async {
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      config: const ScanWorkspaceConfig(
        defaultTargetPath: '/Users/belief',
        defaultTargetScope: TargetScope.localPath,
      ),
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsNothing);
    expect(find.byKey(const ValueKey('app-tree-table-row-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-tree-table-row-7')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-tree-table-row-4')),
        matching: find.text('Library'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-tree-table-row-7')),
        matching: find.text('Downloads'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('/Users/belief/Library'), findsOneWidget);
  });

  testWidgets('folder row tap selects and toggles expansion', (tester) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-tree-table-row-3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-2')));
    await tester.pumpAndSettle();

    expect(result.store.selectedNodeId, NodeId('2'));
    expect(find.byKey(const ValueKey('app-tree-table-row-3')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-2')));
    await tester.pumpAndSettle();

    expect(result.store.selectedNodeId, NodeId('2'));
    expect(find.byKey(const ValueKey('app-tree-table-row-3')), findsNothing);
  });

  testWidgets('folder context menu refresh scans selected folder target', (
    tester,
  ) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    final usersRow = find.byKey(const ValueKey('app-tree-table-row-2'));
    await tester.tapAt(
      tester.getCenter(usersRow),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('node-context-refresh-folder-action')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('node-context-refresh-folder-action')),
    );
    await tester.pumpAndSettle();

    expect(
      result.fixture.repository.lastStartCommand?.targets.single.path.value,
      '/Users',
    );
    expect(find.byKey(const ValueKey('app-tree-table-row-3')), findsOneWidget);
  });

  testWidgets('sample folders with size expose lazy nested children', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-4')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-5')));
    await tester.pumpAndSettle();

    expect(find.text('Browser Cache'), findsOneWidget);
    expect(find.text('User Cache'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-6')));
    await tester.pumpAndSettle();

    expect(find.text('Xcode'), findsOneWidget);
    expect(find.text('Simulator'), findsOneWidget);
  });

  testWidgets('details pane uses file icon for selected files', (tester) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();
    await _selectNestedCrashLog(tester);

    expect(result.store.selectedNodeId, NodeId('11'));
    final detailsIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('details-kind-icon')),
    );
    expect(detailsIcon.icon, Icons.insert_drive_file_outlined);
    expect(find.text('File'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
  });

  testWidgets('details reveal is disabled for shortened display paths', (
    tester,
  ) async {
    final fixture = FakeScanFeatureFixture();
    fixture.repository.renameNodeForTesting(
      NodeId('11'),
      'CrashReporter...log',
    );
    final revealer = _RecordingPathRevealer();
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      fixture: fixture,
      pathRevealer: revealer,
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();
    await _selectNestedCrashLog(tester);

    expect(
      find.byKey(const ValueKey('details-reveal-unavailable-hint')),
      findsOneWidget,
    );
    final revealButton = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('details-reveal-action')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(revealButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('details-reveal-action')));
    await tester.pumpAndSettle();

    expect(revealer.paths, isEmpty);
    expect(find.textContaining('Path does not exist'), findsNothing);
  });

  testWidgets('target picker changes the next scan command target', (
    tester,
  ) async {
    final picker = _RecordingScanTargetPicker(ScanTargetPath('/Users/belief'));
    final result = await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      targetPicker: picker,
    );

    await tester.tap(find.byKey(const ValueKey('scan-target-picker-action')));
    await tester.pumpAndSettle();
    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(picker.initialPaths.single.value, '/');
    expect(
      result.fixture.repository.lastStartCommand?.targets.single.path.value,
      '/Users/belief',
    );
    expect(
      result.fixture.repository.lastStartCommand?.targets.single.scope,
      TargetScope.localPath,
    );
  });

  testWidgets('wide target row has a full-width change target action', (
    tester,
  ) async {
    final picker = _RecordingScanTargetPicker(ScanTargetPath('/Users/belief'));
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      targetPicker: picker,
    );

    await tester.tap(find.byKey(const ValueKey('scan-target-breadcrumb')));
    await tester.pumpAndSettle();

    expect(picker.initialPaths, isEmpty);

    expect(find.byTooltip('Change folder'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('scan-target-picker-action')),
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('Folder'), findsNothing);
    final targetRect = tester.getRect(
      find.byKey(const ValueKey('scan-target-current')),
    );
    final targetSize = tester.getSize(
      find.byKey(const ValueKey('scan-target-current')),
    );
    final targetCard = tester.widget<Container>(
      find.byKey(const ValueKey('scan-target-current')),
    );
    final targetDecoration = targetCard.decoration! as BoxDecoration;
    final targetBorder = targetDecoration.border! as Border;
    final pickerSize = tester.getSize(
      find.byKey(const ValueKey('scan-target-picker-action')),
    );
    expect(targetRect.top, lessThanOrEqualTo(82));
    expect(targetBorder.top.color, const Color(0xFF263148));
    expect(pickerSize.width, greaterThanOrEqualTo(targetSize.width * 0.9));
    expect(pickerSize.height, greaterThanOrEqualTo(targetSize.height * 0.9));

    await tester.tap(find.byKey(const ValueKey('scan-target-current')));
    await tester.pumpAndSettle();

    expect(picker.initialPaths.single.value, '/');
  });

  testWidgets(
    'first-run chooser blocks ambiguous start until target is chosen',
    (tester) async {
      final preferences = _RecordingScanTargetPreferenceStore();
      final result = await _pumpScanHome(
        tester,
        size: const Size(1440, 900),
        config: const ScanWorkspaceConfig(requiresInitialTargetSelection: true),
        targetCatalog: _StaticScanTargetCatalog([
          _choice(
            id: 'home',
            kind: ScanTargetChoiceKind.home,
            path: '/Users/belief',
            displayName: 'Home',
          ),
          _choice(
            id: 'downloads',
            kind: ScanTargetChoiceKind.downloads,
            path: '/Users/belief/Downloads',
            displayName: 'Downloads',
          ),
          _choice(
            id: 'root',
            kind: ScanTargetChoiceKind.root,
            path: '/',
            displayName: '/',
            scope: TargetScope.volume,
          ),
        ]),
        targetPreferenceStore: preferences,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('first-run-target-chooser')),
        findsOneWidget,
      );
      expect(find.text('Choose what to scan'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('System root'), findsOneWidget);
      expect(find.text('Choose folder'), findsWidgets);

      final scanButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Scan'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(scanButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('first-run-target-choice-home')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('first-run-target-chooser')),
        findsNothing,
      );
      expect(preferences.savedTargets.single.path.value, '/Users/belief');

      await _tapScanAction(tester);
      await tester.pumpAndSettle();

      expect(
        result.fixture.repository.lastStartCommand?.targets.single.path.value,
        '/Users/belief',
      );
    },
  );

  testWidgets('saved target loads before first scan', (tester) async {
    final preferences = _RecordingScanTargetPreferenceStore(
      initial: _target('/Users/belief/Downloads'),
    );
    final result = await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      config: const ScanWorkspaceConfig(requiresInitialTargetSelection: true),
      targetCatalog: _StaticScanTargetCatalog([
        _choice(
          id: 'home',
          kind: ScanTargetChoiceKind.home,
          path: '/Users/belief',
          displayName: 'Home',
        ),
      ]),
      targetPreferenceStore: preferences,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('first-run-target-chooser')),
      findsNothing,
    );
    expect(find.text('/Users/belief/Downloads'), findsWidgets);

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(
      result.fixture.repository.lastStartCommand?.targets.single.path.value,
      '/Users/belief/Downloads',
    );
  });

  testWidgets('config target overrides saved target', (tester) async {
    final preferences = _RecordingScanTargetPreferenceStore(
      initial: _target('/Users/belief/Downloads'),
    );
    final result = await _pumpScanHome(
      tester,
      config: const ScanWorkspaceConfig(
        defaultTargetPath: '/tmp/clean-disk-fixture',
        defaultTargetScope: TargetScope.localPath,
        requiresInitialTargetSelection: false,
      ),
      targetPreferenceStore: preferences,
    );
    await tester.pumpAndSettle();

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(
      result.fixture.repository.lastStartCommand?.targets.single.path.value,
      '/tmp/clean-disk-fixture',
    );
  });

  testWidgets('startup probes app-provided default target after capabilities', (
    tester,
  ) async {
    final fixture = FakeScanFeatureFixture();
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      config: const ScanWorkspaceConfig(
        defaultTargetPath: '/tmp/clean-disk-fixture',
        defaultTargetScope: TargetScope.localPath,
      ),
      fixture: fixture,
    );
    await tester.pumpAndSettle();

    expect(
      fixture.repository.permissionProbeTargets.single.path.value,
      '/tmp/clean-disk-fixture',
    );
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Probe pending'), findsNothing);
  });

  testWidgets('first-run choose folder uses picker and saves target', (
    tester,
  ) async {
    final picker = _RecordingScanTargetPicker(
      ScanTargetPath('/Users/belief/project'),
    );
    final preferences = _RecordingScanTargetPreferenceStore();
    final result = await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      config: const ScanWorkspaceConfig(requiresInitialTargetSelection: true),
      targetCatalog: const _StaticScanTargetCatalog([]),
      targetPreferenceStore: preferences,
      targetPicker: picker,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('first-run-choose-folder-action')),
    );
    await tester.pumpAndSettle();
    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(picker.initialPaths.single.value, '/');
    expect(preferences.savedTargets.single.path.value, '/Users/belief/project');
    expect(
      result.fixture.repository.lastStartCommand?.targets.single.path.value,
      '/Users/belief/project',
    );
  });

  testWidgets('details reveal action invokes path revealer', (tester) async {
    final revealer = _RecordingPathRevealer();
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      pathRevealer: revealer,
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.byTooltip('/Users'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('details-reveal-action')));
    await tester.pumpAndSettle();

    expect(revealer.paths.single.value, '/Users');
  });

  testWidgets('details reveal path is relative to configured target', (
    tester,
  ) async {
    final revealer = _RecordingPathRevealer();
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      config: const ScanWorkspaceConfig(
        defaultTargetPath: '/Users/belief',
        defaultTargetScope: TargetScope.localPath,
      ),
      pathRevealer: revealer,
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('details-reveal-action')));
    await tester.pumpAndSettle();

    expect(revealer.paths.single.value, '/Users/belief/Library/Caches');
  });

  testWidgets('wide details pane collapses to the right and expands back', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('details-reveal-action')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('details-pane-collapsed-rail')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('details-pane-collapse-action')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('details-reveal-action')), findsNothing);
    expect(
      find.byKey(const ValueKey('details-pane-collapsed-rail')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('details-pane-collapsed-rail')))
          .width,
      52,
    );
    expect(
      find.byKey(const ValueKey('details-pane-expand-action')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('details-pane-expand-action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('details-reveal-action')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('details-pane-collapsed-rail')),
      findsNothing,
    );
  });

  testWidgets('details reveal action shows progress while opening path', (
    tester,
  ) async {
    final revealer = _BlockingPathRevealer();
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      pathRevealer: revealer,
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('details-reveal-action')));
    await tester.pump();

    expect(revealer.paths.single.value, '/Users');
    expect(find.text('Opening...'), findsOneWidget);

    revealer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Reveal'), findsOneWidget);
  });

  testWidgets('reveal failure is shown without clearing selection', (
    tester,
  ) async {
    final revealer = _RecordingPathRevealer(
      const Result.failure(
        AppFailure.validation(message: 'Reveal failed', field: 'path'),
      ),
    );
    final result = await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      pathRevealer: revealer,
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('details-reveal-action')));
    await tester.pumpAndSettle();

    expect(find.text('Reveal failed'), findsOneWidget);
    expect(result.store.selectedNodeId, NodeId('2'));
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-tree-table-row-8')));
    await tester.pumpAndSettle();

    expect(result.store.selectedNodeId, NodeId('8'));
    expect(find.text('Reveal failed'), findsNothing);
  });

  testWidgets('starts scan with app-provided default target config', (
    tester,
  ) async {
    final result = await _pumpScanHome(
      tester,
      config: const ScanWorkspaceConfig(
        defaultTargetPath: '/tmp/clean-disk-fixture',
        defaultTargetScope: TargetScope.localPath,
        defaultBoundaryPolicy: BoundaryPolicy.crossFilesystems,
      ),
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    final command = result.fixture.repository.lastStartCommand;
    expect(command?.targets.single.path.value, '/tmp/clean-disk-fixture');
    expect(command?.targets.single.scope, TargetScope.localPath);
    expect(
      command?.targets.single.boundaryPolicy,
      BoundaryPolicy.crossFilesystems,
    );
  });

  testWidgets(
    'loads rows when daemon start returns before snapshot is readable',
    (tester) async {
      final fixture = FakeScanFeatureFixture(
        repository: FakeScanRepository()..deferStartCompletion = true,
      );
      await _pumpScanHome(tester, fixture: fixture);

      await _tapScanAction(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('scan-footer')), findsNothing);
      expect(find.byKey(const ValueKey('scan-footer-hidden')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('app-tree-table-row-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('app-tree-table-row-8')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'loads rows after repeated scan when snapshot arrives through status polling',
    (tester) async {
      final fixture = FakeScanFeatureFixture(
        repository: FakeScanRepository()..deferStartCompletion = true,
      );
      final result = await _pumpScanHome(tester, fixture: fixture);

      await _tapScanAction(tester);
      await tester.pumpAndSettle();

      final firstSessionId = result.store.sessionId;
      final firstSnapshotId = result.store.activeSnapshotId;
      expect(
        find.byKey(const ValueKey('app-tree-table-row-2')),
        findsOneWidget,
      );

      await _tapScanAction(tester);
      await tester.pumpAndSettle();

      expect(result.store.sessionId, isNot(firstSessionId));
      expect(result.store.activeSnapshotId, isNot(firstSnapshotId));
      expect(result.store.hasReadableSnapshot, isTrue);
      expect(
        find.byKey(const ValueKey('app-tree-table-row-2')),
        findsOneWidget,
      );
    },
  );

  testWidgets('ignores replayed snapshot event without an active page scan', (
    tester,
  ) async {
    final result = await _pumpScanHome(tester);
    await tester.pumpAndSettle();

    await result.fixture.repository.startScan(_scanCommand());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(result.store.hasLoadedCurrentTreeRoot, isFalse);
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsNothing);
    expect(find.text('No scan data yet'), findsOneWidget);
  });

  testWidgets('review list executes validated directory cleanup to Trash', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Mark a row to review before moving it to Trash.'),
      findsOneWidget,
    );
    expect(find.text('Validate list'), findsNothing);
    expect(
      find.byKey(const ValueKey('cleanup-preview-trash-notice')),
      findsNothing,
    );

    await tester.tap(find.text('Add to review'));
    await tester.pumpAndSettle();

    expect(find.text('In review'), findsOneWidget);
    final inReview = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('In review'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(inReview.onPressed, isNull);
    expect(find.text('196.7 GB'), findsWidgets);
    expect(
      find.text('Review complete. Ready to move to Trash.'),
      findsOneWidget,
    );
    expect(find.text('No permission'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Validate list'), findsOneWidget);

    final refreshPreview = find.byKey(
      const ValueKey('cleanup-preview-refresh-action'),
    );
    await tester.ensureVisible(refreshPreview);
    await tester.tap(refreshPreview);
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(
      find.text('Review complete. Ready to move to Trash.'),
      findsOneWidget,
    );
    expect(find.text('System Trash only'), findsOneWidget);
    expect(
      find.text(
        'Clean Disk revalidates the current snapshot before moving items. Nothing is permanently deleted here.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cleanup-preview-trash-notice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cleanup-preview-trash-action')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('cleanup-preview-trash-action')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('cleanup-confirm-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cleanup-confirm-items')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cleanup-confirm-items')),
        matching: find.text('Users'),
      ),
      findsOneWidget,
    );
    expect(find.text('Move selected items to Trash?'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('cleanup-confirm-trash-action')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Receipt recorded.'), findsOneWidget);
    expect(find.text('Users: Moved to Trash'), findsOneWidget);
    expect(find.text('In review'), findsNothing);
    expect(find.text('In Trash'), findsWidgets);
    expect(
      find.byKey(const ValueKey('details-moved-to-trash-hint')),
      findsOneWidget,
    );
    expect(find.textContaining('already moved to Trash'), findsOneWidget);

    final movedToTrashAction = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('In Trash').last,
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(movedToTrashAction.onPressed, isNull);
  });

  testWidgets('review list cancel keeps cleanup queued without execution', (
    tester,
  ) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to review'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('cleanup-preview-trash-action')),
    );

    await tester.tap(
      find.byKey(const ValueKey('cleanup-preview-trash-action')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cleanup-confirm-dialog')),
      findsOneWidget,
    );
    expect(result.fixture.repository.lastCleanupReceipt, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cleanup-confirm-dialog')), findsNothing);
    expect(result.fixture.repository.lastCleanupReceipt, isNull);
    expect(find.text('In review'), findsOneWidget);
    expect(result.store.queuedItems, hasLength(1));
  });

  testWidgets('renders partial scan issues and details evidence', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Some paths were skipped or degraded. Review details before acting.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    expect(find.text('System protected path skipped'), findsOneWidget);
  });

  testWidgets('renders stale snapshot state without clearing visible rows', (
    tester,
  ) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    result.fixture.eventClient.add(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('99'),
        emittedAtUnixMs: BigInt.from(1700000000099),
        event: ScanSnapshotPublished(
          sessionId: FakeScanRepository.sessionId,
          snapshotId: SnapshotId('101'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Run the scan again to refresh the tree.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('app-tree-table-row-2')), findsOneWidget);
  });

  testWidgets('renders empty error state distinctly from no-data state', (
    tester,
  ) async {
    final result = await _pumpScanHome(tester, size: const Size(1440, 900));

    result.fixture.eventClient.addFailure(
      const AppFailure.network(message: 'offline from test'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan data unavailable'), findsOneWidget);
    expect(find.text('offline from test'), findsOneWidget);
    expect(find.text('No scan data yet'), findsNothing);
  });
}

Future<void> _tapScanAction(WidgetTester tester) async {
  final keyedAction = find.byKey(const ValueKey('scan-toolbar-scan-action'));
  if (keyedAction.evaluate().isNotEmpty) {
    await tester.tap(keyedAction.first);
    return;
  }
  await tester.tap(find.byTooltip('Scan'));
}

Future<void> _selectNestedCrashLog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('app-tree-table-row-2')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('app-tree-table-row-3')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('app-tree-table-row-4')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('app-tree-table-row-10')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('app-tree-table-row-11')));
  await tester.pumpAndSettle();
}

Future<_PumpedScanHome> _pumpScanHome(
  WidgetTester tester, {
  Size? size,
  ScanWorkspaceConfig config = const ScanWorkspaceConfig(),
  FakeScanFeatureFixture? fixture,
  PermissionRepairLauncher? permissionRepairLauncher,
  ScanTargetPicker? targetPicker,
  ScanTargetCatalog? targetCatalog,
  ScanTargetPreferenceStore? targetPreferenceStore,
  PathRevealer? pathRevealer,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final theme = AppTheme.dark();
  final effectiveFixture = fixture ?? FakeScanFeatureFixture();
  final store = ScanUseCaseBundle.fromPorts(
    repository: effectiveFixture.repository,
    eventClient: effectiveFixture.eventClient,
    permissionRepairLauncher: permissionRepairLauncher,
    targetPicker: targetPicker,
    targetCatalog: targetCatalog,
    targetPreferenceStore: targetPreferenceStore,
    pathRevealer: pathRevealer,
  ).createWorkspaceStore();
  addTearDown(effectiveFixture.eventClient.close);

  await tester.pumpWidget(
    AppHeadlessScope(
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      appBuilder: (overlayBuilder) {
        return MaterialApp(
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.dark,
          localizationsDelegates: CleanDiskLocalizations.localizationsDelegates,
          supportedLocales: CleanDiskLocalizations.supportedLocales,
          builder: overlayBuilder,
          home: ScanHomePage(store: store, config: config),
        );
      },
    ),
  );
  await tester.pump();

  return _PumpedScanHome(fixture: effectiveFixture, store: store);
}

final class _RecordingPermissionRepairLauncher
    implements PermissionRepairLauncher {
  _RecordingPermissionRepairLauncher({this.onLaunch});

  final VoidCallback? onLaunch;
  final List<ScanTarget> targets = [];
  final List<RuntimeProof> proofs = [];

  @override
  Future<Result<Unit>> launchPermissionRepair({
    required ScanTarget target,
    required RuntimeProof proof,
  }) async {
    targets.add(target);
    proofs.add(proof);
    onLaunch?.call();
    return const Result.success(Unit.value);
  }
}

final class _RecordingScanTargetPicker implements ScanTargetPicker {
  _RecordingScanTargetPicker(this.path);

  final ScanTargetPath path;
  final List<ScanTargetPath> initialPaths = [];

  @override
  Future<Result<ScanTargetPath?>> pickDirectory({
    required ScanTargetPath initialPath,
  }) async {
    initialPaths.add(initialPath);
    return Result.success(path);
  }
}

final class _StaticScanTargetCatalog implements ScanTargetCatalog {
  const _StaticScanTargetCatalog(this.choices);

  final List<ScanTargetChoice> choices;

  @override
  Future<Result<List<ScanTargetChoice>>> listChoices() async {
    return Result.success(choices);
  }
}

final class _RecordingScanTargetPreferenceStore
    implements ScanTargetPreferenceStore {
  _RecordingScanTargetPreferenceStore({ScanTarget? initial}) : target = initial;

  ScanTarget? target;
  final List<ScanTarget> savedTargets = [];

  @override
  Future<Result<ScanTarget?>> loadLastTarget() async {
    return Result.success(target);
  }

  @override
  Future<Result<Unit>> saveLastTarget(ScanTarget target) async {
    savedTargets.add(target);
    this.target = target;
    return const Result.success(Unit.value);
  }
}

final class _RecordingPathRevealer implements PathRevealer {
  _RecordingPathRevealer([this.result = const Result.success(Unit.value)]);

  Result<Unit> result;
  final List<ScanTargetPath> paths = [];

  @override
  Future<Result<Unit>> revealPath(ScanTargetPath path) async {
    paths.add(path);
    return result;
  }
}

final class _BlockingPathRevealer implements PathRevealer {
  final Completer<Result<Unit>> _completer = Completer<Result<Unit>>();
  final List<ScanTargetPath> paths = [];

  @override
  Future<Result<Unit>> revealPath(ScanTargetPath path) {
    paths.add(path);
    return _completer.future;
  }

  void complete() {
    _completer.complete(const Result.success(Unit.value));
  }
}

ScanTargetChoice _choice({
  required String id,
  required ScanTargetChoiceKind kind,
  required String path,
  required String displayName,
  TargetScope scope = TargetScope.localPath,
}) {
  return ScanTargetChoice(
    id: id,
    kind: kind,
    displayName: displayName,
    target: ScanTarget(
      path: ScanTargetPath(path),
      scope: scope,
      boundaryPolicy: BoundaryPolicy.stayOnInitialFilesystem,
      hardlinkPolicy: HardlinkPolicy.ignore,
    ),
  );
}

ScanTarget _target(String path) {
  return ScanTarget(
    path: ScanTargetPath(path),
    scope: TargetScope.localPath,
    boundaryPolicy: BoundaryPolicy.stayOnInitialFilesystem,
    hardlinkPolicy: HardlinkPolicy.ignore,
  );
}

StartScanCommand _scanCommand() {
  return StartScanCommand(
    commandId: CommandId('1'),
    targets: [_target('/tmp/clean-disk-fixture')],
    measurement: MeasuredQuantity.apparentBytes,
    mode: ScanMode.balanced,
  );
}

final class _PumpedScanHome {
  const _PumpedScanHome({required this.fixture, required this.store});

  final FakeScanFeatureFixture fixture;
  final ScanWorkspaceStore store;
}

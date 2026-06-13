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
    expect(find.byKey(const ValueKey('scan-ai-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-ai-chat-input')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('scan-target-breadcrumb')),
      findsOneWidget,
    );

    await _openTargetMenu(tester);
    expect(
      find.byKey(const ValueKey('scan-target-header-menu')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('scan-target-menu-current')),
      findsOneWidget,
    );
    expect(find.textContaining('Permission Proof'), findsOneWidget);
    expect(find.textContaining('Verified'), findsOneWidget);
    expect(find.text('Probe pending'), findsNothing);
    expect(find.text('Unverified'), findsNothing);
    expect(find.textContaining('Development build'), findsNothing);
    expect(
      find.byKey(const ValueKey('permission-warning-prominent')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('permission-proof-neutral')),
      findsNothing,
    );
    expect(
      find.text('Reduced dev package - verify signed build'),
      findsNothing,
    );
    expect(find.text('Dev shell / Unsigned'), findsNothing);
    expect(find.text('Not checked'), findsNothing);

    await tester.tap(find.byTooltip('Re-check'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Verified'), findsOneWidget);
    expect(find.text('Not checked'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('scan-target-breadcrumb-action')),
    );
    await tester.pumpAndSettle();
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

    await _openTargetMenu(tester);
    expect(
      find.byKey(const ValueKey('scan-target-menu-permission-line')),
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
    expect(
      find.byKey(const ValueKey('permission-proof-neutral')),
      findsNothing,
    );
    expect(find.textContaining('Unknown'), findsOneWidget);
    expect(find.byTooltip('Re-check'), findsOneWidget);
    expect(find.text('Development build'), findsNothing);
    expect(find.text('Not checked'), findsNothing);
  });

  testWidgets('collapsible disk map renders above the folder tree', (
    tester,
  ) async {
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      diskUsageMapRenderer: const _TestDiskUsageMapRenderer(),
    );

    expect(
      find.byKey(const ValueKey('scan-disk-usage-map-panel')),
      findsNothing,
    );

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('scan-disk-usage-map-panel'));
    final renderedMap = find.byKey(
      const ValueKey('test-disk-usage-map-renderer'),
    );
    final firstTreeRow = find.byKey(const ValueKey('app-tree-table-row-2'));

    expect(panel, findsOneWidget);
    expect(renderedMap, findsOneWidget);
    expect(firstTreeRow, findsOneWidget);
    var mapLabels = _diskUsageMapLabels(tester);
    expect(mapLabels, contains('Caches'));
    expect(mapLabels, contains('Xcode'));
    expect(mapLabels, contains('Downloads'));
    expect(find.byKey(const ValueKey('app-tree-table-row-12')), findsNothing);
    expect(
      tester.getTopLeft(panel).dy,
      lessThan(tester.getTopLeft(firstTreeRow).dy),
    );

    await tester.tap(find.byKey(const ValueKey('test-map-tile-Library')));
    await tester.pumpAndSettle();

    mapLabels = _diskUsageMapLabels(tester);
    expect(mapLabels, contains('Library'));
    expect(mapLabels, contains('Caches'));
    expect(mapLabels, contains('Xcode'));
    expect(mapLabels, isNot(contains('Downloads')));

    await tester.tap(find.byKey(const ValueKey('test-map-tile-Library')));
    await tester.pumpAndSettle();

    mapLabels = _diskUsageMapLabels(tester);
    expect(mapLabels, contains('Downloads'));

    await tester.tap(find.byKey(const ValueKey('test-map-tile-Library')));
    await tester.pumpAndSettle();
    await tester.tap(firstTreeRow);
    await tester.pumpAndSettle();

    mapLabels = _diskUsageMapLabels(tester);
    expect(mapLabels, contains('Downloads'));

    await tester.tap(find.byTooltip('Collapse disk map'));
    await tester.pumpAndSettle();

    expect(panel, findsOneWidget);
    expect(renderedMap, findsNothing);

    await tester.tap(find.byTooltip('Expand disk map'));
    await tester.pumpAndSettle();

    expect(renderedMap, findsOneWidget);
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
      expect(
        find.byKey(const ValueKey('scan-footer-stop-action')),
        findsOneWidget,
      );
      expect(find.text('Files Scanned'), findsOneWidget);
      expect(find.text('Elapsed'), findsOneWidget);
      expect(find.text('Throughput'), findsOneWidget);
    },
  );

  testWidgets('footer stop action cancels a running scan', (tester) async {
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

    expect(result.store.sessionStatus?.state, SessionState.running);
    expect(
      find.byKey(const ValueKey('scan-footer-stop-action')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('scan-footer-stop-action')));
    await tester.pump();

    expect(result.store.sessionStatus?.state, SessionState.canceled);
    expect(find.byKey(const ValueKey('scan-footer-stop-action')), findsNothing);
  });

  testWidgets('running footer shows elapsed time and item rate', (
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

    result.fixture.eventClient.add(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('2'),
        emittedAtUnixMs: BigInt.from(1700000000002),
        event: ScanProgressed(
          sessionId: FakeScanRepository.sessionId,
          progress: ScanProgress(
            scannedItems: BigInt.from(1000),
            elapsedMs: BigInt.from(1000),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('00:00:01'), findsOneWidget);
    expect(find.text('1.0k items/s'), findsOneWidget);
  });

  testWidgets('metric strip shows scanning copy while totals are pending', (
    tester,
  ) async {
    final repository = FakeScanRepository()
      ..deferStartCompletion = true
      ..emitStartScanEvents = false;
    final fixture = FakeScanFeatureFixture(repository: repository);
    final result = await _pumpScanHome(
      tester,
      fixture: fixture,
      size: const Size(1440, 900),
    );
    await result.store.start(_scanCommand());
    await tester.pump();

    result.fixture.eventClient.add(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('2'),
        emittedAtUnixMs: BigInt.from(1700000000002),
        event: ScanProgressed(
          sessionId: FakeScanRepository.sessionId,
          progress: ScanProgress(scannedItems: BigInt.from(208214)),
        ),
      ),
    );
    await tester.pump();

    expect(result.store.sessionStatus?.state, SessionState.running);
    expect(find.text('TOTAL SCANNED'), findsOneWidget);
    expect(find.text('LARGEST FOLDER'), findsOneWidget);
    expect(find.text('Scanning'), findsNWidgets(4));
    expect(find.textContaining('Сканирую'), findsOneWidget);
    expect(find.text('208214 files'), findsOneWidget);
    expect(find.text('Finding largest folders'), findsOneWidget);
    expect(find.text('Run a scan'), findsNothing);
  });

  testWidgets('renders growing tree rows without selecting cleanup authority', (
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

    result.fixture.eventClient.add(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('5'),
        emittedAtUnixMs: BigInt.from(1700000020),
        event: ScanGrowingTreeBatch(
          sessionId: FakeScanRepository.sessionId,
          scannedItems: BigInt.from(2),
          events: [
            GrowingNodeDiscovered(
              nodeId: PartialNodeId('101'),
              parentId: null,
              name: 'Live Root',
              kind: NodeKind.directory,
            ),
            GrowingNodeDiscovered(
              nodeId: PartialNodeId('102'),
              parentId: PartialNodeId('101'),
              name: 'Live Folder',
              kind: NodeKind.directory,
            ),
            GrowingNodeSizeUpdated(
              nodeId: PartialNodeId('102'),
              aggregateSize: SizeFact(
                rawValue: '2048',
                quantity: MeasuredQuantity.apparentBytes,
                byteEquivalent: '2048',
                confidence: SizeConfidence.low,
              ),
              state: GrowingNodeState.scanning,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Live Root'), findsOneWidget);
    expect(find.text('Live Folder'), findsOneWidget);

    await tester.tap(find.text('Live Root'));
    await tester.pump();

    expect(find.text('Live Folder'), findsNothing);
    expect(result.store.selectedNodeId, isNull);

    await tester.tap(find.text('Live Root'));
    await tester.pump();

    expect(find.text('Live Folder'), findsOneWidget);

    await tester.tap(find.text('Live Folder'));
    await tester.pump();

    expect(result.store.selectedNodeId, isNull);
    expect(result.store.queuedItems, isEmpty);
  });

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
    expect(find.text('0 B'), findsNothing);

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(find.text('TOTAL SCANNED'), findsOneWidget);
    expect(find.text('LARGEST FOLDER'), findsOneWidget);
    expect(find.text('REVIEW LIST'), findsNothing);
    expect(find.text('SKIPPED'), findsNothing);
    expect(find.byKey(const ValueKey('scan-ai-focus-summary')), findsOneWidget);
    expect(find.text('0 B'), findsNothing);
    expect(find.text('386.4 GB'), findsWidgets);
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
    expect(contentRect.center.dy, lessThanOrEqualTo(tableRect.center.dy));
    expect(tableRect.height, lessThanOrEqualTo(260));
  });

  testWidgets('wide AI rail leaves room for the tree workspace', (
    tester,
  ) async {
    await _pumpScanHome(tester, size: const Size(1440, 900));

    final railSize = tester.getSize(find.byKey(const ValueKey('scan-ai-rail')));
    final tableRect = tester.getRect(find.byType(AppTreeTable));

    expect(find.text('AI-помощник'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-ai-chat-input')), findsOneWidget);
    expect(railSize.width, lessThanOrEqualTo(360));
    expect(tableRect.width, greaterThanOrEqualTo(760));
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

    await _openTargetMenu(tester);
    expect(find.textContaining('Denied'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('permission-warning-prominent')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('permission-warning-compact')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('permission-proof-neutral')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('permission-repair-action')),
      findsOneWidget,
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
    expect(find.textContaining('Verified'), findsOneWidget);
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

      await _openTargetMenu(tester);
      await tester.tap(find.byKey(const ValueKey('permission-repair-action')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('permission-repair-open-settings-action')),
      );
      await tester.pumpAndSettle();

      expect(launcher.targets.single.path.value, '/tmp/clean-disk-fixture');
      expect(find.textContaining('Denied'), findsOneWidget);
      expect(find.textContaining('Verified'), findsNothing);
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

    expect(find.text('386.4 GB'), findsWidgets);
    expect(find.byKey(const ValueKey('app-tree-table-row-3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app-tree-table-toggle-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-tree-table-row-3')), findsOneWidget);
    expect(result.store.selectedNodeId, NodeId('2'));
    expect(find.text('386.4 GB'), findsWidgets);
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
      config: const ScanWorkspaceConfig(requiresInitialTargetSelection: true),
      targetPreferenceStore: _RecordingScanTargetPreferenceStore(
        initial: _target('/'),
      ),
      targetPicker: picker,
    );

    await _openTargetMenu(tester);
    await tester.tap(
      find.byKey(const ValueKey('scan-target-menu-open-picker-action')),
    );
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

  testWidgets('configured target remains available from header picker', (
    tester,
  ) async {
    final picker = _RecordingScanTargetPicker(ScanTargetPath('/Users/belief'));
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      targetPicker: picker,
    );

    expect(picker.initialPaths, isEmpty);
    expect(
      find.byKey(const ValueKey('scan-target-breadcrumb-action')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byTooltip('Change folder'), findsNothing);

    await _openTargetMenu(tester);
    expect(
      find.byKey(const ValueKey('scan-target-header-menu')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('scan-target-menu-open-picker-action')),
      findsOneWidget,
    );
  });

  testWidgets('top breadcrumb picks a concrete folder for the next scan', (
    tester,
  ) async {
    final picker = _RecordingScanTargetPicker(
      ScanTargetPath('/Users/belief/Projects'),
    );
    final preferences = _RecordingScanTargetPreferenceStore();
    final result = await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      config: const ScanWorkspaceConfig(
        defaultTargetPath: '/Users/belief',
        requiresInitialTargetSelection: false,
      ),
      targetPicker: picker,
      targetPreferenceStore: preferences,
    );
    await tester.pumpAndSettle();

    await _openTargetMenu(tester);
    await tester.tap(
      find.byKey(const ValueKey('scan-target-menu-pick-folder-action')),
    );
    await tester.pumpAndSettle();

    expect(picker.initialPaths.single.value, '/Users/belief');
    expect(
      preferences.savedTargets.single.path.value,
      '/Users/belief/Projects',
    );
    expect(find.text('/Users/belief/Projects'), findsOneWidget);

    await _tapScanAction(tester);
    await tester.pumpAndSettle();

    expect(
      result.fixture.repository.lastStartCommand?.targets.single.path.value,
      '/Users/belief/Projects',
    );
    expect(
      result.fixture.repository.lastStartCommand?.targets.single.scope,
      TargetScope.localPath,
    );
  });

  testWidgets('wide header target menu exposes saved target actions', (
    tester,
  ) async {
    final picker = _RecordingScanTargetPicker(ScanTargetPath('/Users/belief'));
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      config: const ScanWorkspaceConfig(requiresInitialTargetSelection: true),
      targetPreferenceStore: _RecordingScanTargetPreferenceStore(
        initial: _target('/'),
      ),
      targetPicker: picker,
    );

    expect(find.byTooltip('Change folder'), findsNothing);
    expect(find.text('Folder'), findsNothing);
    final targetRect = tester.getRect(
      find.byKey(const ValueKey('scan-target-breadcrumb')),
    );
    expect(targetRect.top, lessThanOrEqualTo(82));

    await _openTargetMenu(tester);
    expect(
      find.byKey(const ValueKey('scan-target-menu-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('scan-target-menu-pick-folder-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('scan-target-menu-open-picker-action')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('scan-target-menu-pick-folder-action')),
    );
    await tester.pumpAndSettle();

    expect(picker.initialPaths.single.value, '/');
  });

  testWidgets('wide header target menu renders concrete catalog folders', (
    tester,
  ) async {
    await _pumpScanHome(
      tester,
      size: const Size(1440, 900),
      config: const ScanWorkspaceConfig(requiresInitialTargetSelection: true),
      targetPreferenceStore: _RecordingScanTargetPreferenceStore(
        initial: _target('/Users/belief'),
      ),
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
          id: 'library',
          kind: ScanTargetChoiceKind.library,
          path: '/Users/belief/Library',
          displayName: 'Library',
        ),
        _choice(
          id: 'applications',
          kind: ScanTargetChoiceKind.applications,
          path: '/Applications',
          displayName: 'Applications',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await _openTargetMenu(tester);
    expect(
      find.byKey(const ValueKey('scan-target-menu-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('scan-target-menu-choice-downloads')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('scan-target-menu-choice-library')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('scan-target-menu-choice-applications')),
      findsOneWidget,
    );
  });

  testWidgets(
    'wide header target presets remain selectable with config target',
    (tester) async {
      final preferences = _RecordingScanTargetPreferenceStore();
      final targetCatalog = _SequencedScanTargetCatalog([
        [
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
        ],
        [
          _choice(
            id: 'downloads',
            kind: ScanTargetChoiceKind.downloads,
            path: '/Users/belief/Downloads',
            displayName: 'Downloads',
          ),
          _choice(
            id: 'library',
            kind: ScanTargetChoiceKind.library,
            path: '/Users/belief/Library',
            displayName: 'Library',
          ),
        ],
      ]);
      final result = await _pumpScanHome(
        tester,
        size: const Size(1440, 900),
        config: const ScanWorkspaceConfig(
          defaultTargetPath: '/Users/belief',
          requiresInitialTargetSelection: false,
        ),
        targetPreferenceStore: preferences,
        targetCatalog: targetCatalog,
      );
      await tester.pumpAndSettle();

      await _openTargetMenu(tester);

      await tester.tap(
        find.byKey(const ValueKey('scan-target-menu-choice-downloads')),
      );
      await tester.pumpAndSettle();

      expect(
        preferences.savedTargets.single.path.value,
        '/Users/belief/Downloads',
      );
      expect(targetCatalog.listCalls, greaterThanOrEqualTo(2));
      expect(
        find.byKey(const ValueKey('scan-target-menu-choice-library')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('scan-target-menu-choice-home')),
        findsNothing,
      );

      await _tapScanAction(tester);
      await tester.pumpAndSettle();

      expect(
        result.fixture.repository.lastStartCommand?.targets.single.path.value,
        '/Users/belief/Downloads',
      );
    },
  );

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

      final chooserFinder = find.byKey(
        const ValueKey('first-run-target-chooser'),
      );
      expect(chooserFinder, findsOneWidget);
      expect(find.text('Choose what to scan'), findsOneWidget);
      expect(
        find.descendant(of: chooserFinder, matching: find.text('Home')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chooserFinder, matching: find.text('Downloads')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chooserFinder, matching: find.text('System root')),
        findsOneWidget,
      );
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
    await _openTargetMenu(tester);
    expect(find.textContaining('Verified'), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('details-pane-info-action')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('details-pane-info-action')));
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

Future<void> _openTargetMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('scan-target-breadcrumb-action')));
  await tester.pumpAndSettle();
}

String _diskUsageMapLabels(WidgetTester tester) {
  return tester
          .widget<Text>(
            find.byKey(const ValueKey('test-disk-usage-map-labels')),
          )
          .data ??
      '';
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
  DiskUsageMapRenderer? diskUsageMapRenderer,
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
          home: ScanHomePage(
            store: store,
            config: config,
            diskUsageMapRenderer: diskUsageMapRenderer,
          ),
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

final class _SequencedScanTargetCatalog implements ScanTargetCatalog {
  _SequencedScanTargetCatalog(this.responses);

  final List<List<ScanTargetChoice>> responses;
  var listCalls = 0;

  @override
  Future<Result<List<ScanTargetChoice>>> listChoices() async {
    final index = listCalls < responses.length
        ? listCalls
        : responses.length - 1;
    listCalls += 1;
    return Result.success(responses[index]);
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

final class _TestDiskUsageMapRenderer implements DiskUsageMapRenderer {
  const _TestDiskUsageMapRenderer();

  @override
  DiskUsageMapRendererCapabilities get capabilities =>
      const DiskUsageMapRendererCapabilities(
        rendererName: 'test',
        trustLevel: DiskUsageMapRendererTrustLevel.testOnly,
        supportedKinds: <DiskUsageMapKind>{DiskUsageMapKind.treemap},
      );

  @override
  Widget build(BuildContext context, DiskUsageMapRenderContext renderContext) {
    final tiles = renderContext.projection.visualTiles;
    return DecoratedBox(
      key: const ValueKey('test-disk-usage-map-renderer'),
      decoration: BoxDecoration(color: renderContext.style.backgroundColor),
      child: Column(
        children: [
          Text(
            tiles.map((tile) => tile.label).join('|'),
            key: const ValueKey('test-disk-usage-map-labels'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Expanded(
            child: ListView(
              children: [
                for (final tile in tiles.take(4))
                  GestureDetector(
                    key: ValueKey('test-map-tile-${tile.label}'),
                    onTap: () => renderContext.onTileSelected?.call(tile),
                    child: Text(tile.label),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/path_revealer.dart';
import 'package:clean_disk_scan/src/application/ports/permission_repair_launcher.dart';
import 'package:clean_disk_scan/src/application/ports/scan_event_client.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_catalog.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_preference_store.dart';
import 'package:clean_disk_scan/src/application/use_cases/cancel_scan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/create_cleanup_plan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/dispose_scan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/execute_cleanup_plan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_capabilities_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_children_page_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_cleanup_recovery_inbox_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_node_details_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_scan_status_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_top_items_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/launch_permission_repair_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/list_scan_target_choices_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/load_last_scan_target_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/probe_permission_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/reveal_path_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/save_last_scan_target_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/search_nodes_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/start_scan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/watch_scan_events_use_case.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';
import 'package:clean_disk_scan/src/presentation/stores/scan_workspace_store.dart';
import 'package:test/test.dart';

void main() {
  test(
    'checks daemon compatibility and exposes incompatible/offline states',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      repository.capabilities = Result.success(
        _capabilities(version: const ProtocolVersion(major: 9, minor: 0)),
      );
      await store.checkDaemonCompatibility();

      expect(store.daemonAvailability, ScanDaemonAvailability.incompatible);

      repository.capabilities = const Result.failure(
        AppFailure.network(message: 'offline'),
      );
      await store.checkDaemonCompatibility(attempts: 1);

      expect(store.daemonAvailability, ScanDaemonAvailability.offline);
      expect(store.lastFailure, isA<NetworkFailure>());
    },
  );

  test('retries transient capability network failures', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    repository.capabilityResponses.addAll([
      const Result.failure(AppFailure.network(message: 'not ready')),
      Result.success(_capabilities(version: ProtocolVersion.current)),
    ]);

    await store.checkDaemonCompatibility(
      attempts: 2,
      retryDelay: Duration.zero,
    );

    expect(store.daemonAvailability, ScanDaemonAvailability.ready);
    expect(store.lastFailure, isNull);
    expect(repository.capabilityRequestCount, 2);
  });

  test(
    'permission probe updates runtime proof without failing the page',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      await store.checkDaemonCompatibility();
      expect(
        store.capabilities?.runtimeProof.permissionProbe.status,
        PermissionProbeStatus.unknown,
      );
      expect(
        store.runtimeProof.permissionProbe.status,
        PermissionProbeStatus.unknown,
      );

      await store.probeTargetPermission(_startCommand().targets.single);

      expect(repository.permissionProbeTargets.single.path.value, '/tmp');
      expect(store.pageLoadState, ScanPageLoadState.idle);
      expect(store.lastFailure, isNull);
      expect(
        store.capabilities?.runtimeProof.permissionProbe.status,
        PermissionProbeStatus.verified,
      );
      expect(
        store.runtimeProof.permissionProbe.status,
        PermissionProbeStatus.verified,
      );
    },
  );

  test(
    'permission probe authorizes cleanup preview even before capabilities hydrate',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);
      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      );

      expect(store.capabilities, isNull);
      await store.start(_startCommand());
      store.queueNode(_node(id: '10', name: 'Crashpad'));
      await store.refreshCleanupPreview(_startCommand().targets.single);

      expect(store.capabilities, isNull);
      expect(
        store.runtimeProof.permissionProbe.status,
        PermissionProbeStatus.verified,
      );
      expect(
        store.deletePlan.items.single.states,
        isNot(contains(DeletePlanItemState.missingPermission)),
      );
      expect(store.deletePlan.canAuthorizeCleanup, isTrue);
    },
  );

  test(
    'permission repair launches app adapter and updates state only by re-probe',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final launcher = _FakePermissionRepairLauncher();
      final store = _store(
        repository,
        eventClient,
        permissionRepairLauncher: launcher,
      );
      repository.capabilities = Result.success(
        _capabilities(
          version: ProtocolVersion.current,
          runtimeProof: RuntimeProof.unknown.copyWith(
            permissionProbe: const PermissionProbe(
              status: PermissionProbeStatus.denied,
              checkedAtUnixMs: null,
              requiredAction: PermissionRequiredAction.openMacosFullDiskAccess,
            ),
          ),
        ),
      );

      await store.checkDaemonCompatibility();
      expect(store.canRepairPermission, isTrue);
      expect(
        store.capabilities?.runtimeProof.permissionProbe.status,
        PermissionProbeStatus.denied,
      );

      await store.repairTargetPermission(_startCommand().targets.single);

      expect(launcher.targets.single.path.value, '/tmp');
      expect(
        launcher.proofs.single.permissionProbe.requiredAction,
        PermissionRequiredAction.openMacosFullDiskAccess,
      );
      expect(repository.permissionProbeTargets.single.path.value, '/tmp');
      expect(store.lastFailure, isNull);
      expect(
        store.capabilities?.runtimeProof.permissionProbe.status,
        PermissionProbeStatus.verified,
      );
    },
  );

  test(
    'permission repair stays denied when scanner re-probe still lacks access',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final launcher = _FakePermissionRepairLauncher();
      final deniedProbe = PermissionProbe(
        status: PermissionProbeStatus.denied,
        checkedAtUnixMs: BigInt.from(1700000000001),
        requiredAction: PermissionRequiredAction.openMacosFullDiskAccess,
      );
      final store = _store(
        repository,
        eventClient,
        permissionRepairLauncher: launcher,
      );
      repository.capabilities = Result.success(
        _capabilities(
          version: ProtocolVersion.current,
          runtimeProof: RuntimeProof.unknown.copyWith(
            permissionProbe: deniedProbe,
          ),
        ),
      );
      repository.permissionProbe = Result.success(deniedProbe);

      await store.checkDaemonCompatibility();
      await store.repairTargetPermission(_startCommand().targets.single);

      expect(launcher.targets.single.path.value, '/tmp');
      expect(repository.permissionProbeTargets.single.path.value, '/tmp');
      expect(
        store.capabilities?.runtimeProof.permissionProbe.status,
        PermissionProbeStatus.denied,
      );
      expect(
        store.capabilities?.runtimeProof.permissionProbe.requiredAction,
        PermissionRequiredAction.openMacosFullDiskAccess,
      );
      expect(store.lastFailure, isNull);
    },
  );

  test(
    'loads target choices and persists the selected target through ports',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final savedTarget = _scanTarget('/Users/belief/Downloads');
      final catalog = _FakeScanTargetCatalog([
        ScanTargetChoice(
          id: 'home',
          kind: ScanTargetChoiceKind.home,
          displayName: 'Home',
          target: _scanTarget('/Users/belief'),
        ),
        ScanTargetChoice(
          id: 'downloads',
          kind: ScanTargetChoiceKind.downloads,
          displayName: 'Downloads',
          target: savedTarget,
        ),
      ]);
      final preferences = _FakeScanTargetPreferenceStore(savedTarget);
      final store = _store(
        repository,
        eventClient,
        targetCatalog: catalog,
        targetPreferenceStore: preferences,
      );

      await store.loadTargetChoices();
      final loaded = await store.loadLastScanTarget();
      await store.saveLastScanTarget(_scanTarget('/tmp/project'));

      expect(store.targetChoices.map((choice) => choice.kind), [
        ScanTargetChoiceKind.home,
        ScanTargetChoiceKind.downloads,
      ]);
      expect(loaded?.path.value, '/Users/belief/Downloads');
      expect(preferences.savedTargets.single.path.value, '/tmp/project');
    },
  );

  test(
    'reveal failure stays non-blocking and preserves selection and tree rows',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final revealer = _FakePathRevealer(
        const Result.failure(
          AppFailure.validation(message: 'Path missing', field: 'path'),
        ),
      );
      final store = _store(repository, eventClient, pathRevealer: revealer);
      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      );
      repository.childrenPage = Result.success(
        NodePage(
          snapshotId: SnapshotId('2'),
          items: [_node(id: '10', name: 'Caches')],
          nextCursor: null,
        ),
      );

      await store.start(_startCommand());
      await store.loadPrimaryRootChildren(limit: 100);
      await store.selectNode(NodeId('10'));
      await store.revealPath(ScanTargetPath('/tmp/Caches'));

      expect(revealer.paths.single.value, '/tmp/Caches');
      expect(store.lastRevealFailure?.message, 'Path missing');
      expect(store.selectedNodeId, NodeId('10'));
      expect(store.visibleRows.single.name, 'Caches');
      expect(store.pageLoadState, ScanPageLoadState.idle);
    },
  );

  test('clears scan read model when target changes', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);
    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );
    repository.childrenPage = Result.success(
      NodePage(
        snapshotId: SnapshotId('2'),
        items: [_node(id: '10', name: 'Caches')],
        nextCursor: null,
      ),
    );

    await store.start(_startCommand());
    await store.loadPrimaryRootChildren(limit: 100);
    await store.selectNode(NodeId('10'));
    store.queueNode(_node(id: '10', name: 'Caches'));

    store.clearReadModelForTargetChange();

    expect(store.sessionStatus, isNull);
    expect(store.activeSnapshotId, isNull);
    expect(store.hasReadableSnapshot, isFalse);
    expect(store.visibleRows, isEmpty);
    expect(store.selectedDetails, isNull);
    expect(store.queuedItems, isEmpty);
  });

  test('delete plan allows complete non-protected directories', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);
    repository.capabilities = Result.success(
      _capabilities(
        version: ProtocolVersion.current,
        runtimeProof: _verifiedRuntimeProof(),
      ),
    );
    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );

    await store.checkDaemonCompatibility();
    await store.start(_startCommand());
    store.queueNode(
      _node(id: '10', name: 'Caches', kind: NodeKind.directory, childCount: 3),
    );

    expect(store.deletePlan.items.single.states, isEmpty);
    expect(store.deletePlan.canAuthorizeCleanup, isTrue);
  });

  test(
    'queries children pages without keeping a full tree in Flutter',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      );
      repository.childrenPage = Result.success(
        NodePage(
          snapshotId: SnapshotId('2'),
          items: [_node(id: '10', name: 'Caches')],
          nextCursor: null,
        ),
      );

      await store.start(_startCommand());
      expect(store.primaryRootNodeId, NodeId('1'));

      await store.loadPrimaryRootChildren(limit: 1);

      expect(repository.childrenQueries, hasLength(1));
      expect(repository.childrenQueries.single.limit, 1);
      expect(store.visibleRows, hasLength(1));
      expect(store.visibleRows.single.name, 'Caches');
      expect(store.viewport.nextCursor, isNull);
      expect(store.viewport.isStale, isFalse);
    },
  );

  test('expands nested tree nodes lazily and reuses loaded children', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );
    repository.childrenResponses.addAll([
      Result.success(
        NodePage(
          snapshotId: SnapshotId('2'),
          items: [
            _node(
              id: '10',
              name: 'Users',
              kind: NodeKind.directory,
              childCount: 1,
            ),
          ],
          nextCursor: null,
        ),
      ),
      Result.success(
        NodePage(
          snapshotId: SnapshotId('2'),
          items: [
            _node(
              id: '11',
              parentId: NodeId('10'),
              name: 'Library',
              kind: NodeKind.directory,
            ),
          ],
          nextCursor: null,
        ),
      ),
    ]);

    await store.start(_startCommand());
    await store.loadPrimaryRootChildren(limit: 100);

    expect(store.visibleTreeRows, hasLength(1));
    expect(store.visibleTreeRows.single.depth, 0);
    expect(store.visibleTreeRows.single.expanded, isFalse);

    await store.toggleTreeNode(NodeId('10'));

    expect(repository.childrenQueries, hasLength(2));
    expect(repository.childrenQueries.last.parentId, NodeId('10'));
    expect(store.visibleTreeRows, hasLength(2));
    expect(store.visibleTreeRows.last.depth, 1);
    expect(store.visibleTreeRows.first.expanded, isTrue);

    await store.toggleTreeNode(NodeId('10'));

    expect(store.visibleTreeRows, hasLength(1));

    await store.toggleTreeNode(NodeId('10'));

    expect(repository.childrenQueries, hasLength(2));
    expect(store.visibleTreeRows, hasLength(2));
  });

  test('loads more visible tree rows from the current cursor', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );
    repository.childrenResponses.addAll([
      Result.success(
        NodePage(
          snapshotId: SnapshotId('2'),
          items: [_node(id: '10', name: 'Caches')],
          nextCursor: OpaqueCursor('1'),
        ),
      ),
      Result.success(
        NodePage(
          snapshotId: SnapshotId('2'),
          items: [_node(id: '11', name: 'Logs')],
          nextCursor: null,
        ),
      ),
    ]);

    await store.start(_startCommand());
    await store.loadPrimaryRootChildren(limit: 1);

    expect(store.visibleTreeRows.map((row) => row.item.name), ['Caches']);
    expect(store.canLoadMoreVisibleTreeRows, isTrue);

    await store.loadMoreVisibleTreeRows();

    expect(repository.childrenQueries, hasLength(2));
    expect(repository.childrenQueries.last.cursor, OpaqueCursor('1'));
    expect(store.visibleTreeRows.map((row) => row.item.name), [
      'Caches',
      'Logs',
    ]);
    expect(store.canLoadMoreVisibleTreeRows, isFalse);
  });

  test('discards stale children page results after snapshot changes', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);
    final completer = Completer<Result<NodePage>>();

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );
    repository.childrenCompleter = completer;

    await store.start(_startCommand());
    final load = store.loadPrimaryRootChildren(limit: 100);

    store.reconcileEvent(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('42'),
        emittedAtUnixMs: BigInt.from(42),
        event: ScanSnapshotPublished(
          sessionId: ScanSessionId('1'),
          snapshotId: SnapshotId('3'),
        ),
      ),
    );
    completer.complete(
      Result.success(
        NodePage(
          snapshotId: SnapshotId('2'),
          items: [_node(id: '10', name: 'Stale')],
          nextCursor: null,
        ),
      ),
    );
    await load;

    expect(store.activeSnapshotId, SnapshotId('3'));
    expect(store.visibleRows, isEmpty);
    expect(store.pageLoadState, ScanPageLoadState.idle);
  });

  test('clears active snapshot while a new scan is pending', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );
    repository.childrenPage = Result.success(
      NodePage(
        snapshotId: SnapshotId('2'),
        items: [_node(id: '10', name: 'Apps')],
        nextCursor: null,
      ),
    );

    await store.start(_startCommand());
    await store.loadPrimaryRootChildren();
    expect(store.hasReadableSnapshot, isTrue);

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('3'),
        state: SessionState.running,
        snapshotId: null,
        rootNodeIds: const [],
        progress: null,
      ),
    );

    await store.start(_startCommand());

    expect(store.sessionId, ScanSessionId('3'));
    expect(store.activeSnapshotId, isNull);
    expect(store.hasReadableSnapshot, isFalse);
    expect(store.visibleRows, isEmpty);
    expect(store.viewport.isStale, isFalse);
  });

  test(
    'applies growing tree batches as partial non-authoritative rows',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      await store.start(_startCommand());

      store.reconcileEvent(
        ScanEventEnvelope(
          protocolVersion: ProtocolVersion.current,
          sequence: EventSequence('10'),
          emittedAtUnixMs: BigInt.from(10),
          event: ScanGrowingTreeBatch(
            sessionId: ScanSessionId('1'),
            scannedItems: BigInt.from(3),
            events: [
              GrowingNodeDiscovered(
                nodeId: PartialNodeId('1'),
                parentId: null,
                name: 'Macintosh HD',
                kind: NodeKind.directory,
              ),
              GrowingNodeDiscovered(
                nodeId: PartialNodeId('2'),
                parentId: PartialNodeId('1'),
                name: 'Users',
                kind: NodeKind.directory,
              ),
              GrowingNodeSizeUpdated(
                nodeId: PartialNodeId('2'),
                aggregateSize: SizeFact(
                  rawValue: '128',
                  quantity: MeasuredQuantity.apparentBytes,
                  byteEquivalent: '128',
                  confidence: SizeConfidence.low,
                ),
                state: GrowingNodeState.scanning,
              ),
            ],
          ),
        ),
      );

      expect(store.progress?.scannedItems, BigInt.from(3));
      expect(store.hasPartialScanTree, isTrue);
      expect(store.partialVisibleTreeRows.map((row) => row.item.name), [
        'Macintosh HD',
        'Users',
      ]);
      expect(store.partialVisibleTreeRows.last.depth, 1);
      expect(
        store.partialVisibleRows.last.aggregateSize.rawBigInt,
        BigInt.from(128),
      );
      expect(store.visibleRows, isEmpty);

      store.reconcileEvent(
        ScanEventEnvelope(
          protocolVersion: ProtocolVersion.current,
          sequence: EventSequence('11'),
          emittedAtUnixMs: BigInt.from(11),
          event: ScanSnapshotPublished(
            sessionId: ScanSessionId('1'),
            snapshotId: SnapshotId('2'),
          ),
        ),
      );

      expect(store.hasPartialScanTree, isFalse);
      expect(store.partialVisibleRows, isEmpty);
    },
  );

  test('keeps growing tree preview shallow while scan is running', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    await store.start(_startCommand());

    store.reconcileEvent(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('12'),
        emittedAtUnixMs: BigInt.from(12),
        event: ScanGrowingTreeBatch(
          sessionId: ScanSessionId('1'),
          scannedItems: BigInt.from(3),
          events: [
            GrowingNodeDiscovered(
              nodeId: PartialNodeId('1'),
              parentId: null,
              name: 'Macintosh HD',
              kind: NodeKind.directory,
            ),
            GrowingNodeDiscovered(
              nodeId: PartialNodeId('2'),
              parentId: PartialNodeId('1'),
              name: 'Users',
              kind: NodeKind.directory,
            ),
            GrowingNodeDiscovered(
              nodeId: PartialNodeId('3'),
              parentId: PartialNodeId('2'),
              name: 'belief',
              kind: NodeKind.directory,
            ),
          ],
        ),
      ),
    );

    expect(store.partialVisibleTreeRows.map((row) => row.item.name), [
      'Macintosh HD',
      'Users',
    ]);
    expect(store.partialVisibleTreeRows.map((row) => row.depth), [0, 1]);
  });

  test('caps growing tree preview rows during large running scans', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    await store.start(_startCommand());

    store.reconcileEvent(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('12'),
        emittedAtUnixMs: BigInt.from(12),
        event: ScanGrowingTreeBatch(
          sessionId: ScanSessionId('1'),
          scannedItems: BigInt.from(220),
          events: [
            GrowingNodeDiscovered(
              nodeId: PartialNodeId('1'),
              parentId: null,
              name: 'Library',
              kind: NodeKind.directory,
            ),
            for (var index = 2; index <= 220; index++)
              GrowingNodeDiscovered(
                nodeId: PartialNodeId('$index'),
                parentId: PartialNodeId('1'),
                name: 'Folder $index',
                kind: NodeKind.directory,
              ),
          ],
        ),
      ),
    );

    expect(store.hasPartialScanTree, isTrue);
    expect(store.partialVisibleTreeRows, hasLength(160));
    expect(store.partialVisibleRows, hasLength(160));
  });

  test(
    'disposes previous daemon session before starting replacement scan',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      await store.start(_startCommand());
      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('3'),
          state: SessionState.running,
          snapshotId: null,
          rootNodeIds: const [],
          progress: null,
        ),
      );

      await store.start(_startCommand());

      expect(repository.disposeCommands, hasLength(1));
      expect(repository.disposeCommands.single.sessionId, ScanSessionId('1'));
      expect(store.sessionId, ScanSessionId('3'));
    },
  );

  test('disposes active daemon session when store is disposed', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    await store.start(_startCommand());
    await store.dispose();

    expect(repository.disposeCommands, hasLength(1));
    expect(repository.disposeCommands.single.sessionId, ScanSessionId('1'));
  });

  test(
    'does not mark loaded rows stale for the same published snapshot',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      );
      repository.childrenPage = Result.success(
        NodePage(
          snapshotId: SnapshotId('2'),
          items: [_node(id: '10', name: 'Apps')],
          nextCursor: null,
        ),
      );

      await store.start(_startCommand());
      await store.loadPrimaryRootChildren();

      store.reconcileEvent(
        ScanEventEnvelope(
          protocolVersion: ProtocolVersion.current,
          sequence: EventSequence('43'),
          emittedAtUnixMs: BigInt.from(43),
          event: ScanSnapshotPublished(
            sessionId: ScanSessionId('1'),
            snapshotId: SnapshotId('2'),
          ),
        ),
      );

      expect(store.viewport.isStale, isFalse);
      expect(store.visibleRows.single.name, 'Apps');
    },
  );

  test('marks loaded rows stale when a newer snapshot is published', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );
    repository.childrenPage = Result.success(
      NodePage(
        snapshotId: SnapshotId('2'),
        items: [_node(id: '10', name: 'Apps')],
        nextCursor: null,
      ),
    );

    await store.start(_startCommand());
    await store.loadPrimaryRootChildren();

    store.reconcileEvent(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('44'),
        emittedAtUnixMs: BigInt.from(44),
        event: ScanSnapshotPublished(
          sessionId: ScanSessionId('1'),
          snapshotId: SnapshotId('3'),
        ),
      ),
    );

    expect(store.activeSnapshotId, SnapshotId('3'));
    expect(store.viewport.isStale, isTrue);
    expect(store.visibleRows.single.name, 'Apps');
  });

  test('waits for a readable snapshot through status polling', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.running,
        snapshotId: null,
        rootNodeIds: const [],
        progress: null,
      ),
    );
    repository.statusResponses.add(
      Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      ),
    );

    await store.start(_startCommand());
    final ready = await store.waitForReadableSnapshot(
      attempts: 1,
      pollDelay: Duration.zero,
    );

    expect(ready, isTrue);
    expect(store.hasReadableSnapshot, isTrue);
    expect(repository.statusRequestCount, 1);
  });

  test('stops waiting when status polling fails', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.running,
        snapshotId: null,
        rootNodeIds: const [],
        progress: null,
      ),
    );
    repository.statusResponses.add(
      const Result.failure(AppFailure.network(message: 'offline')),
    );

    await store.start(_startCommand());
    final ready = await store.waitForReadableSnapshot(
      attempts: 3,
      pollDelay: Duration.zero,
    );

    expect(ready, isFalse);
    expect(store.lastFailure, isA<NetworkFailure>());
    expect(repository.statusRequestCount, 1);
  });

  test('does not treat snapshot without root nodes as readable', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: const [],
        progress: null,
      ),
    );

    await store.start(_startCommand());

    expect(store.canQueryPages, isTrue);
    expect(store.hasReadableSnapshot, isFalse);
  });

  test('search and top items use application query ports', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );
    repository.childrenPage = Result.success(
      NodePage(
        snapshotId: SnapshotId('2'),
        items: [_node(id: '10', name: 'Caches')],
        nextCursor: null,
      ),
    );

    await store.start(_startCommand());
    await store.search('cache', limit: 25);
    await store.showTopItems(kind: TopItemsKind.directories, limit: 10);

    expect(repository.searchQueries.single.searchText, 'cache');
    expect(repository.searchQueries.single.limit, 25);
    expect(repository.topItemsQueries.single.kind, TopItemsKind.directories);
    expect(repository.topItemsQueries.single.limit, 10);
    expect(store.viewport.mode, ScanQueryMode.topItems);
  });

  test('disk usage map query respects daemon page size limit', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    await store.checkDaemonCompatibility();
    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );
    repository.childrenPage = Result.success(
      NodePage(
        snapshotId: SnapshotId('2'),
        items: [_node(id: '10', name: 'Library')],
        nextCursor: null,
      ),
    );

    await store.start(_startCommand());
    await store.loadDiskUsageMapRows(limit: 512);

    expect(repository.topItemsQueries.single.limit, 100);
    expect(store.diskUsageMapRows.single.nodeId, NodeId('10'));
  });

  test(
    'completed status without progress keeps last progress metrics',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.running,
          snapshotId: null,
          rootNodeIds: const [],
          progress: null,
        ),
      );
      await store.start(_startCommand());

      repository.statusResponses.add(
        Result.success(
          ScanSessionStatus(
            sessionId: ScanSessionId('1'),
            state: SessionState.running,
            snapshotId: null,
            rootNodeIds: const [],
            progress: ScanProgress(
              scannedItems: BigInt.from(42),
              elapsedMs: BigInt.from(1000),
              throughputBytesPerSec: BigInt.from(1024),
            ),
          ),
        ),
      );
      await store.refreshStatus();

      repository.statusResponses.add(
        Result.success(
          ScanSessionStatus(
            sessionId: ScanSessionId('1'),
            state: SessionState.completed,
            snapshotId: SnapshotId('2'),
            rootNodeIds: [NodeId('1')],
            progress: null,
          ),
        ),
      );
      await store.refreshStatus();

      expect(store.progress?.scannedItems, BigInt.from(42));
      expect(store.progress?.elapsedMs, BigInt.from(1000));
      expect(
        store.sessionStatus?.progress?.throughputBytesPerSec,
        BigInt.from(1024),
      );
    },
  );

  test(
    'search discards older result when a newer query wins the race',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      );
      repository.childrenPage = Result.success(
        NodePage(
          snapshotId: SnapshotId('2'),
          items: [_node(id: '1', name: 'Root')],
          nextCursor: null,
        ),
      );
      final slowAppSearch = Completer<Result<NodePage>>();
      final fastCacheSearch = Completer<Result<NodePage>>();
      repository.searchCompleters.addAll([slowAppSearch, fastCacheSearch]);

      await store.start(_startCommand());
      final appSearch = store.search('app');
      final cacheSearch = store.search('cache');

      expect(repository.searchQueries.map((query) => query.searchText), [
        'app',
        'cache',
      ]);

      fastCacheSearch.complete(
        Result.success(
          NodePage(
            snapshotId: SnapshotId('2'),
            items: [_node(id: '20', name: 'Cache result')],
            nextCursor: null,
          ),
        ),
      );
      await cacheSearch;

      expect(store.viewport.searchText, 'cache');
      expect(store.visibleRows.single.name, 'Cache result');

      slowAppSearch.complete(
        Result.success(
          NodePage(
            snapshotId: SnapshotId('2'),
            items: [_node(id: '10', name: 'Old app result')],
            nextCursor: null,
          ),
        ),
      );
      await appSearch;

      expect(store.viewport.searchText, 'cache');
      expect(store.visibleRows.single.name, 'Cache result');
    },
  );

  test('delete queue is presentation intent separate from selection', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);
    repository.capabilities = Result.success(
      _capabilities(
        version: ProtocolVersion.current,
        runtimeProof: _verifiedRuntimeProof(),
      ),
    );

    await store.checkDaemonCompatibility();
    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );

    await store.start(_startCommand());
    await store.selectNode(NodeId('10'));
    store.queueSelectedNode();

    expect(store.selectedNodeId, NodeId('10'));
    expect(store.queuedItems.single.nodeId, NodeId('10'));
    expect(store.queuedItems.single.snapshotId, SnapshotId('2'));
    expect(store.queuedBytes, BigInt.from(10));
    expect(store.deletePlan.canAuthorizeCleanup, isTrue);

    store.removeQueuedNode(NodeId('10'));

    expect(store.selectedNodeId, NodeId('10'));
    expect(store.queuedItems, isEmpty);
  });

  test(
    'cleanup preview blocks stale snapshot refs after publication',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);
      repository.capabilities = Result.success(
        _capabilities(
          version: ProtocolVersion.current,
          runtimeProof: _verifiedRuntimeProof(),
        ),
      );

      await store.checkDaemonCompatibility();
      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      );

      await store.start(_startCommand());
      await store.selectNode(NodeId('10'));
      store.queueSelectedNode();

      expect(store.deletePlan.items.single.states, isEmpty);

      store.reconcileEvent(
        ScanEventEnvelope(
          protocolVersion: ProtocolVersion.current,
          sequence: EventSequence('1'),
          emittedAtUnixMs: BigInt.from(1700000000001),
          event: ScanSnapshotPublished(
            sessionId: ScanSessionId('1'),
            snapshotId: SnapshotId('3'),
          ),
        ),
      );

      expect(
        store.deletePlan.items.single.states,
        contains(DeletePlanItemState.staleSnapshot),
      );
    },
  );

  test(
    'cleanup preview revalidates permission and blocks missing access',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);
      repository.capabilities = Result.success(
        _capabilities(
          version: ProtocolVersion.current,
          runtimeProof: _verifiedRuntimeProof(),
        ),
      );

      await store.checkDaemonCompatibility();
      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      );
      repository.permissionProbe = Result.success(
        PermissionProbe(
          status: PermissionProbeStatus.denied,
          checkedAtUnixMs: BigInt.from(1700000000002),
          requiredAction: PermissionRequiredAction.openMacosFullDiskAccess,
        ),
      );

      await store.start(_startCommand());
      await store.selectNode(NodeId('10'));
      store.queueSelectedNode();
      await store.refreshCleanupPreview(_startCommand().targets.single);

      expect(repository.permissionProbeTargets.single.path.value, '/tmp');
      expect(
        store.deletePlan.items.single.states,
        contains(DeletePlanItemState.missingPermission),
      );
    },
  );

  test('cleanup preview marks changed metadata and unknown reclaim', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);
    repository.capabilities = Result.success(
      _capabilities(
        version: ProtocolVersion.current,
        runtimeProof: _verifiedRuntimeProof(),
      ),
    );

    await store.checkDaemonCompatibility();
    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );

    await store.start(_startCommand());
    store.queueNode(
      _node(
        id: '10',
        name: 'Queued',
        byteEquivalent: null,
        confidence: SizeConfidence.unknown,
      ),
    );
    repository.childrenPage = Result.success(
      NodePage(
        snapshotId: SnapshotId('2'),
        items: [_node(id: '10', name: 'Changed', rawValue: '20')],
        nextCursor: null,
      ),
    );

    await store.loadPrimaryRootChildren();

    expect(
      store.deletePlan.items.single.states,
      containsAll([
        DeletePlanItemState.changedMetadata,
        DeletePlanItemState.unknownReclaim,
      ]),
    );
  });

  test(
    'cleanup preview records policy conflicts without side effects',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);
      repository.capabilities = Result.success(
        _capabilities(
          version: ProtocolVersion.current,
          runtimeProof: _verifiedRuntimeProof(),
        ),
      );
      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      );

      await store.checkDaemonCompatibility();
      await store.start(_startCommand());
      store.queueNode(
        _node(
          id: '10',
          name: 'System',
          flags: const NodeFlags(
            hidden: false,
            system: true,
            package: false,
            symlink: false,
          ),
        ),
      );

      expect(
        store.deletePlan.items.single.states,
        contains(DeletePlanItemState.policyConflict),
      );
      expect(store.deletePlan.canAuthorizeCleanup, isFalse);
    },
  );

  test('cleanup execution requires server plan and records receipt', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);
    repository.capabilities = Result.success(
      _capabilities(
        version: ProtocolVersion.current,
        runtimeProof: _verifiedRuntimeProof(),
      ),
    );
    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );

    await store.checkDaemonCompatibility();
    await store.start(_startCommand());
    store.queueNode(_node(id: '10', name: 'alpha.log'));
    await store.prepareCleanupPlan(
      commandId: CommandId('76'),
      target: _startCommand().targets.single,
    );
    await store.executeCleanup(CommandId('77'));

    expect(repository.cleanupPlanCommands.single.commandId, CommandId('76'));
    expect(
      repository.cleanupPlanCommands.single.items.single.sessionId,
      ScanSessionId('1'),
    );
    expect(
      repository.cleanupPlanCommands.single.items.single.snapshotId,
      SnapshotId('2'),
    );
    expect(
      repository.cleanupPlanCommands.single.items.single.nodeId,
      NodeId('10'),
    );
    expect(
      repository.cleanupPlanExecuteCommands.single.commandId,
      CommandId('77'),
    );
    expect(
      repository.cleanupPlanExecuteCommands.single.planId,
      CleanupPlanId('55'),
    );
    expect(store.cleanupReceipt?.state, CleanupReceiptState.completed);
    expect(
      store.cleanupReceipt?.items.single.state,
      CleanupItemOutcomeState.movedToTrash,
    );
    expect(store.queuedItems, isEmpty);
    expect(store.isMovedToTrash(NodeId('10')), isTrue);

    store.queueNode(_node(id: '10', name: 'alpha.log'));

    expect(store.queuedItems, isEmpty);
    expect(store.lastFailure?.message, 'Node was already moved to Trash');
  });

  test(
    'cleanup execution fails closed without a prepared server plan',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);
      repository.capabilities = Result.success(
        _capabilities(
          version: ProtocolVersion.current,
          runtimeProof: _verifiedRuntimeProof(),
        ),
      );
      repository.startStatus = Result.success(
        ScanSessionStatus(
          sessionId: ScanSessionId('1'),
          state: SessionState.completed,
          snapshotId: SnapshotId('2'),
          rootNodeIds: [NodeId('1')],
          progress: null,
        ),
      );

      await store.checkDaemonCompatibility();
      await store.start(_startCommand());
      store.queueNode(_node(id: '10', name: 'alpha.log'));
      await store.executeCleanup(CommandId('77'));

      expect(repository.cleanupPlanExecuteCommands, isEmpty);
      expect(
        store.lastFailure?.message,
        'Cleanup plan must be validated before execution',
      );
    },
  );

  test('server blocked cleanup plan is not executable', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);
    repository.capabilities = Result.success(
      _capabilities(
        version: ProtocolVersion.current,
        runtimeProof: _verifiedRuntimeProof(),
      ),
    );
    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );
    repository.cleanupPlanResult = Result.success(
      ValidatedCleanupPlan(
        planId: CleanupPlanId('56'),
        commandId: CommandId('76'),
        state: ValidatedCleanupPlanState.blocked,
        items: [
          ValidatedCleanupPlanItem(
            itemRef: CleanupPlanItemRef(
              sessionId: ScanSessionId('1'),
              snapshotId: SnapshotId('2'),
              nodeId: NodeId('10'),
            ),
            displayName: 'alpha.log',
            state: ValidatedCleanupPlanItemState.blocked,
            reason: 'stale file identity',
          ),
        ],
      ),
    );

    await store.checkDaemonCompatibility();
    await store.start(_startCommand());
    store.queueNode(_node(id: '10', name: 'alpha.log'));
    final plan = await store.prepareCleanupPlan(
      commandId: CommandId('76'),
      target: _startCommand().targets.single,
    );

    expect(plan, isNull);
    expect(repository.cleanupPlanCommands, hasLength(1));
    expect(store.validatedCleanupPlan?.planId, CleanupPlanId('56'));
    expect(store.lastFailure?.message, 'stale file identity');
  });

  test('late progress events do not regress a completed session', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);
    repository.startStatus = Result.success(
      ScanSessionStatus(
        sessionId: ScanSessionId('1'),
        state: SessionState.completed,
        snapshotId: SnapshotId('2'),
        rootNodeIds: [NodeId('1')],
        progress: null,
      ),
    );

    await store.start(_startCommand());
    store.reconcileEvent(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('9'),
        emittedAtUnixMs: BigInt.from(1700000000009),
        event: ScanProgressed(
          sessionId: ScanSessionId('1'),
          progress: ScanProgress(
            scannedItems: BigInt.from(42),
            elapsedMs: BigInt.from(1000),
            throughputBytesPerSec: BigInt.from(1024),
          ),
        ),
      ),
    );

    expect(store.sessionStatus?.state, SessionState.completed);
    expect(store.activeSnapshotId, SnapshotId('2'));
  });

  test('ignores replayed stream events before a session is active', () async {
    final repository = _FakeScanRepository();
    final eventClient = _FakeScanEventClient();
    final store = _store(repository, eventClient);

    await store.connectEvents();
    eventClient.add(
      Result.success(
        ScanEventEnvelope(
          protocolVersion: ProtocolVersion.current,
          sequence: EventSequence('1'),
          emittedAtUnixMs: BigInt.from(1),
          event: ScanStarted(sessionId: ScanSessionId('7')),
        ),
      ),
    );
    eventClient.add(
      Result.success(
        ScanEventEnvelope(
          protocolVersion: ProtocolVersion.current,
          sequence: EventSequence('2'),
          emittedAtUnixMs: BigInt.from(2),
          event: ScanSnapshotPublished(
            sessionId: ScanSessionId('7'),
            snapshotId: SnapshotId('8'),
          ),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(store.sessionId, isNull);
    expect(store.activeSnapshotId, isNull);
    expect(store.viewport.isStale, isFalse);

    await store.dispose();
  });

  test(
    'reconciles current stream events as hints without marking empty viewport stale',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      await store.connectEvents();
      await store.start(_startCommand());
      eventClient.add(
        Result.success(
          ScanEventEnvelope(
            protocolVersion: ProtocolVersion.current,
            sequence: EventSequence('1'),
            emittedAtUnixMs: BigInt.from(1),
            event: ScanStarted(sessionId: ScanSessionId('1')),
          ),
        ),
      );
      eventClient.add(
        Result.success(
          ScanEventEnvelope(
            protocolVersion: ProtocolVersion.current,
            sequence: EventSequence('2'),
            emittedAtUnixMs: BigInt.from(2),
            event: ScanProgressed(
              sessionId: ScanSessionId('1'),
              progress: ScanProgress(scannedItems: BigInt.from(42)),
            ),
          ),
        ),
      );
      eventClient.add(
        Result.success(
          ScanEventEnvelope(
            protocolVersion: ProtocolVersion.current,
            sequence: EventSequence('3'),
            emittedAtUnixMs: BigInt.from(3),
            event: ScanSnapshotPublished(
              sessionId: ScanSessionId('1'),
              snapshotId: SnapshotId('8'),
            ),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.sessionId?.value, '1');
      expect(store.progress?.scannedItems, BigInt.from(42));
      expect(store.activeSnapshotId?.value, '8');
      expect(store.viewport.isStale, isFalse);

      await store.dispose();
    },
  );

  test(
    'refreshes authoritative status when stream sequence has a gap',
    () async {
      final repository = _FakeScanRepository();
      final eventClient = _FakeScanEventClient();
      final store = _store(repository, eventClient);

      repository.statusResponses.add(
        Result.success(
          ScanSessionStatus(
            sessionId: ScanSessionId('1'),
            state: SessionState.completed,
            snapshotId: SnapshotId('9'),
            rootNodeIds: [NodeId('1')],
            progress: ScanProgress(scannedItems: BigInt.from(200)),
          ),
        ),
      );

      await store.connectEvents();
      await store.start(_startCommand());
      eventClient.add(
        Result.success(
          ScanEventEnvelope(
            protocolVersion: ProtocolVersion.current,
            sequence: EventSequence('1'),
            emittedAtUnixMs: BigInt.from(1),
            event: ScanProgressed(
              sessionId: ScanSessionId('1'),
              progress: ScanProgress(scannedItems: BigInt.from(100)),
            ),
          ),
        ),
      );
      eventClient.add(
        Result.success(
          ScanEventEnvelope(
            protocolVersion: ProtocolVersion.current,
            sequence: EventSequence('3'),
            emittedAtUnixMs: BigInt.from(3),
            event: ScanProgressed(
              sessionId: ScanSessionId('1'),
              progress: ScanProgress(scannedItems: BigInt.from(150)),
            ),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.statusRequestCount, 1);
      expect(store.sessionStatus?.state, SessionState.completed);
      expect(store.activeSnapshotId, SnapshotId('9'));

      await store.dispose();
    },
  );
}

ScanWorkspaceStore _store(
  _FakeScanRepository repository,
  _FakeScanEventClient eventClient, {
  PermissionRepairLauncher? permissionRepairLauncher,
  ScanTargetCatalog? targetCatalog,
  ScanTargetPreferenceStore? targetPreferenceStore,
  PathRevealer? pathRevealer,
}) {
  return ScanWorkspaceStore(
    getCapabilities: GetCapabilitiesUseCase(repository),
    probePermission: ProbePermissionUseCase(repository),
    launchPermissionRepair: permissionRepairLauncher == null
        ? null
        : LaunchPermissionRepairUseCase(permissionRepairLauncher),
    listScanTargetChoices: targetCatalog == null
        ? null
        : ListScanTargetChoicesUseCase(targetCatalog),
    loadLastScanTarget: targetPreferenceStore == null
        ? null
        : LoadLastScanTargetUseCase(targetPreferenceStore),
    saveLastScanTarget: targetPreferenceStore == null
        ? null
        : SaveLastScanTargetUseCase(targetPreferenceStore),
    revealPath: pathRevealer == null ? null : RevealPathUseCase(pathRevealer),
    startScan: StartScanUseCase(repository),
    cancelScan: CancelScanUseCase(repository),
    disposeScan: DisposeScanUseCase(repository),
    getScanStatus: GetScanStatusUseCase(repository),
    getChildrenPage: GetChildrenPageUseCase(repository),
    searchNodes: SearchNodesUseCase(repository),
    getTopItems: GetTopItemsUseCase(repository),
    getNodeDetails: GetNodeDetailsUseCase(repository),
    createCleanupPlan: CreateCleanupPlanUseCase(repository),
    executeCleanupPlan: ExecuteCleanupPlanUseCase(repository),
    getCleanupRecoveryInbox: GetCleanupRecoveryInboxUseCase(repository),
    watchScanEvents: WatchScanEventsUseCase(eventClient),
  );
}

ScanTarget _scanTarget(String path) {
  return ScanTarget(
    path: ScanTargetPath(path),
    scope: TargetScope.localPath,
    boundaryPolicy: BoundaryPolicy.stayOnInitialFilesystem,
    hardlinkPolicy: HardlinkPolicy.ignore,
  );
}

StartScanCommand _startCommand() {
  return StartScanCommand(
    commandId: CommandId('99'),
    targets: [
      ScanTarget(
        path: ScanTargetPath('/tmp'),
        scope: TargetScope.localPath,
        boundaryPolicy: BoundaryPolicy.crossFilesystems,
        hardlinkPolicy: HardlinkPolicy.ignore,
      ),
    ],
    measurement: MeasuredQuantity.apparentBytes,
    mode: ScanMode.balanced,
  );
}

DaemonCapabilities _capabilities({
  required ProtocolVersion version,
  RuntimeProof runtimeProof = RuntimeProof.unknown,
}) {
  return DaemonCapabilities(
    protocolVersion: version,
    scanner: const ScannerCapability(
      backendName: 'fake',
      capabilities: CapabilitySet(
        hardlinks: SupportLevel.supported,
        filesystemBoundary: SupportLevel.supported,
        cooperativeCancellation: SupportLevel.supported,
        metadataEnrichment: SupportLevel.supported,
        growingTreeStreaming: SupportLevel.supported,
      ),
    ),
    limits: const ProtocolLimits(maxPageSize: 100, maxEventQueueItems: 100),
    runtimeProof: runtimeProof,
  );
}

RuntimeProof _verifiedRuntimeProof() {
  return RuntimeProof.unknown.copyWith(
    permissionProbe: PermissionProbe(
      status: PermissionProbeStatus.verified,
      checkedAtUnixMs: BigInt.from(1700000000000),
      requiredAction: PermissionRequiredAction.none,
    ),
  );
}

NodePageItem _node({
  required String id,
  required String name,
  NodeId? parentId,
  String rawValue = '10',
  String? byteEquivalent = '10',
  SizeConfidence confidence = SizeConfidence.high,
  NodeKind kind = NodeKind.file,
  NodeFlags flags = const NodeFlags(
    hidden: false,
    system: false,
    package: false,
    symlink: false,
  ),
  ChildCompleteness childCompleteness = ChildCompleteness.complete,
  int childCount = 0,
  int issueCount = 0,
  int subtreeIssueCount = 0,
}) {
  return NodePageItem(
    nodeId: NodeId(id),
    parentId: parentId ?? NodeId('1'),
    name: name,
    kind: kind,
    size: SizeFact(
      rawValue: rawValue,
      quantity: MeasuredQuantity.apparentBytes,
      byteEquivalent: byteEquivalent,
      confidence: confidence,
    ),
    flags: flags,
    childCompleteness: childCompleteness,
    childCount: childCount,
    issueCount: issueCount,
    subtreeIssueCount: subtreeIssueCount,
  );
}

final class _FakeScanEventClient implements ScanEventClient {
  final StreamController<Result<ScanEventEnvelope>> _controller =
      StreamController.broadcast();

  @override
  Stream<Result<ScanEventEnvelope>> watchEvents() => _controller.stream;

  void add(Result<ScanEventEnvelope> event) => _controller.add(event);
}

final class _FakePermissionRepairLauncher implements PermissionRepairLauncher {
  final List<ScanTarget> targets = [];
  final List<RuntimeProof> proofs = [];
  Result<Unit> result = const Result.success(Unit.value);

  @override
  Future<Result<Unit>> launchPermissionRepair({
    required ScanTarget target,
    required RuntimeProof proof,
  }) async {
    targets.add(target);
    proofs.add(proof);
    return result;
  }
}

final class _FakeScanTargetCatalog implements ScanTargetCatalog {
  const _FakeScanTargetCatalog(this.choices);

  final List<ScanTargetChoice> choices;

  @override
  Future<Result<List<ScanTargetChoice>>> listChoices() async {
    return Result.success(choices);
  }
}

final class _FakeScanTargetPreferenceStore
    implements ScanTargetPreferenceStore {
  _FakeScanTargetPreferenceStore(this.target);

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

final class _FakePathRevealer implements PathRevealer {
  _FakePathRevealer(this.result);

  Result<Unit> result;
  final List<ScanTargetPath> paths = [];

  @override
  Future<Result<Unit>> revealPath(ScanTargetPath path) async {
    paths.add(path);
    return result;
  }
}

final class _FakeScanRepository implements ScanRepository {
  Result<DaemonCapabilities> capabilities = Result.success(
    _capabilities(version: ProtocolVersion.current),
  );
  final List<Result<DaemonCapabilities>> capabilityResponses = [];
  var capabilityRequestCount = 0;
  Result<DaemonDiagnostics> diagnostics = Result.success(
    DaemonDiagnostics(
      protocolVersion: ProtocolVersion.current,
      activeSessions: 0,
      runningSessions: 0,
      completedSessions: 0,
      cancelRequestedSessions: 0,
      bufferedEvents: 0,
      storedCursors: 0,
      authRequired: true,
    ),
  );
  Result<PermissionProbe> permissionProbe = Result.success(
    PermissionProbe(
      status: PermissionProbeStatus.verified,
      checkedAtUnixMs: BigInt.from(1700000000000),
      requiredAction: PermissionRequiredAction.none,
    ),
  );
  Result<ScanSessionStatus> startStatus = Result.success(
    ScanSessionStatus(
      sessionId: ScanSessionId('1'),
      state: SessionState.running,
      snapshotId: null,
      rootNodeIds: const [],
      progress: null,
    ),
  );
  Result<NodePage> childrenPage = Result.success(
    NodePage(snapshotId: SnapshotId('1'), items: const [], nextCursor: null),
  );
  final List<Result<NodePage>> childrenResponses = [];
  Completer<Result<NodePage>>? childrenCompleter;
  final List<Result<ScanSessionStatus>> statusResponses = [];
  final List<ChildrenPageQuery> childrenQueries = [];
  final List<SearchPageQuery> searchQueries = [];
  final List<Completer<Result<NodePage>>> searchCompleters = [];
  final List<TopItemsQuery> topItemsQueries = [];
  final List<ScanTarget> permissionProbeTargets = [];
  final List<CreateCleanupPlanCommand> cleanupPlanCommands = [];
  final List<ExecuteCleanupPlanCommand> cleanupPlanExecuteCommands = [];
  final List<SessionCommand> disposeCommands = [];
  final Map<CleanupPlanId, List<CleanupPlanItemRef>> cleanupPlanItemsById = {};
  Result<ValidatedCleanupPlan>? cleanupPlanResult;
  Result<CleanupRecoveryInbox> recoveryInbox = const Result.success(
    CleanupRecoveryInbox(interruptedReceipts: []),
  );
  var statusRequestCount = 0;

  @override
  Future<Result<DaemonCapabilities>> getCapabilities() async {
    capabilityRequestCount += 1;
    if (capabilityResponses.isNotEmpty) {
      return capabilityResponses.removeAt(0);
    }
    return capabilities;
  }

  @override
  Future<Result<DaemonDiagnostics>> getDiagnostics() async => diagnostics;

  @override
  Future<Result<PermissionProbe>> probePermission(ScanTarget target) async {
    permissionProbeTargets.add(target);
    return permissionProbe;
  }

  @override
  Future<Result<ScanSessionStatus>> startScan(StartScanCommand command) async {
    return startStatus;
  }

  @override
  Future<Result<ScanSessionStatus>> getSessionStatus(
    ScanSessionId sessionId,
  ) async {
    statusRequestCount += 1;
    if (statusResponses.isNotEmpty) {
      return statusResponses.removeAt(0);
    }
    return startStatus;
  }

  @override
  Future<Result<ScanSessionStatus>> cancelScan(SessionCommand command) async {
    return startStatus;
  }

  @override
  Future<Result<Unit>> disposeScan(SessionCommand command) async {
    disposeCommands.add(command);
    return const Result.success(Unit.value);
  }

  @override
  Future<Result<NodePage>> getChildrenPage(ChildrenPageQuery query) async {
    childrenQueries.add(query);
    final completer = childrenCompleter;
    if (completer != null) {
      childrenCompleter = null;
      return completer.future;
    }
    if (childrenResponses.isNotEmpty) {
      return childrenResponses.removeAt(0);
    }
    return childrenPage;
  }

  @override
  Future<Result<NodePage>> search(SearchPageQuery query) async {
    searchQueries.add(query);
    if (searchCompleters.isNotEmpty) {
      return searchCompleters.removeAt(0).future;
    }
    return childrenPage;
  }

  @override
  Future<Result<NodePage>> getTopItems(TopItemsQuery query) async {
    topItemsQueries.add(query);
    return childrenPage;
  }

  @override
  Future<Result<NodeDetails>> getNodeDetails(NodeDetailsQuery query) async {
    return Result.success(
      NodeDetails(
        snapshotId: query.snapshotId,
        summary: _node(id: query.nodeId.value, name: 'Details'),
        timestamps: NodeTimestamps(
          createdAtUnixMs: BigInt.from(1704103200000),
          modifiedAtUnixMs: BigInt.from(1704195900000),
        ),
        childIds: const [],
        issues: const [],
      ),
    );
  }

  @override
  Future<Result<ValidatedCleanupPlan>> createCleanupPlan(
    CreateCleanupPlanCommand command,
  ) async {
    cleanupPlanCommands.add(command);
    final forced = cleanupPlanResult;
    if (forced != null) {
      return forced;
    }
    final planId = CleanupPlanId('55');
    cleanupPlanItemsById[planId] = List.unmodifiable(command.items);
    return Result.success(
      ValidatedCleanupPlan(
        planId: planId,
        commandId: command.commandId,
        state: ValidatedCleanupPlanState.ready,
        items: command.items
            .map(
              (item) => ValidatedCleanupPlanItem(
                itemRef: item,
                displayName: item.nodeId.value,
                state: ValidatedCleanupPlanItemState.ready,
                reason: null,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<Result<CleanupReceipt>> executeCleanupPlan(
    ExecuteCleanupPlanCommand command,
  ) async {
    cleanupPlanExecuteCommands.add(command);
    final items = cleanupPlanItemsById[command.planId] ?? const [];
    return Result.success(
      CleanupReceipt(
        operationId: command.commandId,
        commandId: command.commandId,
        state: CleanupReceiptState.completed,
        lowDiskReserveReady: true,
        items: items
            .map(
              (item) => CleanupReceiptItem(
                nodeId: item.nodeId,
                displayName: item.nodeId.value,
                state: CleanupItemOutcomeState.movedToTrash,
                restoreExpectation: RestoreExpectationLevel.platformTrashManual,
                reason: null,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<Result<CleanupRecoveryInbox>> getCleanupRecoveryInbox() async {
    return recoveryInbox;
  }
}

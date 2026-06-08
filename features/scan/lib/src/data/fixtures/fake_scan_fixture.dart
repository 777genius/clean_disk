import 'dart:async';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_event_client.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class FakeScanFeatureFixture {
  FakeScanFeatureFixture({
    FakeScanRepository? repository,
    FakeScanEventClient? eventClient,
  }) : eventClient = eventClient ?? FakeScanEventClient(),
       repository = repository ?? FakeScanRepository() {
    this.repository.eventSink ??= this.eventClient.add;
  }

  final FakeScanRepository repository;
  final FakeScanEventClient eventClient;
}

final class FakeScanEventClient implements ScanEventClient {
  FakeScanEventClient();

  final StreamController<Result<ScanEventEnvelope>> _controller =
      StreamController<Result<ScanEventEnvelope>>.broadcast(sync: true);

  void add(ScanEventEnvelope envelope) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(Result.success(envelope));
  }

  void addFailure(AppFailure failure) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(Result.failure(failure));
  }

  Future<void> close() {
    return _controller.close();
  }

  @override
  Stream<Result<ScanEventEnvelope>> watchEvents() {
    return _controller.stream;
  }
}

const _defaultCapabilities = DaemonCapabilities(
  protocolVersion: ProtocolVersion.current,
  scanner: ScannerCapability(
    backendName: 'fake-scan-fixture',
    capabilities: CapabilitySet(
      hardlinks: SupportLevel.supported,
      filesystemBoundary: SupportLevel.supported,
      cooperativeCancellation: SupportLevel.supported,
      metadataEnrichment: SupportLevel.supported,
      growingTreeStreaming: SupportLevel.supported,
    ),
  ),
  limits: ProtocolLimits(maxPageSize: 500, maxEventQueueItems: 1024),
  runtimeProof: RuntimeProof(
    scannerIdentity: ScannerIdentityProof(
      platform: RuntimePlatform.macos,
      processKind: ScannerProcessKind.currentProcess,
      verification: ScannerIdentityVerification.unverified,
      executablePath: null,
      bundleIdentifier: null,
    ),
    permissionProbe: PermissionProbe(
      status: PermissionProbeStatus.notProbed,
      checkedAtUnixMs: null,
      requiredAction: PermissionRequiredAction.none,
    ),
    packaging: PackagingProof(
      distributionChannel: DistributionChannel.development,
      packageMode: PackageMode.developmentShell,
      sandboxed: false,
      signedBuild: false,
      debugBuild: true,
      scannerProcess: ScannerProcessKind.currentProcess,
      limitations: ['unsigned_build', 'development_shell'],
      updateSafety: UpdateSafety(
        quiesceRequiredBeforeUpdate: true,
        rollbackSupported: SupportLevel.unknown,
        receiptPreservation: SupportLevel.supported,
      ),
    ),
  ),
);

final _defaultPermissionProbe = PermissionProbe(
  status: PermissionProbeStatus.verified,
  checkedAtUnixMs: BigInt.from(1700000000000),
  requiredAction: PermissionRequiredAction.none,
);

final class FakeScanRepository implements ScanRepository {
  FakeScanRepository({this.eventSink}) {
    _nodes = _FakeScanTree.sample().nodes;
  }

  static final sessionId = ScanSessionId('1');
  static final snapshotId = SnapshotId('100');
  static final rootNodeId = NodeId('1');
  static final usersNodeId = NodeId('2');
  static final homeNodeId = NodeId('3');
  static final libraryNodeId = NodeId('4');
  static final cachesNodeId = NodeId('5');
  static final appSupportNodeId = NodeId('6');
  static final downloadsNodeId = NodeId('7');
  static final applicationsNodeId = NodeId('8');
  static final systemNodeId = NodeId('9');

  void Function(ScanEventEnvelope envelope)? eventSink;

  late final Map<NodeId, _FakeNode> _nodes;
  ScanSessionStatus? _status;
  StartScanCommand? lastStartCommand;
  bool deferStartCompletion = false;
  DaemonCapabilities capabilities = _defaultCapabilities;
  PermissionProbe permissionProbe = _defaultPermissionProbe;
  final List<ScanTarget> permissionProbeTargets = [];
  final List<SearchPageQuery> searchQueries = [];
  final Map<CleanupPlanId, List<CleanupPlanItemRef>> _cleanupPlanItemsById = {};
  int _eventSequence = 0;
  int _scanSequence = 0;
  ScanSessionId _currentSessionId = sessionId;
  SnapshotId _currentSnapshotId = snapshotId;
  NodeId _currentRootNodeId = rootNodeId;
  CleanupReceipt? lastCleanupReceipt;

  void renameNodeForTesting(NodeId id, String name) {
    final node = _nodes[id];
    if (node == null) {
      return;
    }
    _nodes[id] = node.copyWith(name: name);
  }

  @override
  Future<Result<DaemonCapabilities>> getCapabilities() async {
    return Result.success(capabilities);
  }

  @override
  Future<Result<PermissionProbe>> probePermission(ScanTarget target) async {
    permissionProbeTargets.add(target);
    return Result.success(permissionProbe);
  }

  @override
  Future<Result<DaemonDiagnostics>> getDiagnostics() async {
    final status = _status;
    return Result.success(
      DaemonDiagnostics(
        protocolVersion: ProtocolVersion.current,
        activeSessions: status == null ? 0 : 1,
        runningSessions: status?.state == SessionState.running ? 1 : 0,
        completedSessions: status?.state == SessionState.completed ? 1 : 0,
        cancelRequestedSessions: status?.state == SessionState.canceled ? 1 : 0,
        bufferedEvents: 0,
        storedCursors: 0,
        authRequired: false,
      ),
    );
  }

  @override
  Future<Result<ScanSessionStatus>> startScan(StartScanCommand command) async {
    lastStartCommand = command;
    _scanSequence += 1;
    _currentSessionId = ScanSessionId('$_scanSequence');
    _currentSnapshotId = SnapshotId('${99 + _scanSequence}');
    _currentRootNodeId = _rootNodeForTarget(
      command.targets.isEmpty ? null : command.targets.first,
    );
    final visibleNodeCount = _subtreeNodeIds(_currentRootNodeId).length;
    final progress = ScanProgress(
      scannedItems: BigInt.from(visibleNodeCount),
      elapsedMs: BigInt.from(42),
      throughputBytesPerSec: BigInt.from(1024 * 1024 * 128),
    );
    final completed = ScanSessionStatus(
      sessionId: _currentSessionId,
      state: SessionState.completed,
      snapshotId: _currentSnapshotId,
      rootNodeIds: [_currentRootNodeId],
      progress: progress,
    );
    _status = completed;

    _emit(ScanStarted(sessionId: _currentSessionId));
    _emitGrowingTreeBatch();
    _emit(ScanProgressed(sessionId: _currentSessionId, progress: progress));
    _emit(
      ScanSnapshotPublished(
        sessionId: _currentSessionId,
        snapshotId: _currentSnapshotId,
      ),
    );

    if (deferStartCompletion) {
      return Result.success(
        ScanSessionStatus(
          sessionId: _currentSessionId,
          state: SessionState.running,
          snapshotId: null,
          rootNodeIds: [_currentRootNodeId],
          progress: null,
        ),
      );
    }

    return Result.success(completed);
  }

  @override
  Future<Result<ScanSessionStatus>> getSessionStatus(
    ScanSessionId sessionId,
  ) async {
    final failure = _validateSession(sessionId);
    if (failure != null) {
      return Result.failure(failure);
    }
    return Result.success(_status!);
  }

  @override
  Future<Result<ScanSessionStatus>> cancelScan(SessionCommand command) async {
    final failure = _validateSession(command.sessionId);
    if (failure != null) {
      return Result.failure(failure);
    }

    final canceled = ScanSessionStatus(
      sessionId: command.sessionId,
      state: SessionState.canceled,
      snapshotId: _status?.snapshotId,
      rootNodeIds: _status?.rootNodeIds ?? const [],
      progress: _status?.progress,
    );
    _status = canceled;
    _emit(ScanCanceled(sessionId: command.sessionId));
    return Result.success(canceled);
  }

  @override
  Future<Result<Unit>> disposeScan(SessionCommand command) async {
    final failure = _validateSession(command.sessionId);
    if (failure != null) {
      return Result.failure(failure);
    }
    _status = null;
    return const Result.success(Unit.value);
  }

  @override
  Future<Result<NodePage>> getChildrenPage(ChildrenPageQuery query) async {
    final failure = _validatePublishedSnapshot(
      query.sessionId,
      query.snapshotId,
    );
    if (failure != null) {
      return Result.failure(failure);
    }

    final parent = _nodes[query.parentId];
    if (parent == null) {
      return Result.failure(
        AppFailure.validation(
          message: 'Node not found',
          field: query.parentId.value,
        ),
      );
    }

    final children = parent.childIds.map((id) => _nodes[id]).nonNulls.toList();
    _sortNodes(children, query.sort);
    return _pageFromNodes(
      nodes: children,
      cursor: query.cursor,
      limit: query.limit,
    );
  }

  @override
  Future<Result<NodePage>> search(SearchPageQuery query) async {
    searchQueries.add(query);
    final failure = _validatePublishedSnapshot(
      query.sessionId,
      query.snapshotId,
    );
    if (failure != null) {
      return Result.failure(failure);
    }

    final allowedNodeIds = _subtreeNodeIds(_currentRootNodeId);
    final text = query.searchText.toLowerCase();
    final matches =
        _nodes.values
            .where(
              (node) =>
                  allowedNodeIds.contains(node.id) &&
                  node.name.toLowerCase().contains(text),
            )
            .toList()
          ..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));

    return _pageFromNodes(
      nodes: matches,
      cursor: query.cursor,
      limit: query.limit,
    );
  }

  @override
  Future<Result<NodePage>> getTopItems(TopItemsQuery query) async {
    final failure = _validatePublishedSnapshot(
      query.sessionId,
      query.snapshotId,
    );
    if (failure != null) {
      return Result.failure(failure);
    }

    final allowedNodeIds = _subtreeNodeIds(_currentRootNodeId);
    final items = _nodes.values.where((node) {
      if (!allowedNodeIds.contains(node.id)) {
        return false;
      }
      return switch (query.kind) {
        TopItemsKind.files => node.kind == NodeKind.file,
        TopItemsKind.directories => node.kind == NodeKind.directory,
        TopItemsKind.filesAndDirectories => true,
      };
    }).toList()..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));

    return _pageFromNodes(
      nodes: items,
      cursor: query.cursor,
      limit: query.limit,
    );
  }

  @override
  Future<Result<NodeDetails>> getNodeDetails(NodeDetailsQuery query) async {
    final failure = _validatePublishedSnapshot(
      query.sessionId,
      query.snapshotId,
    );
    if (failure != null) {
      return Result.failure(failure);
    }

    final node = _nodes[query.nodeId];
    if (node == null) {
      return Result.failure(
        AppFailure.validation(
          message: 'Node not found',
          field: query.nodeId.value,
        ),
      );
    }

    return Result.success(
      NodeDetails(
        snapshotId: _currentSnapshotId,
        summary: node.toPageItem(_nodes),
        timestamps: NodeTimestamps(
          createdAtUnixMs: BigInt.from(1704103200000),
          modifiedAtUnixMs: BigInt.from(1704195900000),
        ),
        childIds: List.unmodifiable(node.childIds),
        issues: List.unmodifiable(node.issues),
      ),
    );
  }

  @override
  Future<Result<ValidatedCleanupPlan>> createCleanupPlan(
    CreateCleanupPlanCommand command,
  ) async {
    final planId = CleanupPlanId('1');
    _cleanupPlanItemsById[planId] = List.unmodifiable(command.items);
    return Result.success(
      ValidatedCleanupPlan(
        planId: planId,
        commandId: command.commandId,
        state: ValidatedCleanupPlanState.ready,
        items: command.items
            .map(
              (item) => ValidatedCleanupPlanItem(
                itemRef: item,
                displayName: _nodes[item.nodeId]?.name ?? item.nodeId.value,
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
    final items = _cleanupPlanItemsById[command.planId] ?? const [];
    final receipt = CleanupReceipt(
      operationId: command.commandId,
      commandId: command.commandId,
      state: CleanupReceiptState.completed,
      lowDiskReserveReady: true,
      items: items
          .map(
            (item) => CleanupReceiptItem(
              nodeId: item.nodeId,
              displayName: _nodes[item.nodeId]?.name ?? item.nodeId.value,
              state: CleanupItemOutcomeState.movedToTrash,
              restoreExpectation: RestoreExpectationLevel.platformTrashManual,
              reason: null,
            ),
          )
          .toList(growable: false),
    );
    lastCleanupReceipt = receipt;
    return Result.success(receipt);
  }

  @override
  Future<Result<CleanupRecoveryInbox>> getCleanupRecoveryInbox() async {
    return const Result.success(CleanupRecoveryInbox(interruptedReceipts: []));
  }

  Result<NodePage> _pageFromNodes({
    required List<_FakeNode> nodes,
    required OpaqueCursor? cursor,
    required int limit,
  }) {
    final safeLimit = limit.clamp(1, 500).toInt();
    final offset = cursor == null ? 0 : int.tryParse(cursor.value) ?? -1;
    if (offset < 0 || offset > nodes.length) {
      return Result.failure(
        AppFailure.validation(message: 'Invalid cursor', field: cursor?.value),
      );
    }

    final end = (offset + safeLimit).clamp(0, nodes.length).toInt();
    final pageItems = nodes
        .sublist(offset, end)
        .map((node) => node.toPageItem(_nodes))
        .toList();
    final nextCursor = end < nodes.length ? OpaqueCursor('$end') : null;

    return Result.success(
      NodePage(
        snapshotId: _currentSnapshotId,
        items: pageItems,
        nextCursor: nextCursor,
      ),
    );
  }

  NodeId _rootNodeForTarget(ScanTarget? target) {
    final path = target?.path.value.trim();
    if (path == null || path.isEmpty) {
      return rootNodeId;
    }
    return switch (_normalizeFakePath(path)) {
      '/' => rootNodeId,
      '/Users' => usersNodeId,
      '/Users/belief' => homeNodeId,
      '/Users/belief/Library' => libraryNodeId,
      '/Users/belief/Library/Caches' => cachesNodeId,
      '/Users/belief/Library/Application Support' => appSupportNodeId,
      '/Users/belief/Downloads' => downloadsNodeId,
      '/Applications' => applicationsNodeId,
      '/System' => systemNodeId,
      _ => rootNodeId,
    };
  }

  Set<NodeId> _subtreeNodeIds(NodeId rootId) {
    final result = <NodeId>{};
    final pending = <NodeId>[rootId];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!result.add(id)) {
        continue;
      }
      final node = _nodes[id];
      if (node == null) {
        continue;
      }
      pending.addAll(node.childIds);
    }
    return result;
  }

  String _normalizeFakePath(String path) {
    final normalized = path.trim().replaceAll(RegExp(r'/+'), '/');
    if (normalized.isEmpty || normalized == '/') {
      return '/';
    }
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  AppFailure? _validateSession(ScanSessionId candidate) {
    if (candidate != _currentSessionId || _status == null) {
      return AppFailure.validation(
        message: 'Scan session not found',
        field: candidate.value,
      );
    }
    return null;
  }

  AppFailure? _validatePublishedSnapshot(
    ScanSessionId candidateSessionId,
    SnapshotId candidateSnapshotId,
  ) {
    final sessionFailure = _validateSession(candidateSessionId);
    if (sessionFailure != null) {
      return sessionFailure;
    }
    if (candidateSnapshotId != _currentSnapshotId) {
      return AppFailure.validation(
        message: 'Snapshot cursor is stale',
        field: candidateSnapshotId.value,
      );
    }
    if (_status?.hasPublishedSnapshot != true) {
      return const AppFailure.validation(
        message: 'Scan snapshot is not ready',
        field: 'snapshotId',
      );
    }
    return null;
  }

  void _emit(ScanEvent event) {
    final sink = eventSink;
    if (sink == null) {
      return;
    }
    _eventSequence += 1;
    sink(
      ScanEventEnvelope(
        protocolVersion: ProtocolVersion.current,
        sequence: EventSequence('$_eventSequence'),
        emittedAtUnixMs: BigInt.from(1700000000000 + _eventSequence),
        event: event,
      ),
    );
  }

  void _emitGrowingTreeBatch() {
    final nodes = _subtreeNodesInDisplayOrder(_currentRootNodeId);
    if (nodes.isEmpty) {
      return;
    }

    final events = <GrowingTreeEvent>[];
    for (final node in nodes) {
      events.add(
        GrowingNodeDiscovered(
          nodeId: _partialId(node.id),
          parentId: node.parentId == null ? null : _partialId(node.parentId!),
          name: node.name,
          kind: node.kind,
        ),
      );
      final size = SizeFact(
        rawValue: '${node.sizeBytes}',
        quantity: MeasuredQuantity.apparentBytes,
        byteEquivalent: '${node.sizeBytes}',
        confidence: SizeConfidence.low,
      );
      events
        ..add(
          GrowingNodeSizeUpdated(
            nodeId: _partialId(node.id),
            aggregateSize: size,
            state: GrowingNodeState.scanning,
          ),
        )
        ..add(
          GrowingNodeCompleted(
            nodeId: _partialId(node.id),
            aggregateSize: size,
            childCompleteness: ChildCompleteness.complete,
          ),
        );
      for (final issue in node.issues) {
        events.add(
          GrowingNodeIssueRecorded(nodeId: _partialId(node.id), issue: issue),
        );
      }
    }

    _emit(
      ScanGrowingTreeBatch(
        sessionId: _currentSessionId,
        scannedItems: BigInt.from(nodes.length),
        events: events,
      ),
    );
  }

  List<_FakeNode> _subtreeNodesInDisplayOrder(NodeId rootId) {
    final result = <_FakeNode>[];
    final visited = <NodeId>{};

    void visit(NodeId id) {
      if (!visited.add(id)) {
        return;
      }
      final node = _nodes[id];
      if (node == null) {
        return;
      }
      result.add(node);
      for (final childId in node.childIds) {
        visit(childId);
      }
    }

    visit(rootId);
    return result;
  }

  PartialNodeId _partialId(NodeId id) {
    return PartialNodeId(id.value);
  }

  void _sortNodes(List<_FakeNode> nodes, ChildSort sort) {
    switch (sort) {
      case ChildSort.insertion:
        break;
      case ChildSort.nameAsc:
        nodes.sort((a, b) => a.name.compareTo(b.name));
      case ChildSort.nameDesc:
        nodes.sort((a, b) => b.name.compareTo(a.name));
      case ChildSort.sizeAsc:
        nodes.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
      case ChildSort.sizeDesc:
        nodes.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    }
  }
}

final class _FakeScanTree {
  const _FakeScanTree(this.nodes);

  factory _FakeScanTree.sample() {
    final root = _FakeNode.directory(
      id: FakeScanRepository.rootNodeId,
      parentId: null,
      name: 'Macintosh HD',
      sizeBytes: 386400000000,
      childIds: [NodeId('2'), NodeId('8'), NodeId('9')],
    );
    final users = _FakeNode.directory(
      id: NodeId('2'),
      parentId: root.id,
      name: 'Users',
      sizeBytes: 196700000000,
      childIds: [NodeId('3')],
    );
    final home = _FakeNode.directory(
      id: FakeScanRepository.homeNodeId,
      parentId: users.id,
      name: 'belief',
      sizeBytes: 175200000000,
      childIds: [NodeId('4'), NodeId('7')],
    );
    final library = _FakeNode.directory(
      id: NodeId('4'),
      parentId: home.id,
      name: 'Library',
      sizeBytes: 128200000000,
      childIds: [NodeId('5'), NodeId('6'), NodeId('10')],
    );
    final caches = _FakeNode.directory(
      id: FakeScanRepository.cachesNodeId,
      parentId: library.id,
      name: 'Caches',
      sizeBytes: 38700000000,
      childIds: [NodeId('12'), NodeId('13')],
    );
    final appSupport = _FakeNode.directory(
      id: NodeId('6'),
      parentId: library.id,
      name: 'Application Support',
      sizeBytes: 22100000000,
      childIds: [NodeId('14'), NodeId('15')],
    );
    final downloads = _FakeNode.directory(
      id: NodeId('7'),
      parentId: home.id,
      name: 'Downloads',
      sizeBytes: 24800000000,
      childIds: const [],
    );
    final applications = _FakeNode.directory(
      id: NodeId('8'),
      parentId: root.id,
      name: 'Applications',
      sizeBytes: 74300000000,
      childIds: const [],
    );
    final system = _FakeNode.directory(
      id: NodeId('9'),
      parentId: root.id,
      name: 'System',
      sizeBytes: 61800000000,
      childIds: const [],
      issues: const [
        ScanIssue(
          code: IssueCode.permissionDenied,
          severity: IssueSeverity.warning,
          evidence: IssueEvidence(
            path: DisplayPath(text: '/System', privacy: PathPrivacy.raw),
            operation: 'read_dir',
            message: 'System protected path skipped',
          ),
        ),
      ],
    );
    final logs = _FakeNode.directory(
      id: NodeId('10'),
      parentId: library.id,
      name: 'Logs',
      sizeBytes: 8600000000,
      childIds: [NodeId('11')],
    );
    final crashLog = _FakeNode.file(
      id: NodeId('11'),
      parentId: logs.id,
      name: 'CrashReporter.log',
      sizeBytes: 1200000000,
    );
    final browserCache = _FakeNode.directory(
      id: NodeId('12'),
      parentId: caches.id,
      name: 'Browser Cache',
      sizeBytes: 22100000000,
      childIds: [NodeId('16')],
    );
    final userCache = _FakeNode.directory(
      id: NodeId('13'),
      parentId: caches.id,
      name: 'User Cache',
      sizeBytes: 10300000000,
      childIds: [NodeId('17')],
    );
    final xcodeSupport = _FakeNode.directory(
      id: NodeId('14'),
      parentId: appSupport.id,
      name: 'Xcode',
      sizeBytes: 12800000000,
      childIds: [NodeId('18')],
    );
    final simulatorSupport = _FakeNode.directory(
      id: NodeId('15'),
      parentId: appSupport.id,
      name: 'Simulator',
      sizeBytes: 9300000000,
      childIds: [NodeId('19')],
    );
    final browserCacheData = _FakeNode.file(
      id: NodeId('16'),
      parentId: browserCache.id,
      name: 'cache.data',
      sizeBytes: 7600000000,
    );
    final userCacheData = _FakeNode.file(
      id: NodeId('17'),
      parentId: userCache.id,
      name: 'index.db',
      sizeBytes: 2100000000,
    );
    final xcodeIndex = _FakeNode.file(
      id: NodeId('18'),
      parentId: xcodeSupport.id,
      name: 'index.noindex',
      sizeBytes: 6400000000,
    );
    final simulatorImage = _FakeNode.file(
      id: NodeId('19'),
      parentId: simulatorSupport.id,
      name: 'runtime.dmg',
      sizeBytes: 4800000000,
    );

    return _FakeScanTree({
      for (final node in [
        root,
        users,
        home,
        library,
        caches,
        appSupport,
        downloads,
        applications,
        system,
        logs,
        crashLog,
        browserCache,
        userCache,
        xcodeSupport,
        simulatorSupport,
        browserCacheData,
        userCacheData,
        xcodeIndex,
        simulatorImage,
      ])
        node.id: node,
    });
  }

  final Map<NodeId, _FakeNode> nodes;
}

final class _FakeNode {
  const _FakeNode({
    required this.id,
    required this.parentId,
    required this.name,
    required this.kind,
    required this.sizeBytes,
    required this.childIds,
    required this.issues,
  });

  factory _FakeNode.directory({
    required NodeId id,
    required NodeId? parentId,
    required String name,
    required int sizeBytes,
    required List<NodeId> childIds,
    List<ScanIssue> issues = const [],
  }) {
    return _FakeNode(
      id: id,
      parentId: parentId,
      name: name,
      kind: NodeKind.directory,
      sizeBytes: sizeBytes,
      childIds: childIds,
      issues: issues,
    );
  }

  factory _FakeNode.file({
    required NodeId id,
    required NodeId? parentId,
    required String name,
    required int sizeBytes,
    List<ScanIssue> issues = const [],
  }) {
    return _FakeNode(
      id: id,
      parentId: parentId,
      name: name,
      kind: NodeKind.file,
      sizeBytes: sizeBytes,
      childIds: const [],
      issues: issues,
    );
  }

  final NodeId id;
  final NodeId? parentId;
  final String name;
  final NodeKind kind;
  final int sizeBytes;
  final List<NodeId> childIds;
  final List<ScanIssue> issues;

  _FakeNode copyWith({String? name}) {
    return _FakeNode(
      id: id,
      parentId: parentId,
      name: name ?? this.name,
      kind: kind,
      sizeBytes: sizeBytes,
      childIds: childIds,
      issues: issues,
    );
  }

  NodePageItem toPageItem(Map<NodeId, _FakeNode> nodes) {
    return NodePageItem(
      nodeId: id,
      parentId: parentId,
      name: name,
      kind: kind,
      size: SizeFact(
        rawValue: '$sizeBytes',
        quantity: MeasuredQuantity.apparentBytes,
        byteEquivalent: '$sizeBytes',
        confidence: SizeConfidence.exact,
      ),
      flags: const NodeFlags(
        hidden: false,
        system: false,
        package: false,
        symlink: false,
      ),
      childCompleteness: ChildCompleteness.complete,
      childCount: childIds.length,
      issueCount: issues.length,
      subtreeIssueCount: _subtreeIssueCount(nodes),
    );
  }

  int _subtreeIssueCount(Map<NodeId, _FakeNode> nodes) {
    var count = 0;
    for (final childId in childIds) {
      final child = nodes[childId];
      if (child == null) {
        continue;
      }
      count += child.issues.length + child._subtreeIssueCount(nodes);
    }
    return count;
  }
}

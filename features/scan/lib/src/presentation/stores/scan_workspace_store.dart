import 'dart:async';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_catalog.dart';
import 'package:clean_disk_scan/src/application/use_cases/cancel_scan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/execute_cleanup_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_capabilities_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_children_page_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_cleanup_recovery_inbox_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_node_details_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_scan_status_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_top_items_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/launch_permission_repair_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/list_scan_target_choices_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/load_last_scan_target_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/pick_scan_target_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/probe_permission_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/reveal_path_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/save_last_scan_target_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/search_nodes_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/start_scan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/watch_scan_events_use_case.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';
import 'package:mobx/mobx.dart';

enum ScanDaemonAvailability { unknown, ready, offline, incompatible }

enum ScanPageLoadState { idle, loading, failed }

enum ScanQueryMode { children, search, topItems }

final class ScanTreeNodeRow {
  const ScanTreeNodeRow({
    required this.item,
    required this.depth,
    required this.expanded,
    required this.loading,
  });

  final NodePageItem item;
  final int depth;
  final bool expanded;
  final bool loading;
}

final class ScanViewportState {
  const ScanViewportState({
    required this.parentId,
    required this.nextCursor,
    required this.pageSize,
    required this.sort,
    required this.mode,
    required this.searchText,
    required this.topItemsKind,
    required this.isStale,
  });

  static const initial = ScanViewportState(
    parentId: null,
    nextCursor: null,
    pageSize: 100,
    sort: ChildSort.sizeDesc,
    mode: ScanQueryMode.children,
    searchText: '',
    topItemsKind: TopItemsKind.directories,
    isStale: false,
  );

  final NodeId? parentId;
  final OpaqueCursor? nextCursor;
  final int pageSize;
  final ChildSort sort;
  final ScanQueryMode mode;
  final String searchText;
  final TopItemsKind topItemsKind;
  final bool isStale;

  ScanViewportState copyWith({
    Object? parentId = _unset,
    Object? nextCursor = _unset,
    int? pageSize,
    ChildSort? sort,
    ScanQueryMode? mode,
    String? searchText,
    TopItemsKind? topItemsKind,
    bool? isStale,
  }) {
    return ScanViewportState(
      parentId: identical(parentId, _unset)
          ? this.parentId
          : parentId as NodeId?,
      nextCursor: identical(nextCursor, _unset)
          ? this.nextCursor
          : nextCursor as OpaqueCursor?,
      pageSize: pageSize ?? this.pageSize,
      sort: sort ?? this.sort,
      mode: mode ?? this.mode,
      searchText: searchText ?? this.searchText,
      topItemsKind: topItemsKind ?? this.topItemsKind,
      isStale: isStale ?? this.isStale,
    );
  }

  ScanViewportState withoutNextCursor() {
    return ScanViewportState(
      parentId: parentId,
      nextCursor: null,
      pageSize: pageSize,
      sort: sort,
      mode: mode,
      searchText: searchText,
      topItemsKind: topItemsKind,
      isStale: isStale,
    );
  }
}

final class ScanWorkspaceStore with Store {
  ScanWorkspaceStore({
    required GetCapabilitiesUseCase getCapabilities,
    required ProbePermissionUseCase probePermission,
    LaunchPermissionRepairUseCase? launchPermissionRepair,
    PickScanTargetUseCase? pickScanTarget,
    ListScanTargetChoicesUseCase? listScanTargetChoices,
    LoadLastScanTargetUseCase? loadLastScanTarget,
    SaveLastScanTargetUseCase? saveLastScanTarget,
    RevealPathUseCase? revealPath,
    required StartScanUseCase startScan,
    required CancelScanUseCase cancelScan,
    required GetScanStatusUseCase getScanStatus,
    required GetChildrenPageUseCase getChildrenPage,
    required SearchNodesUseCase searchNodes,
    required GetTopItemsUseCase getTopItems,
    required GetNodeDetailsUseCase getNodeDetails,
    required ExecuteCleanupUseCase executeCleanup,
    required GetCleanupRecoveryInboxUseCase getCleanupRecoveryInbox,
    required WatchScanEventsUseCase watchScanEvents,
  }) : _getCapabilities = getCapabilities,
       _probePermission = probePermission,
       _launchPermissionRepair = launchPermissionRepair,
       _pickScanTarget = pickScanTarget,
       _listScanTargetChoices = listScanTargetChoices,
       _loadLastScanTarget = loadLastScanTarget,
       _saveLastScanTarget = saveLastScanTarget,
       _revealPath = revealPath,
       _startScan = startScan,
       _cancelScan = cancelScan,
       _getScanStatus = getScanStatus,
       _getChildrenPage = getChildrenPage,
       _searchNodes = searchNodes,
       _getTopItems = getTopItems,
       _getNodeDetails = getNodeDetails,
       _executeCleanup = executeCleanup,
       _getCleanupRecoveryInbox = getCleanupRecoveryInbox,
       _watchScanEvents = watchScanEvents;

  final GetCapabilitiesUseCase _getCapabilities;
  final ProbePermissionUseCase _probePermission;
  final LaunchPermissionRepairUseCase? _launchPermissionRepair;
  final PickScanTargetUseCase? _pickScanTarget;
  final ListScanTargetChoicesUseCase? _listScanTargetChoices;
  final LoadLastScanTargetUseCase? _loadLastScanTarget;
  final SaveLastScanTargetUseCase? _saveLastScanTarget;
  final RevealPathUseCase? _revealPath;
  final StartScanUseCase _startScan;
  final CancelScanUseCase _cancelScan;
  final GetScanStatusUseCase _getScanStatus;
  final GetChildrenPageUseCase _getChildrenPage;
  final SearchNodesUseCase _searchNodes;
  final GetTopItemsUseCase _getTopItems;
  final GetNodeDetailsUseCase _getNodeDetails;
  final ExecuteCleanupUseCase _executeCleanup;
  final GetCleanupRecoveryInboxUseCase _getCleanupRecoveryInbox;
  final WatchScanEventsUseCase _watchScanEvents;

  final Observable<ScanDaemonAvailability> _daemonAvailability = Observable(
    ScanDaemonAvailability.unknown,
  );
  final Observable<ScanPageLoadState> _pageLoadState = Observable(
    ScanPageLoadState.idle,
  );
  final Observable<ScanSessionStatus?> _sessionStatus =
      Observable<ScanSessionStatus?>(null);
  final Observable<DaemonCapabilities?> _capabilities =
      Observable<DaemonCapabilities?>(null);
  final Observable<RuntimeProof> _runtimeProof = Observable(
    RuntimeProof.unknown,
  );
  final Observable<ScanProgress?> _progress = Observable<ScanProgress?>(null);
  final Observable<SnapshotId?> _activeSnapshotId = Observable<SnapshotId?>(
    null,
  );
  final Observable<ScanViewportState> _viewport = Observable(
    ScanViewportState.initial,
  );
  final Observable<NodeId?> _selectedNodeId = Observable<NodeId?>(null);
  final Observable<NodeDetails?> _selectedDetails = Observable<NodeDetails?>(
    null,
  );
  final Observable<AppFailure?> _lastFailure = Observable<AppFailure?>(null);
  final Observable<AppFailure?> _lastRevealFailure = Observable<AppFailure?>(
    null,
  );
  final Observable<bool> _isLoadingTargetChoices = Observable(false);
  final Observable<bool> _isRevealingPath = Observable(false);
  final ObservableList<ScanTargetChoice> _targetChoices =
      ObservableList<ScanTargetChoice>();
  final ObservableList<NodePageItem> _visibleRows =
      ObservableList<NodePageItem>();
  final ObservableMap<NodeId, NodePageItem> _treeNodesById =
      ObservableMap<NodeId, NodePageItem>();
  final ObservableMap<NodeId, _TreeChildrenPageState> _treeChildrenByParent =
      ObservableMap<NodeId, _TreeChildrenPageState>();
  final ObservableMap<NodeId, bool> _expandedNodeIds =
      ObservableMap<NodeId, bool>();
  final ObservableMap<NodeId, CleanupQueueIntent> _queuedItems =
      ObservableMap<NodeId, CleanupQueueIntent>();
  final ObservableMap<NodeId, CleanupReceiptItem> _movedToTrashItems =
      ObservableMap<NodeId, CleanupReceiptItem>();
  final Observable<DeletePlan?> _deletePlan = Observable<DeletePlan?>(null);
  final Observable<CleanupReceipt?> _cleanupReceipt =
      Observable<CleanupReceipt?>(null);
  final Observable<CleanupRecoveryInbox> _cleanupRecoveryInbox = Observable(
    const CleanupRecoveryInbox(interruptedReceipts: []),
  );

  StreamSubscription<Result<ScanEventEnvelope>>? _eventSubscription;
  void Function()? _onChanged;
  var _searchRequestGeneration = 0;

  void setChangeListener(void Function()? listener) {
    _onChanged = listener;
  }

  void _notifyChanged() {
    final listener = _onChanged;
    if (listener == null) {
      return;
    }
    scheduleMicrotask(listener);
  }

  ScanDaemonAvailability get daemonAvailability => _daemonAvailability.value;

  ScanPageLoadState get pageLoadState => _pageLoadState.value;

  ScanSessionStatus? get sessionStatus => _sessionStatus.value;

  DaemonCapabilities? get capabilities => _capabilities.value;

  RuntimeProof get runtimeProof => _runtimeProof.value;

  ScanSessionId? get sessionId => _sessionStatus.value?.sessionId;

  SnapshotId? get activeSnapshotId => _activeSnapshotId.value;

  List<NodeId> get rootNodeIds {
    return List.unmodifiable(_sessionStatus.value?.rootNodeIds ?? const []);
  }

  NodeId? get primaryRootNodeId {
    final roots = _sessionStatus.value?.rootNodeIds ?? const [];
    return roots.isEmpty ? null : roots.first;
  }

  ScanProgress? get progress => _progress.value;

  ScanViewportState get viewport => _viewport.value;

  NodeId? get selectedNodeId => _selectedNodeId.value;

  NodeDetails? get selectedDetails => _selectedDetails.value;

  AppFailure? get lastFailure => _lastFailure.value;

  AppFailure? get lastRevealFailure => _lastRevealFailure.value;

  List<ScanTargetChoice> get targetChoices {
    return List.unmodifiable(_targetChoices);
  }

  bool get isLoadingTargetChoices => _isLoadingTargetChoices.value;

  bool get isRevealingPath => _isRevealingPath.value;

  bool get canPickScanTarget => _pickScanTarget != null;

  bool get canListScanTargetChoices => _listScanTargetChoices != null;

  bool get canPersistScanTarget => _saveLastScanTarget != null;

  bool get canRevealPath => _revealPath != null;

  bool get canCancelScan {
    final isRunning = _sessionStatus.value?.state == SessionState.running;
    final supportsCancellation =
        _capabilities.value?.scanner.capabilities.cooperativeCancellation ==
        SupportLevel.supported;
    return isRunning && supportsCancellation;
  }

  bool get canLoadMoreVisibleTreeRows => _loadMoreTreeParentId != null;

  bool get isLoadingMoreVisibleTreeRows {
    final parentId = _loadMoreTreeParentId;
    if (parentId == null) {
      return false;
    }
    return _treeChildrenByParent[parentId]?.isLoading == true;
  }

  List<ScanTreeNodeRow> get visibleTreeRows {
    if (viewport.mode != ScanQueryMode.children) {
      return const [];
    }

    final rootParentId = viewport.parentId;
    if (rootParentId == null) {
      return const [];
    }

    final rows = <ScanTreeNodeRow>[];
    _appendVisibleTreeRows(rows: rows, parentId: rootParentId, depth: 0);
    return List.unmodifiable(rows);
  }

  List<NodePageItem> get visibleRows {
    if (viewport.mode == ScanQueryMode.children) {
      return List.unmodifiable(visibleTreeRows.map((row) => row.item));
    }
    return List.unmodifiable(_visibleRows);
  }

  List<CleanupQueueIntent> get queuedItems {
    return List.unmodifiable(_queuedItems.values);
  }

  DeletePlan get deletePlan => _deletePlan.value ?? _buildDeletePlanSnapshot();

  CleanupReceipt? get cleanupReceipt => _cleanupReceipt.value;

  CleanupRecoveryInbox get cleanupRecoveryInbox => _cleanupRecoveryInbox.value;

  bool isQueued(NodeId nodeId) {
    return _queuedItems.containsKey(nodeId);
  }

  bool isMovedToTrash(NodeId nodeId) {
    return _movedToTrashItems.containsKey(nodeId);
  }

  BigInt get queuedBytes {
    return _queuedItems.values.fold<BigInt>(
      BigInt.zero,
      (sum, item) =>
          sum + (item.measuredSize.byteEquivalentBigInt ?? BigInt.zero),
    );
  }

  bool get canQueryPages {
    return sessionId != null && activeSnapshotId != null;
  }

  bool get hasReadableSnapshot {
    return canQueryPages && rootNodeIds.isNotEmpty;
  }

  bool get hasLoadedCurrentTreeRoot {
    if (viewport.mode != ScanQueryMode.children) {
      return false;
    }
    final parentId = viewport.parentId;
    if (parentId == null) {
      return false;
    }
    return _treeChildrenByParent[parentId]?.loaded == true;
  }

  bool get canRepairPermission {
    return _launchPermissionRepair != null &&
        _hasLaunchablePermissionRepair(_runtimeProof.value);
  }

  Future<ScanTarget?> pickScanTarget(ScanTarget currentTarget) async {
    final picker = _pickScanTarget;
    if (picker == null) {
      _setFailure(
        const AppFailure.validation(
          message: 'Scan target picker is not available',
          field: 'scanTargetPicker',
        ),
      );
      return null;
    }

    final result = await picker(
      PickScanTargetRequest(currentTarget: currentTarget),
    );
    return switch (result) {
      ResultSuccess(:final value) => _acceptPickedScanTarget(value),
      ResultFailure(:final failure) => _failPickedScanTarget(failure),
    };
  }

  Future<void> loadTargetChoices() async {
    final listChoices = _listScanTargetChoices;
    if (listChoices == null) {
      return;
    }

    runInAction(() {
      _isLoadingTargetChoices.value = true;
    });
    final result = await listChoices(Unit.value);
    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _targetChoices
            ..clear()
            ..addAll(value);
          _isLoadingTargetChoices.value = false;
        });
      case ResultFailure(:final failure):
        runInAction(() {
          _targetChoices.clear();
          _isLoadingTargetChoices.value = false;
          _lastFailure.value = failure;
        });
    }
    _notifyChanged();
  }

  Future<ScanTarget?> loadLastScanTarget() async {
    final loadTarget = _loadLastScanTarget;
    if (loadTarget == null) {
      return null;
    }

    final result = await loadTarget(Unit.value);
    return switch (result) {
      ResultSuccess(:final value) => value,
      ResultFailure(:final failure) => _failLoadedScanTarget(failure),
    };
  }

  Future<void> saveLastScanTarget(ScanTarget target) async {
    final saveTarget = _saveLastScanTarget;
    if (saveTarget == null) {
      return;
    }

    final result = await saveTarget(target);
    if (result case ResultFailure<Unit>(:final failure)) {
      runInAction(() {
        _lastFailure.value = failure;
      });
      _notifyChanged();
    }
  }

  void clearReadModelForTargetChange() {
    runInAction(_clearReadModelState);
    _notifyChanged();
  }

  Future<void> revealPath(ScanTargetPath path) async {
    final reveal = _revealPath;
    if (reveal == null) {
      runInAction(() {
        _lastRevealFailure.value = const AppFailure.validation(
          message: 'Path reveal is not available',
          field: 'pathRevealer',
        );
      });
      _notifyChanged();
      return;
    }

    runInAction(() {
      _isRevealingPath.value = true;
      _lastRevealFailure.value = null;
    });
    final result = await reveal(path);
    switch (result) {
      case ResultSuccess<Unit>():
        runInAction(() {
          _isRevealingPath.value = false;
          _lastRevealFailure.value = null;
        });
      case ResultFailure<Unit>(:final failure):
        runInAction(() {
          _isRevealingPath.value = false;
          _lastRevealFailure.value = failure;
        });
    }
    _notifyChanged();
  }

  Future<void> checkDaemonCompatibility({
    int attempts = 3,
    Duration retryDelay = const Duration(milliseconds: 250),
  }) async {
    assert(attempts > 0, 'attempts must be positive');

    Result<DaemonCapabilities>? result;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      result = await _getCapabilities();
      if (result case ResultSuccess<DaemonCapabilities>()) {
        break;
      }
      if (result case ResultFailure<DaemonCapabilities>(
        :final failure,
      ) when _shouldRetryCapabilities(failure) && attempt + 1 < attempts) {
        await Future<void>.delayed(retryDelay);
      } else {
        break;
      }
    }

    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _daemonAvailability.value =
              value.protocolVersion.isCompatibleWith(ProtocolVersion.current)
              ? ScanDaemonAvailability.ready
              : ScanDaemonAvailability.incompatible;
          _capabilities.value = value;
          _runtimeProof.value = value.runtimeProof;
          _lastFailure.value = null;
        });
      case ResultFailure(:final failure):
        runInAction(() {
          _daemonAvailability.value = ScanDaemonAvailability.offline;
          _capabilities.value = null;
          _runtimeProof.value = RuntimeProof.unknown;
          _lastFailure.value = failure;
        });
      case null:
        return;
    }
  }

  Future<void> probeTargetPermission(ScanTarget target) async {
    final result = await _probePermission(target);
    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _runtimeProof.value = _runtimeProof.value.copyWith(
            permissionProbe: value,
          );
          final current = _capabilities.value;
          if (current != null) {
            _capabilities.value = current.copyWith(
              runtimeProof: current.runtimeProof.copyWith(
                permissionProbe: value,
              ),
            );
          }
          _deletePlan.value = _buildDeletePlanSnapshot();
          _lastFailure.value = null;
        });
      case ResultFailure(:final failure):
        runInAction(() {
          _lastFailure.value = failure;
          _deletePlan.value = _buildDeletePlanSnapshot();
        });
    }
  }

  Future<void> refreshCleanupPreview(ScanTarget target) async {
    await probeTargetPermission(target);
    runInAction(() {
      _deletePlan.value = _buildDeletePlanSnapshot();
    });
  }

  Future<void> refreshCleanupRecoveryInbox() async {
    final result = await _getCleanupRecoveryInbox(Unit.value);
    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _cleanupRecoveryInbox.value = value;
          _lastFailure.value = null;
        });
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  Future<void> repairTargetPermission(ScanTarget target) async {
    final launcher = _launchPermissionRepair;
    if (launcher == null) {
      _setFailure(
        const AppFailure.validation(
          message: 'Permission repair is not available',
          field: 'permissionRepair',
        ),
      );
      return;
    }

    final proof = _runtimeProof.value;

    if (!_hasLaunchablePermissionRepair(proof)) {
      return;
    }

    final result = await launcher(target: target, proof: proof);
    switch (result) {
      case ResultSuccess<Unit>():
        runInAction(() {
          _lastFailure.value = null;
        });
        await probeTargetPermission(target);
      case ResultFailure<Unit>(:final failure):
        runInAction(() {
          _lastFailure.value = failure;
        });
    }
  }

  Future<void> start(StartScanCommand command) async {
    _setPageLoading();
    runInAction(() {
      final currentViewport = viewport;
      _activeSnapshotId.value = null;
      _resetTreeProjection();
      _visibleRows.clear();
      _movedToTrashItems.clear();
      _selectedNodeId.value = null;
      _selectedDetails.value = null;
      _viewport.value = ScanViewportState.initial.copyWith(
        pageSize: currentViewport.pageSize,
        sort: currentViewport.sort,
        topItemsKind: currentViewport.topItemsKind,
      );
      _deletePlan.value = _buildDeletePlanSnapshot();
    });
    final result = await _startScan(command);
    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _applySessionStatus(value);
          _pageLoadState.value = ScanPageLoadState.idle;
          _lastFailure.value = null;
        });
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  Future<void> refreshStatus() async {
    final currentSessionId = sessionId;
    if (currentSessionId == null) {
      return;
    }

    final result = await _getScanStatus(currentSessionId);
    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _applySessionStatus(value);
          _lastFailure.value = null;
        });
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  Future<bool> waitForReadableSnapshot({
    int attempts = 15,
    Duration pollDelay = const Duration(milliseconds: 200),
  }) async {
    assert(attempts > 0, 'attempts must be positive');

    for (var attempt = 0; attempt < attempts; attempt += 1) {
      if (hasReadableSnapshot) {
        return true;
      }
      if (sessionId == null) {
        return false;
      }
      if (attempt > 0) {
        await Future<void>.delayed(pollDelay);
      }

      await refreshStatus();
      if (hasReadableSnapshot) {
        return true;
      }
      if (pageLoadState == ScanPageLoadState.failed) {
        return false;
      }
      final state = sessionStatus?.state;
      if (state == SessionState.failed || state == SessionState.canceled) {
        return false;
      }
    }

    return hasReadableSnapshot;
  }

  Future<void> cancelCurrentScan(CommandId commandId) async {
    final currentSessionId = sessionId;
    if (currentSessionId == null) {
      return;
    }

    final result = await _cancelScan(
      SessionCommand(commandId: commandId, sessionId: currentSessionId),
    );
    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _applySessionStatus(value);
          _lastFailure.value = null;
        });
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  Future<void> loadPrimaryRootChildren({int? limit, ChildSort? sort}) async {
    final rootId = primaryRootNodeId;
    if (rootId == null) {
      _setFailure(
        const AppFailure.validation(
          message: 'Scan snapshot has no root nodes',
          field: 'rootNodeIds',
        ),
      );
      return;
    }

    await loadChildren(parentId: rootId, limit: limit, sort: sort);
  }

  Future<void> loadChildren({
    required NodeId parentId,
    OpaqueCursor? cursor,
    int? limit,
    ChildSort? sort,
  }) async {
    await _loadTreeRoot(
      parentId: parentId,
      cursor: cursor,
      limit: limit,
      sort: sort,
    );
  }

  Future<void> toggleTreeNode(NodeId nodeId) async {
    final node = _treeNodesById[nodeId];
    if (node == null || node.childCount <= 0) {
      return;
    }

    if (_expandedNodeIds.containsKey(nodeId)) {
      runInAction(() {
        _expandedNodeIds.remove(nodeId);
        _deletePlan.value = _buildDeletePlanSnapshot();
      });
      return;
    }

    runInAction(() {
      _expandedNodeIds[nodeId] = true;
      _deletePlan.value = _buildDeletePlanSnapshot();
    });

    if (!_treeChildrenByParent.containsKey(nodeId)) {
      await loadMoreTreeChildren(nodeId);
    }
  }

  Future<void> expandTreeNode(NodeId nodeId) async {
    if (_expandedNodeIds.containsKey(nodeId)) {
      return;
    }
    await toggleTreeNode(nodeId);
  }

  void collapseTreeNode(NodeId nodeId) {
    if (!_expandedNodeIds.containsKey(nodeId)) {
      return;
    }
    runInAction(() {
      _expandedNodeIds.remove(nodeId);
      _deletePlan.value = _buildDeletePlanSnapshot();
    });
  }

  Future<void> loadMoreTreeChildren(NodeId parentId) async {
    final currentSessionId = sessionId;
    final currentSnapshotId = activeSnapshotId;
    if (currentSessionId == null || currentSnapshotId == null) {
      _setFailure(
        const AppFailure.validation(
          message: 'Scan snapshot is not ready',
          field: 'snapshotId',
        ),
      );
      return;
    }

    final existing = _treeChildrenByParent[parentId];
    if (existing?.isLoading == true) {
      return;
    }
    if (existing != null && existing.loaded && existing.nextCursor == null) {
      return;
    }

    runInAction(() {
      _treeChildrenByParent[parentId] =
          (existing ?? _TreeChildrenPageState.empty).copyWith(
            isLoading: true,
            failure: null,
          );
    });

    final result = await _getChildrenPage(
      ChildrenPageQuery(
        sessionId: currentSessionId,
        snapshotId: currentSnapshotId,
        parentId: parentId,
        cursor: existing?.nextCursor,
        limit: viewport.pageSize,
        sort: viewport.sort,
      ),
    );
    if (!_isCurrentSnapshot(currentSessionId, currentSnapshotId)) {
      _clearTreeNodeLoading(parentId);
      return;
    }
    switch (result) {
      case ResultSuccess(:final value):
        _appendTreeChildrenPage(value, parentId);
      case ResultFailure(:final failure):
        _setTreeFailure(parentId, failure);
    }
  }

  Future<void> loadMoreVisibleTreeRows() async {
    final parentId = _loadMoreTreeParentId;
    if (parentId == null) {
      return;
    }
    await loadMoreTreeChildren(parentId);
  }

  Future<void> _loadTreeRoot({
    required NodeId parentId,
    OpaqueCursor? cursor,
    int? limit,
    ChildSort? sort,
  }) async {
    final currentSessionId = sessionId;
    final currentSnapshotId = activeSnapshotId;
    if (currentSessionId == null || currentSnapshotId == null) {
      _setFailure(
        const AppFailure.validation(
          message: 'Scan snapshot is not ready',
          field: 'snapshotId',
        ),
      );
      return;
    }
    _searchRequestGeneration += 1;

    final nextViewport = ScanViewportState(
      parentId: parentId,
      nextCursor: cursor,
      pageSize: limit ?? viewport.pageSize,
      sort: sort ?? viewport.sort,
      mode: ScanQueryMode.children,
      searchText: '',
      topItemsKind: viewport.topItemsKind,
      isStale: false,
    );
    runInAction(() {
      _viewport.value = nextViewport;
      _pageLoadState.value = ScanPageLoadState.loading;
      _resetTreeProjection();
    });

    final result = await _getChildrenPage(
      ChildrenPageQuery(
        sessionId: currentSessionId,
        snapshotId: currentSnapshotId,
        parentId: parentId,
        cursor: cursor,
        limit: nextViewport.pageSize,
        sort: nextViewport.sort,
      ),
    );
    if (!_isCurrentSnapshot(currentSessionId, currentSnapshotId)) {
      _clearPageLoadingAfterStaleResult();
      return;
    }
    switch (result) {
      case ResultSuccess(:final value):
        _applyTreeRootPage(value, parentId, nextViewport);
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  Future<void> search(
    String searchText, {
    OpaqueCursor? cursor,
    int? limit,
  }) async {
    final trimmed = searchText.trim();
    if (trimmed.isEmpty) {
      await loadPrimaryRootChildren(limit: limit);
      return;
    }

    final currentSessionId = sessionId;
    final currentSnapshotId = activeSnapshotId;
    if (currentSessionId == null || currentSnapshotId == null) {
      _setFailure(
        const AppFailure.validation(
          message: 'Scan snapshot is not ready',
          field: 'snapshotId',
        ),
      );
      return;
    }
    _searchRequestGeneration += 1;
    final requestGeneration = _searchRequestGeneration;

    final nextViewport = ScanViewportState(
      parentId: viewport.parentId,
      nextCursor: cursor,
      pageSize: limit ?? viewport.pageSize,
      sort: viewport.sort,
      mode: ScanQueryMode.search,
      searchText: trimmed,
      topItemsKind: viewport.topItemsKind,
      isStale: false,
    );
    runInAction(() {
      _viewport.value = nextViewport;
      _pageLoadState.value = ScanPageLoadState.loading;
    });

    final result = await _searchNodes(
      SearchPageQuery(
        sessionId: currentSessionId,
        snapshotId: currentSnapshotId,
        searchText: trimmed,
        cursor: cursor,
        limit: nextViewport.pageSize,
      ),
    );
    if (!_isCurrentSnapshot(currentSessionId, currentSnapshotId)) {
      _clearPageLoadingAfterStaleResult();
      return;
    }
    if (!_isCurrentSearchResult(requestGeneration, trimmed)) {
      return;
    }
    switch (result) {
      case ResultSuccess(:final value):
        _applyFlatPage(value, nextViewport);
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  Future<void> showTopItems({
    TopItemsKind kind = TopItemsKind.directories,
    OpaqueCursor? cursor,
    int? limit,
  }) async {
    final currentSessionId = sessionId;
    final currentSnapshotId = activeSnapshotId;
    if (currentSessionId == null || currentSnapshotId == null) {
      _setFailure(
        const AppFailure.validation(
          message: 'Scan snapshot is not ready',
          field: 'snapshotId',
        ),
      );
      return;
    }

    final nextViewport = ScanViewportState(
      parentId: viewport.parentId,
      nextCursor: cursor,
      pageSize: limit ?? viewport.pageSize,
      sort: viewport.sort,
      mode: ScanQueryMode.topItems,
      searchText: '',
      topItemsKind: kind,
      isStale: false,
    );
    runInAction(() {
      _viewport.value = nextViewport;
      _pageLoadState.value = ScanPageLoadState.loading;
    });

    final result = await _getTopItems(
      TopItemsQuery(
        sessionId: currentSessionId,
        snapshotId: currentSnapshotId,
        kind: kind,
        cursor: cursor,
        limit: nextViewport.pageSize,
      ),
    );
    if (!_isCurrentSnapshot(currentSessionId, currentSnapshotId)) {
      _clearPageLoadingAfterStaleResult();
      return;
    }
    switch (result) {
      case ResultSuccess(:final value):
        _applyFlatPage(value, nextViewport);
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  Future<void> changeSort(ChildSort sort) async {
    final parentId = viewport.parentId ?? primaryRootNodeId;
    if (parentId == null) {
      return;
    }
    await loadChildren(
      parentId: parentId,
      limit: viewport.pageSize,
      sort: sort,
    );
  }

  Future<void> selectNode(NodeId nodeId) async {
    final currentSessionId = sessionId;
    final currentSnapshotId = activeSnapshotId;
    if (currentSessionId == null || currentSnapshotId == null) {
      _setFailure(
        const AppFailure.validation(
          message: 'Scan snapshot is not ready',
          field: 'snapshotId',
        ),
      );
      return;
    }

    runInAction(() {
      _selectedNodeId.value = nodeId;
      _selectedDetails.value = null;
      _lastRevealFailure.value = null;
    });

    final result = await _getNodeDetails(
      NodeDetailsQuery(
        sessionId: currentSessionId,
        snapshotId: currentSnapshotId,
        nodeId: nodeId,
      ),
    );
    if (!_isCurrentSnapshot(currentSessionId, currentSnapshotId) ||
        selectedNodeId != nodeId) {
      return;
    }
    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _selectedDetails.value = value;
          _lastFailure.value = null;
        });
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  void queueSelectedNode() {
    final summary = selectedDetails?.summary;
    if (summary == null) {
      return;
    }
    queueNode(summary);
  }

  void queueNode(NodePageItem item) {
    final currentSessionId = sessionId;
    final currentSnapshotId = activeSnapshotId;
    if (currentSessionId == null || currentSnapshotId == null) {
      _setFailure(
        const AppFailure.validation(
          message: 'Scan snapshot is not ready',
          field: 'snapshotId',
        ),
      );
      return;
    }
    if (isMovedToTrash(item.nodeId)) {
      _setFailure(
        const AppFailure.validation(
          message: 'Node was already moved to Trash',
          field: 'nodeId',
        ),
      );
      return;
    }

    runInAction(() {
      _queuedItems[item.nodeId] = CleanupQueueIntent.fromNode(
        sessionId: currentSessionId,
        snapshotId: currentSnapshotId,
        item: item,
      );
      _deletePlan.value = _buildDeletePlanSnapshot();
    });
  }

  void removeQueuedNode(NodeId nodeId) {
    runInAction(() {
      _queuedItems.remove(nodeId);
      _deletePlan.value = _buildDeletePlanSnapshot();
    });
  }

  Future<void> executeCleanup(CommandId commandId) async {
    final plan = deletePlan;
    if (!plan.canAuthorizeCleanup) {
      _setFailure(
        const AppFailure.validation(
          message: 'Cleanup preview has blocking states',
          field: 'deletePlan',
        ),
      );
      return;
    }

    final result = await _executeCleanup(
      ExecuteCleanupCommand(
        commandId: commandId,
        items: plan.items
            .map((item) => CleanupPlanItemRef.fromIntent(item.intent))
            .toList(),
      ),
    );
    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _cleanupReceipt.value = value;
          for (final item in value.items) {
            if (item.state == CleanupItemOutcomeState.movedToTrash) {
              _movedToTrashItems[item.nodeId] = item;
              _queuedItems.remove(item.nodeId);
            }
          }
          _deletePlan.value = _buildDeletePlanSnapshot();
          _lastFailure.value = null;
        });
        await refreshCleanupRecoveryInbox();
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  Future<void> connectEvents() async {
    await _eventSubscription?.cancel();
    _eventSubscription = _watchScanEvents().listen(_applyEventResult);
  }

  void reconcileEvent(ScanEventEnvelope envelope) {
    final event = envelope.event;
    final eventSessionId = event.sessionId;
    final currentSessionId = sessionId;

    if (eventSessionId == null) {
      return;
    }
    if (currentSessionId == null || currentSessionId != eventSessionId) {
      return;
    }
    if (_isTerminalSessionState(sessionStatus?.state) &&
        (event is ScanStarted || event is ScanProgressed)) {
      return;
    }

    runInAction(() {
      switch (event) {
        case ScanStarted():
          _sessionStatus.value = ScanSessionStatus(
            sessionId: eventSessionId,
            state: SessionState.running,
            snapshotId: activeSnapshotId,
            rootNodeIds: sessionStatus?.rootNodeIds ?? const [],
            progress: progress,
          );
        case ScanProgressed(:final progress):
          _progress.value = progress;
          _sessionStatus.value = ScanSessionStatus(
            sessionId: eventSessionId,
            state: SessionState.running,
            snapshotId: activeSnapshotId,
            rootNodeIds: sessionStatus?.rootNodeIds ?? const [],
            progress: progress,
          );
        case ScanSnapshotPublished(:final snapshotId):
          final previousSnapshotId = activeSnapshotId;
          final hasVisibleSnapshotData =
              _visibleRows.isNotEmpty || _treeChildrenByParent.isNotEmpty;
          final shouldMarkStale =
              previousSnapshotId != null &&
              previousSnapshotId != snapshotId &&
              hasVisibleSnapshotData;
          _activeSnapshotId.value = snapshotId;
          _sessionStatus.value = ScanSessionStatus(
            sessionId: eventSessionId,
            state: SessionState.completed,
            snapshotId: snapshotId,
            rootNodeIds: sessionStatus?.rootNodeIds ?? const [],
            progress: progress,
          );
          if (shouldMarkStale || viewport.isStale) {
            _viewport.value = viewport.copyWith(isStale: shouldMarkStale);
          }
        case ScanCanceled():
          _sessionStatus.value = ScanSessionStatus(
            sessionId: eventSessionId,
            state: SessionState.canceled,
            snapshotId: activeSnapshotId,
            rootNodeIds: sessionStatus?.rootNodeIds ?? const [],
            progress: progress,
          );
        case ScanFailed(:final message):
          _sessionStatus.value = ScanSessionStatus(
            sessionId: eventSessionId,
            state: SessionState.failed,
            snapshotId: activeSnapshotId,
            rootNodeIds: sessionStatus?.rootNodeIds ?? const [],
            progress: progress,
          );
          _lastFailure.value = AppFailure.unexpected(message: message);
        case UnknownScanEvent():
          break;
      }
      _deletePlan.value = _buildDeletePlanSnapshot();
    });
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  void _applyEventResult(Result<ScanEventEnvelope> result) {
    switch (result) {
      case ResultSuccess(:final value):
        reconcileEvent(value);
      case ResultFailure(:final failure):
        runInAction(() {
          _daemonAvailability.value = ScanDaemonAvailability.offline;
          _lastFailure.value = failure;
        });
    }
    _notifyChanged();
  }

  void _applyTreeRootPage(
    NodePage page,
    NodeId parentId,
    ScanViewportState nextViewport,
  ) {
    runInAction(() {
      _activeSnapshotId.value = page.snapshotId;
      _visibleRows
        ..clear()
        ..addAll(page.items);
      for (final item in page.items) {
        _treeNodesById[item.nodeId] = item;
      }
      _treeChildrenByParent[parentId] = _TreeChildrenPageState(
        childIds: page.items.map((item) => item.nodeId).toList(),
        nextCursor: page.nextCursor,
        isLoading: false,
        loaded: true,
        failure: null,
      );
      _expandedNodeIds[parentId] = true;
      _viewport.value = nextViewport.copyWith(
        nextCursor: page.nextCursor,
        isStale: false,
      );
      _pageLoadState.value = ScanPageLoadState.idle;
      _deletePlan.value = _buildDeletePlanSnapshot();
      _lastFailure.value = null;
    });
    _notifyChanged();
  }

  void _appendTreeChildrenPage(NodePage page, NodeId parentId) {
    runInAction(() {
      _activeSnapshotId.value = page.snapshotId;
      for (final item in page.items) {
        _treeNodesById[item.nodeId] = item;
      }

      final existing = _treeChildrenByParent[parentId];
      final childIds = <NodeId>[
        ...?existing?.childIds,
        for (final item in page.items)
          if (existing?.childIds.contains(item.nodeId) != true) item.nodeId,
      ];
      _treeChildrenByParent[parentId] = _TreeChildrenPageState(
        childIds: childIds,
        nextCursor: page.nextCursor,
        isLoading: false,
        loaded: true,
        failure: null,
      );
      _pageLoadState.value = ScanPageLoadState.idle;
      _deletePlan.value = _buildDeletePlanSnapshot();
      _lastFailure.value = null;
    });
    _notifyChanged();
  }

  void _applyFlatPage(NodePage page, ScanViewportState nextViewport) {
    runInAction(() {
      _activeSnapshotId.value = page.snapshotId;
      _visibleRows
        ..clear()
        ..addAll(page.items);
      _viewport.value = nextViewport.copyWith(
        nextCursor: page.nextCursor,
        isStale: false,
      );
      _pageLoadState.value = ScanPageLoadState.idle;
      _deletePlan.value = _buildDeletePlanSnapshot();
      _lastFailure.value = null;
    });
    _notifyChanged();
  }

  void _applySessionStatus(ScanSessionStatus status) {
    _sessionStatus.value = status;
    _progress.value = status.progress ?? _progress.value;
    if (status.snapshotId != null) {
      _activeSnapshotId.value = status.snapshotId;
    }
    if (status.snapshotId != null) {
      _viewport.value = viewport.copyWith(isStale: false);
    }
    _deletePlan.value = _buildDeletePlanSnapshot();
    _notifyChanged();
  }

  void _setPageLoading() {
    runInAction(() {
      _pageLoadState.value = ScanPageLoadState.loading;
      _lastFailure.value = null;
    });
    _notifyChanged();
  }

  void _setFailure(AppFailure failure) {
    runInAction(() {
      _pageLoadState.value = ScanPageLoadState.failed;
      _lastFailure.value = failure;
      _deletePlan.value = _buildDeletePlanSnapshot();
    });
    _notifyChanged();
  }

  void _setTreeFailure(NodeId parentId, AppFailure failure) {
    runInAction(() {
      final existing = _treeChildrenByParent[parentId];
      _treeChildrenByParent[parentId] =
          (existing ?? _TreeChildrenPageState.empty).copyWith(
            isLoading: false,
            failure: failure,
          );
      _pageLoadState.value = ScanPageLoadState.failed;
      _lastFailure.value = failure;
      _deletePlan.value = _buildDeletePlanSnapshot();
    });
    _notifyChanged();
  }

  ScanTarget? _acceptPickedScanTarget(ScanTarget? target) {
    runInAction(() {
      _lastFailure.value = null;
    });
    return target;
  }

  ScanTarget? _failPickedScanTarget(AppFailure failure) {
    _setFailure(failure);
    return null;
  }

  ScanTarget? _failLoadedScanTarget(AppFailure failure) {
    runInAction(() {
      _lastFailure.value = failure;
    });
    _notifyChanged();
    return null;
  }

  bool _isCurrentSnapshot(
    ScanSessionId expectedSessionId,
    SnapshotId expectedSnapshotId,
  ) {
    return sessionId == expectedSessionId &&
        activeSnapshotId == expectedSnapshotId;
  }

  bool _isCurrentSearchResult(int generation, String searchText) {
    final currentViewport = viewport;
    return _searchRequestGeneration == generation &&
        currentViewport.mode == ScanQueryMode.search &&
        currentViewport.searchText == searchText;
  }

  void _clearPageLoadingAfterStaleResult() {
    runInAction(() {
      if (_pageLoadState.value == ScanPageLoadState.loading) {
        _pageLoadState.value = ScanPageLoadState.idle;
      }
    });
    _notifyChanged();
  }

  void _clearTreeNodeLoading(NodeId parentId) {
    runInAction(() {
      final existing = _treeChildrenByParent[parentId];
      if (existing == null) {
        return;
      }
      _treeChildrenByParent[parentId] = existing.copyWith(isLoading: false);
    });
    _notifyChanged();
  }

  void _appendVisibleTreeRows({
    required List<ScanTreeNodeRow> rows,
    required NodeId parentId,
    required int depth,
  }) {
    final parentState = _treeChildrenByParent[parentId];
    if (parentState == null) {
      return;
    }

    for (final childId in parentState.childIds) {
      final item = _treeNodesById[childId];
      if (item == null) {
        continue;
      }
      final childState = _treeChildrenByParent[childId];
      final expanded = _expandedNodeIds.containsKey(childId);
      rows.add(
        ScanTreeNodeRow(
          item: item,
          depth: depth,
          expanded: expanded,
          loading: childState?.isLoading == true,
        ),
      );
      if (expanded) {
        _appendVisibleTreeRows(rows: rows, parentId: childId, depth: depth + 1);
      }
    }
  }

  NodeId? get _loadMoreTreeParentId {
    if (viewport.mode != ScanQueryMode.children) {
      return null;
    }

    final selected = selectedNodeId;
    if (_canLoadMoreTreeParent(selected)) {
      return selected;
    }

    final rootParentId = viewport.parentId;
    if (_canLoadMoreTreeParent(rootParentId)) {
      return rootParentId;
    }

    for (final row in visibleTreeRows) {
      if (row.expanded && _canLoadMoreTreeParent(row.item.nodeId)) {
        return row.item.nodeId;
      }
    }
    return null;
  }

  bool _canLoadMoreTreeParent(NodeId? parentId) {
    if (parentId == null) {
      return false;
    }
    final state = _treeChildrenByParent[parentId];
    return state != null && state.nextCursor != null;
  }

  void _resetTreeProjection() {
    _treeNodesById.clear();
    _treeChildrenByParent.clear();
    _expandedNodeIds.clear();
  }

  void _clearReadModelState() {
    final currentViewport = viewport;
    _sessionStatus.value = null;
    _progress.value = null;
    _activeSnapshotId.value = null;
    _pageLoadState.value = ScanPageLoadState.idle;
    _selectedNodeId.value = null;
    _selectedDetails.value = null;
    _lastRevealFailure.value = null;
    _visibleRows.clear();
    _resetTreeProjection();
    _queuedItems.clear();
    _movedToTrashItems.clear();
    _cleanupReceipt.value = null;
    _viewport.value = ScanViewportState.initial.copyWith(
      pageSize: currentViewport.pageSize,
      sort: currentViewport.sort,
      topItemsKind: currentViewport.topItemsKind,
    );
    _deletePlan.value = _buildDeletePlanSnapshot();
  }

  DeletePlan _buildDeletePlanSnapshot() {
    return DeletePlan.preview(
      intents: _queuedItems.values,
      runtimeProof: _runtimeProof.value,
      activeSnapshotId: activeSnapshotId,
      currentRows: _currentVisibleRowsForPreview(),
      visibleRowsStale: viewport.isStale,
    );
  }

  List<NodePageItem> _currentVisibleRowsForPreview() {
    if (viewport.mode == ScanQueryMode.children) {
      return visibleTreeRows.map((row) => row.item).toList(growable: false);
    }
    return List.unmodifiable(_visibleRows);
  }
}

bool _isTerminalSessionState(SessionState? state) {
  return state == SessionState.completed ||
      state == SessionState.canceled ||
      state == SessionState.failed;
}

final class _TreeChildrenPageState {
  const _TreeChildrenPageState({
    required this.childIds,
    required this.nextCursor,
    required this.isLoading,
    required this.loaded,
    required this.failure,
  });

  static const empty = _TreeChildrenPageState(
    childIds: [],
    nextCursor: null,
    isLoading: false,
    loaded: false,
    failure: null,
  );

  final List<NodeId> childIds;
  final OpaqueCursor? nextCursor;
  final bool isLoading;
  final bool loaded;
  final AppFailure? failure;

  _TreeChildrenPageState copyWith({
    List<NodeId>? childIds,
    Object? nextCursor = _unset,
    bool? isLoading,
    bool? loaded,
    Object? failure = _unset,
  }) {
    return _TreeChildrenPageState(
      childIds: childIds ?? this.childIds,
      nextCursor: identical(nextCursor, _unset)
          ? this.nextCursor
          : nextCursor as OpaqueCursor?,
      isLoading: isLoading ?? this.isLoading,
      loaded: loaded ?? this.loaded,
      failure: identical(failure, _unset)
          ? this.failure
          : failure as AppFailure?,
    );
  }
}

bool _shouldRetryCapabilities(AppFailure failure) {
  return failure is NetworkFailure;
}

bool _hasLaunchablePermissionRepair(RuntimeProof proof) {
  return switch (proof.permissionProbe.requiredAction) {
    PermissionRequiredAction.openMacosFullDiskAccess ||
    PermissionRequiredAction.runAsAdministrator ||
    PermissionRequiredAction.reviewLinuxPermissions => true,
    PermissionRequiredAction.none || PermissionRequiredAction.unknown => false,
  };
}

const Object _unset = Object();

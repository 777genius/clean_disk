import 'dart:async';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_catalog.dart';
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

const _diskUsageMapRequestedLimit = 512;
const _partialScanPreviewRowLimit = 160;
const _pendingScanEventLimit = 512;

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

final class PartialScanTreeNodeRow {
  const PartialScanTreeNodeRow({
    required this.item,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
    required this.loading,
  });

  final PartialNodeItem item;
  final int depth;
  final bool hasChildren;
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
    required DisposeScanUseCase disposeScan,
    required GetScanStatusUseCase getScanStatus,
    required GetChildrenPageUseCase getChildrenPage,
    required SearchNodesUseCase searchNodes,
    required GetTopItemsUseCase getTopItems,
    required GetNodeDetailsUseCase getNodeDetails,
    required CreateCleanupPlanUseCase createCleanupPlan,
    required ExecuteCleanupPlanUseCase executeCleanupPlan,
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
       _disposeScan = disposeScan,
       _getScanStatus = getScanStatus,
       _getChildrenPage = getChildrenPage,
       _searchNodes = searchNodes,
       _getTopItems = getTopItems,
       _getNodeDetails = getNodeDetails,
       _createCleanupPlan = createCleanupPlan,
       _executeCleanupPlan = executeCleanupPlan,
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
  final DisposeScanUseCase _disposeScan;
  final GetScanStatusUseCase _getScanStatus;
  final GetChildrenPageUseCase _getChildrenPage;
  final SearchNodesUseCase _searchNodes;
  final GetTopItemsUseCase _getTopItems;
  final GetNodeDetailsUseCase _getNodeDetails;
  final CreateCleanupPlanUseCase _createCleanupPlan;
  final ExecuteCleanupPlanUseCase _executeCleanupPlan;
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
  final ObservableList<NodePageItem> _diskUsageMapRows =
      ObservableList<NodePageItem>();
  final ObservableMap<NodeId, NodePageItem> _treeNodesById =
      ObservableMap<NodeId, NodePageItem>();
  final ObservableMap<NodeId, _TreeChildrenPageState> _treeChildrenByParent =
      ObservableMap<NodeId, _TreeChildrenPageState>();
  final ObservableMap<NodeId, bool> _expandedNodeIds =
      ObservableMap<NodeId, bool>();
  final ObservableList<PartialNodeId> _partialRootNodeIds =
      ObservableList<PartialNodeId>();
  final ObservableMap<PartialNodeId, PartialNodeItem> _partialNodesById =
      ObservableMap<PartialNodeId, PartialNodeItem>();
  final ObservableMap<PartialNodeId, List<PartialNodeId>>
  _partialChildrenByParent =
      ObservableMap<PartialNodeId, List<PartialNodeId>>();
  final ObservableMap<PartialNodeId, bool> _expandedPartialNodeIds =
      ObservableMap<PartialNodeId, bool>();
  final ObservableMap<PartialNodeId, bool> _collapsedPartialNodeIds =
      ObservableMap<PartialNodeId, bool>();
  final ObservableMap<NodeId, CleanupQueueIntent> _queuedItems =
      ObservableMap<NodeId, CleanupQueueIntent>();
  final ObservableMap<NodeId, CleanupReceiptItem> _movedToTrashItems =
      ObservableMap<NodeId, CleanupReceiptItem>();
  final Observable<DeletePlan?> _deletePlan = Observable<DeletePlan?>(null);
  final Observable<ValidatedCleanupPlan?> _validatedCleanupPlan =
      Observable<ValidatedCleanupPlan?>(null);
  final Observable<CleanupReceipt?> _cleanupReceipt =
      Observable<CleanupReceipt?>(null);
  final Observable<CleanupRecoveryInbox> _cleanupRecoveryInbox = Observable(
    const CleanupRecoveryInbox(interruptedReceipts: []),
  );
  final Observable<SnapshotId?> _diskUsageMapSnapshotId =
      Observable<SnapshotId?>(null);
  final Observable<NodePageItem?> _diskUsageMapRootNode =
      Observable<NodePageItem?>(null);
  final Observable<NodeId?> _diskUsageMapFocusNodeId = Observable<NodeId?>(
    null,
  );
  final Observable<bool> _isLoadingDiskUsageMapRows = Observable(false);
  final Observable<AppFailure?> _diskUsageMapFailure = Observable<AppFailure?>(
    null,
  );

  StreamSubscription<Result<ScanEventEnvelope>>? _eventSubscription;
  EventSequence? _lastEventSequence;
  final List<ScanEventEnvelope> _pendingSessionEvents = [];
  void Function()? _onChanged;
  var _searchRequestGeneration = 0;
  var _diskUsageMapRequestGeneration = 0;

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

  bool get hasPartialScanTree => _partialNodesById.isNotEmpty;

  List<PartialScanTreeNodeRow> get partialVisibleTreeRows {
    if (_partialRootNodeIds.isEmpty) {
      return const [];
    }

    final rows = <PartialScanTreeNodeRow>[];
    for (final rootId in _partialRootNodeIds) {
      if (rows.length >= _partialScanPreviewRowLimit) {
        break;
      }
      _appendPartialVisibleTreeRows(
        rows: rows,
        nodeId: rootId,
        depth: 0,
        limit: _partialScanPreviewRowLimit,
      );
    }
    return List.unmodifiable(rows);
  }

  List<PartialNodeItem> get partialVisibleRows {
    return List.unmodifiable(partialVisibleTreeRows.map((row) => row.item));
  }

  List<NodePageItem> get diskUsageMapRows {
    final rows = List<NodePageItem>.unmodifiable(_diskUsageMapRows);
    final focusNodeId = _diskUsageMapFocusNodeId.value;
    if (focusNodeId == null) {
      return rows;
    }

    final focused = _diskUsageMapNode(rows, focusNodeId);
    if (focused == null) {
      return rows;
    }

    final descendants = _diskUsageMapDescendants(rows, focusNodeId);
    if (descendants.isEmpty) {
      return List.unmodifiable([focused]);
    }
    return List.unmodifiable([focused, ...descendants]);
  }

  NodePageItem? get diskUsageMapFocusNode {
    final focusNodeId = _diskUsageMapFocusNodeId.value;
    if (focusNodeId == null) {
      return null;
    }
    return _diskUsageMapNode(_diskUsageMapRows, focusNodeId);
  }

  NodePageItem? get diskUsageMapRootNode => _diskUsageMapRootNode.value;

  NodeId? get diskUsageMapFocusNodeId => _diskUsageMapFocusNodeId.value;

  bool get isLoadingDiskUsageMapRows => _isLoadingDiskUsageMapRows.value;

  AppFailure? get diskUsageMapFailure => _diskUsageMapFailure.value;

  List<CleanupQueueIntent> get queuedItems {
    return List.unmodifiable(_queuedItems.values);
  }

  DeletePlan get deletePlan => _deletePlan.value ?? _buildDeletePlanSnapshot();

  ValidatedCleanupPlan? get validatedCleanupPlan => _validatedCleanupPlan.value;

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
      _validatedCleanupPlan.value = null;
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
    await _disposeCurrentSession(command.commandId);
    _lastEventSequence = null;
    runInAction(() {
      final currentViewport = viewport;
      _activeSnapshotId.value = null;
      _progress.value = null;
      _resetTreeProjection();
      _resetPartialScanProjection();
      _resetDiskUsageMapProjection();
      _visibleRows.clear();
      _movedToTrashItems.clear();
      _validatedCleanupPlan.value = null;
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
        _replayPendingEventsForSession(value.sessionId, value.state);
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
        if (_isOlderSnapshotStatus(value)) {
          return;
        }
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

  Future<void> togglePartialTreeNode(PartialNodeId nodeId) async {
    final node = _partialNodesById[nodeId];
    final hasChildren = _partialChildrenByParent[nodeId]?.isNotEmpty == true;
    if (node == null || !hasChildren) {
      return;
    }

    runInAction(() {
      if (_expandedPartialNodeIds.containsKey(nodeId)) {
        _expandedPartialNodeIds.remove(nodeId);
        _collapsedPartialNodeIds[nodeId] = true;
      } else {
        _expandedPartialNodeIds[nodeId] = true;
        _collapsedPartialNodeIds.remove(nodeId);
      }
    });
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
        unawaited(loadDiskUsageMapRows());
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

  Future<void> loadDiskUsageMapRows({
    int limit = _diskUsageMapRequestedLimit,
  }) async {
    final currentSessionId = sessionId;
    final currentSnapshotId = activeSnapshotId;
    if (currentSessionId == null || currentSnapshotId == null) {
      return;
    }
    if (_diskUsageMapSnapshotId.value == currentSnapshotId &&
        _diskUsageMapRows.isNotEmpty &&
        !_isLoadingDiskUsageMapRows.value) {
      return;
    }

    final requestGeneration = _diskUsageMapRequestGeneration += 1;
    final queryLimit = _boundedQueryLimit(limit);
    runInAction(() {
      _isLoadingDiskUsageMapRows.value = true;
      _diskUsageMapFailure.value = null;
    });

    final result = await _getTopItems(
      TopItemsQuery(
        sessionId: currentSessionId,
        snapshotId: currentSnapshotId,
        kind: TopItemsKind.filesAndDirectories,
        cursor: null,
        limit: queryLimit,
      ),
    );
    if (!_isCurrentSnapshot(currentSessionId, currentSnapshotId) ||
        requestGeneration != _diskUsageMapRequestGeneration) {
      runInAction(() {
        _isLoadingDiskUsageMapRows.value = false;
      });
      _notifyChanged();
      return;
    }

    switch (result) {
      case ResultSuccess(:final value):
        final rootIds = rootNodeIds.toSet();
        NodePageItem? rootNode;
        for (final item in value.items) {
          if (rootIds.contains(item.nodeId)) {
            rootNode = item;
            break;
          }
        }
        runInAction(() {
          _diskUsageMapSnapshotId.value = value.snapshotId;
          _diskUsageMapRootNode.value = rootNode;
          _diskUsageMapRows
            ..clear()
            ..addAll(
              value.items.where((item) => !rootIds.contains(item.nodeId)),
            );
          _diskUsageMapFocusNodeId.value = null;
          _isLoadingDiskUsageMapRows.value = false;
          _diskUsageMapFailure.value = null;
        });
      case ResultFailure(:final failure):
        runInAction(() {
          _isLoadingDiskUsageMapRows.value = false;
          _diskUsageMapFailure.value = failure;
        });
    }
    _notifyChanged();
  }

  void toggleDiskUsageMapFocus(NodeId nodeId) {
    runInAction(() {
      _diskUsageMapFocusNodeId.value = _diskUsageMapFocusNodeId.value == nodeId
          ? null
          : nodeId;
    });
    _notifyChanged();
  }

  void clearDiskUsageMapFocus() {
    if (_diskUsageMapFocusNodeId.value == null) {
      return;
    }
    runInAction(() {
      _diskUsageMapFocusNodeId.value = null;
    });
    _notifyChanged();
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
      _validatedCleanupPlan.value = null;
    });
  }

  void removeQueuedNode(NodeId nodeId) {
    runInAction(() {
      _queuedItems.remove(nodeId);
      _deletePlan.value = _buildDeletePlanSnapshot();
      _validatedCleanupPlan.value = null;
    });
  }

  Future<DeletePlan?> prepareCleanupPlan({
    required CommandId commandId,
    required ScanTarget target,
  }) async {
    await refreshCleanupPreview(target);
    final plan = deletePlan;
    if (!plan.canAuthorizeCleanup) {
      _setFailure(
        const AppFailure.validation(
          message: 'Cleanup preview has blocking states',
          field: 'deletePlan',
        ),
      );
      return null;
    }

    final result = await _createCleanupPlan(
      CreateCleanupPlanCommand(
        commandId: commandId,
        items: _cleanupItemRefsFromPlan(plan),
      ),
    );
    switch (result) {
      case ResultSuccess(:final value):
        runInAction(() {
          _validatedCleanupPlan.value = value;
          _lastFailure.value = null;
        });
        if (!value.canExecute) {
          _setFailure(
            AppFailure.validation(
              message: _serverCleanupBlockReason(value),
              field: 'cleanupPlan',
            ),
          );
          return null;
        }
        _notifyChanged();
        return plan;
      case ResultFailure(:final failure):
        _setFailure(failure);
        return null;
    }
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

    final validatedPlan = _validatedCleanupPlan.value;
    if (validatedPlan == null ||
        !validatedPlan.canExecute ||
        !_validatedPlanMatchesDeletePlan(validatedPlan, plan)) {
      _setFailure(
        const AppFailure.validation(
          message: 'Cleanup plan must be validated before execution',
          field: 'cleanupPlan',
        ),
      );
      return;
    }

    final result = await _executeCleanupPlan(
      ExecuteCleanupPlanCommand(
        commandId: commandId,
        planId: validatedPlan.planId,
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
          _validatedCleanupPlan.value = null;
          _lastFailure.value = null;
        });
        await refreshCleanupRecoveryInbox();
      case ResultFailure(:final failure):
        _setFailure(failure);
    }
  }

  Future<void> connectEvents() async {
    await _eventSubscription?.cancel();
    _lastEventSequence = null;
    _eventSubscription = _watchScanEvents().listen((result) {
      unawaited(_applyEventResult(result));
    });
  }

  void reconcileEvent(ScanEventEnvelope envelope) {
    final event = envelope.event;
    final eventSessionId = event.sessionId;
    final currentSessionId = sessionId;

    if (eventSessionId == null) {
      return;
    }
    if (currentSessionId == null || currentSessionId != eventSessionId) {
      if (currentSessionId == null ||
          _pageLoadState.value == ScanPageLoadState.loading) {
        _bufferPendingSessionEvent(envelope);
      }
      return;
    }
    if (_isTerminalSessionState(sessionStatus?.state) &&
        (event is ScanStarted ||
            event is ScanProgressed ||
            event is ScanGrowingTreeBatch)) {
      return;
    }

    runInAction(() {
      switch (event) {
        case ScanStarted():
          _resetPartialScanProjection();
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
        case ScanGrowingTreeBatch(:final scannedItems, :final events):
          _applyGrowingTreeBatch(events);
          final nextProgress = _progressFromGrowingBatch(scannedItems);
          _progress.value = nextProgress;
          _sessionStatus.value = ScanSessionStatus(
            sessionId: eventSessionId,
            state: SessionState.running,
            snapshotId: activeSnapshotId,
            rootNodeIds: sessionStatus?.rootNodeIds ?? const [],
            progress: nextProgress,
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
          _resetPartialScanProjection();
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
          _resetPartialScanProjection();
        case ScanFailed(:final message):
          _sessionStatus.value = ScanSessionStatus(
            sessionId: eventSessionId,
            state: SessionState.failed,
            snapshotId: activeSnapshotId,
            rootNodeIds: sessionStatus?.rootNodeIds ?? const [],
            progress: progress,
          );
          _resetPartialScanProjection();
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
    await _disposeCurrentSession(_nextInternalCommandId());
  }

  Future<void> _applyEventResult(Result<ScanEventEnvelope> result) async {
    switch (result) {
      case ResultSuccess(:final value):
        final missedEvents = _recordEventSequence(value.sequence);
        reconcileEvent(value);
        if (missedEvents) {
          await refreshStatus();
        }
      case ResultFailure(:final failure):
        runInAction(() {
          _daemonAvailability.value = ScanDaemonAvailability.offline;
          _lastFailure.value = failure;
        });
    }
    _notifyChanged();
  }

  void _bufferPendingSessionEvent(ScanEventEnvelope envelope) {
    if (envelope.event.sessionId == null) {
      return;
    }
    _pendingSessionEvents.add(envelope);
    if (_pendingSessionEvents.length > _pendingScanEventLimit) {
      _pendingSessionEvents.removeRange(
        0,
        _pendingSessionEvents.length - _pendingScanEventLimit,
      );
    }
  }

  void _replayPendingEventsForSession(
    ScanSessionId sessionId,
    SessionState initialState,
  ) {
    if (_pendingSessionEvents.isEmpty) {
      return;
    }
    final skipTerminalEvents = !_isTerminalSessionState(initialState);
    final events =
        _pendingSessionEvents
            .where((envelope) {
              if (envelope.event.sessionId != sessionId) {
                return false;
              }
              return !skipTerminalEvents || !_isTerminalEvent(envelope.event);
            })
            .toList(growable: false)
          ..sort(
            (left, right) =>
                left.sequence.toBigInt().compareTo(right.sequence.toBigInt()),
          );
    _pendingSessionEvents.removeWhere(
      (envelope) => envelope.event.sessionId == sessionId,
    );
    for (final envelope in events) {
      reconcileEvent(envelope);
    }
  }

  Future<void> _disposeCurrentSession(CommandId commandId) async {
    final currentSessionId = sessionId;
    if (currentSessionId == null) {
      return;
    }

    final result = await _disposeScan(
      SessionCommand(commandId: commandId, sessionId: currentSessionId),
    );
    if (result case ResultFailure<Unit>(:final failure)) {
      runInAction(() {
        _lastFailure.value = failure;
      });
      _notifyChanged();
    }
  }

  CommandId _nextInternalCommandId() {
    return CommandId(DateTime.now().microsecondsSinceEpoch.toString());
  }

  bool _recordEventSequence(EventSequence sequence) {
    final current = sequence.toBigInt();
    final previous = _lastEventSequence?.toBigInt();
    if (previous != null && current <= previous) {
      return false;
    }
    _lastEventSequence = sequence;
    return previous != null && current > previous + BigInt.one;
  }

  bool _isOlderSnapshotStatus(ScanSessionStatus status) {
    final currentSessionId = sessionId;
    if (currentSessionId != null && status.sessionId != currentSessionId) {
      return true;
    }
    final currentSnapshotId = activeSnapshotId;
    final nextSnapshotId = status.snapshotId;
    if (currentSnapshotId == null || nextSnapshotId == null) {
      return false;
    }
    return nextSnapshotId.toBigInt() < currentSnapshotId.toBigInt();
  }

  List<CleanupPlanItemRef> _cleanupItemRefsFromPlan(DeletePlan plan) {
    return plan.items
        .map((item) => CleanupPlanItemRef.fromIntent(item.intent))
        .toList(growable: false);
  }

  bool _validatedPlanMatchesDeletePlan(
    ValidatedCleanupPlan validatedPlan,
    DeletePlan plan,
  ) {
    final currentRefs = _cleanupItemRefsFromPlan(plan);
    if (validatedPlan.items.length != currentRefs.length) {
      return false;
    }
    for (var index = 0; index < currentRefs.length; index += 1) {
      if (!_sameCleanupPlanItemRef(
        validatedPlan.items[index].itemRef,
        currentRefs[index],
      )) {
        return false;
      }
    }
    return true;
  }

  bool _sameCleanupPlanItemRef(
    CleanupPlanItemRef left,
    CleanupPlanItemRef right,
  ) {
    return left.sessionId == right.sessionId &&
        left.snapshotId == right.snapshotId &&
        left.nodeId == right.nodeId;
  }

  String _serverCleanupBlockReason(ValidatedCleanupPlan plan) {
    for (final item in plan.items) {
      final reason = item.reason;
      if (item.isBlocked && reason != null && reason.isNotEmpty) {
        return reason;
      }
    }
    return 'Cleanup plan has blocked items';
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
    final effectiveProgress = _effectiveStatusProgress(status);
    _sessionStatus.value = effectiveProgress == status.progress
        ? status
        : ScanSessionStatus(
            sessionId: status.sessionId,
            state: status.state,
            snapshotId: status.snapshotId,
            rootNodeIds: status.rootNodeIds,
            progress: effectiveProgress,
          );
    _progress.value = effectiveProgress;
    if (status.snapshotId != null) {
      _activeSnapshotId.value = status.snapshotId;
    }
    if (status.snapshotId != null) {
      _viewport.value = viewport.copyWith(isStale: false);
    }
    if (status.isTerminal) {
      _resetPartialScanProjection();
    }
    _deletePlan.value = _buildDeletePlanSnapshot();
    _notifyChanged();
  }

  ScanProgress? _effectiveStatusProgress(ScanSessionStatus status) {
    final statusProgress = status.progress;
    if (statusProgress != null) {
      return statusProgress;
    }
    if (_sessionStatus.value?.sessionId != status.sessionId) {
      return null;
    }
    return _progress.value;
  }

  int _boundedQueryLimit(int requestedLimit) {
    final fallbackLimit = viewport.pageSize <= 0 ? 1 : viewport.pageSize;
    final maxPageSize = _capabilities.value?.limits.maxPageSize;
    final upperBound = maxPageSize != null && maxPageSize > 0
        ? maxPageSize
        : fallbackLimit;
    if (requestedLimit <= 0) {
      return fallbackLimit <= upperBound ? fallbackLimit : upperBound;
    }
    return requestedLimit <= upperBound ? requestedLimit : upperBound;
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

  NodePageItem? _diskUsageMapNode(Iterable<NodePageItem> rows, NodeId nodeId) {
    for (final row in rows) {
      if (row.nodeId == nodeId) {
        return row;
      }
    }
    return null;
  }

  List<NodePageItem> _diskUsageMapDescendants(
    Iterable<NodePageItem> rows,
    NodeId parentId,
  ) {
    final childrenByParent = <NodeId, List<NodePageItem>>{};
    for (final row in rows) {
      final parent = row.parentId;
      if (parent == null) {
        continue;
      }
      (childrenByParent[parent] ??= <NodePageItem>[]).add(row);
    }

    final descendants = <NodePageItem>[];
    final queue = <NodePageItem>[...?childrenByParent[parentId]];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      descendants.add(current);
      queue.addAll(childrenByParent[current.nodeId] ?? const <NodePageItem>[]);
    }
    return descendants;
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

  ScanProgress _progressFromGrowingBatch(BigInt scannedItems) {
    final currentProgress = progress;
    if (currentProgress != null &&
        currentProgress.scannedItems >= scannedItems) {
      return currentProgress;
    }
    return ScanProgress(
      scannedItems: scannedItems,
      elapsedMs: currentProgress?.elapsedMs,
      throughputBytesPerSec: currentProgress?.throughputBytesPerSec,
    );
  }

  void _applyGrowingTreeBatch(List<GrowingTreeEvent> events) {
    for (final event in events) {
      switch (event) {
        case GrowingNodeDiscovered():
          _applyGrowingNodeDiscovered(event);
        case GrowingNodeSizeUpdated():
          _updatePartialNode(
            event.nodeId,
            aggregateSize: event.aggregateSize,
            state: event.state,
          );
        case GrowingNodeCompleted():
          _updatePartialNode(
            event.nodeId,
            aggregateSize: event.aggregateSize,
            state: GrowingNodeState.complete,
            childCompleteness: event.childCompleteness,
          );
        case GrowingNodeIssueRecorded():
          _recordPartialNodeIssue(event.nodeId);
        case UnknownGrowingTreeEvent():
          break;
      }
    }
  }

  void _applyGrowingNodeDiscovered(GrowingNodeDiscovered event) {
    final existing = _partialNodesById[event.nodeId];
    _partialNodesById[event.nodeId] =
        existing ??
        PartialNodeItem(
          nodeId: event.nodeId,
          parentId: event.parentId,
          name: event.name,
          kind: event.kind,
          aggregateSize: _zeroPartialSizeFact(),
          state: GrowingNodeState.discovered,
          childCompleteness: ChildCompleteness.unknown,
          issueCount: 0,
        );

    final parentId = event.parentId;
    if (parentId == null) {
      if (!_partialRootNodeIds.contains(event.nodeId)) {
        _partialRootNodeIds.add(event.nodeId);
      }
      if (!_collapsedPartialNodeIds.containsKey(event.nodeId)) {
        _expandedPartialNodeIds[event.nodeId] = true;
      }
      return;
    }

    final children = _partialChildrenByParent[parentId] ?? const [];
    if (!children.contains(event.nodeId)) {
      _partialChildrenByParent[parentId] = [...children, event.nodeId];
    }
  }

  void _updatePartialNode(
    PartialNodeId nodeId, {
    SizeFact? aggregateSize,
    GrowingNodeState? state,
    ChildCompleteness? childCompleteness,
  }) {
    final existing = _partialNodesById[nodeId];
    if (existing == null) {
      return;
    }
    _partialNodesById[nodeId] = existing.copyWith(
      aggregateSize: aggregateSize,
      state: state,
      childCompleteness: childCompleteness,
    );
  }

  void _recordPartialNodeIssue(PartialNodeId? nodeId) {
    if (nodeId == null) {
      return;
    }
    final existing = _partialNodesById[nodeId];
    if (existing == null) {
      return;
    }
    _partialNodesById[nodeId] = existing.copyWith(
      issueCount: existing.issueCount + 1,
    );
  }

  void _appendPartialVisibleTreeRows({
    required List<PartialScanTreeNodeRow> rows,
    required PartialNodeId nodeId,
    required int depth,
    required int limit,
  }) {
    if (rows.length >= limit) {
      return;
    }
    final node = _partialNodesById[nodeId];
    if (node == null) {
      return;
    }
    final children = _partialChildrenByParent[nodeId] ?? const [];
    final expanded = _expandedPartialNodeIds.containsKey(nodeId);
    rows.add(
      PartialScanTreeNodeRow(
        item: node,
        depth: depth,
        hasChildren: children.isNotEmpty,
        expanded: expanded,
        loading: node.state == GrowingNodeState.scanning,
      ),
    );
    if (!expanded) {
      return;
    }
    for (final childId in children) {
      if (rows.length >= limit) {
        break;
      }
      _appendPartialVisibleTreeRows(
        rows: rows,
        nodeId: childId,
        depth: depth + 1,
        limit: limit,
      );
    }
  }

  SizeFact _zeroPartialSizeFact() {
    return SizeFact(
      rawValue: '0',
      quantity: MeasuredQuantity.apparentBytes,
      byteEquivalent: '0',
      confidence: SizeConfidence.low,
    );
  }

  void _resetTreeProjection() {
    _treeNodesById.clear();
    _treeChildrenByParent.clear();
    _expandedNodeIds.clear();
  }

  void _resetPartialScanProjection() {
    _partialRootNodeIds.clear();
    _partialNodesById.clear();
    _partialChildrenByParent.clear();
    _expandedPartialNodeIds.clear();
    _collapsedPartialNodeIds.clear();
  }

  void _resetDiskUsageMapProjection() {
    _diskUsageMapRequestGeneration += 1;
    _diskUsageMapRows.clear();
    _diskUsageMapSnapshotId.value = null;
    _diskUsageMapRootNode.value = null;
    _diskUsageMapFocusNodeId.value = null;
    _isLoadingDiskUsageMapRows.value = false;
    _diskUsageMapFailure.value = null;
  }

  void _clearReadModelState() {
    final currentViewport = viewport;
    _sessionStatus.value = null;
    _lastEventSequence = null;
    _progress.value = null;
    _activeSnapshotId.value = null;
    _pageLoadState.value = ScanPageLoadState.idle;
    _selectedNodeId.value = null;
    _selectedDetails.value = null;
    _lastRevealFailure.value = null;
    _visibleRows.clear();
    _resetTreeProjection();
    _resetPartialScanProjection();
    _resetDiskUsageMapProjection();
    _queuedItems.clear();
    _movedToTrashItems.clear();
    _validatedCleanupPlan.value = null;
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

bool _isTerminalEvent(ScanEvent event) {
  return event is ScanSnapshotPublished ||
      event is ScanCanceled ||
      event is ScanFailed;
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

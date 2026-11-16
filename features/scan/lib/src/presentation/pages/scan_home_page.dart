import 'dart:async';
import 'dart:ui';

import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:clean_disk_localization/clean_disk_localization.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_catalog.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';
import 'package:clean_disk_scan/src/presentation/stores/scan_workspace_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

part 'scan_workspace_layouts.dart';
part 'scan_workspace_panels.dart';
part 'scan_workspace_feedback.dart';
part 'scan_workspace_permission_widgets.dart';
part 'scan_workspace_actions.dart';
part 'scan_workspace_helpers.dart';
part 'scan_workspace_dialogs.dart';
part 'scan_workspace_tables.dart';
part 'scan_workspace_feedback_states.dart';
part 'scan_workspace_navigation.dart';
part 'scan_workspace_breadcrumbs.dart';
part 'scan_workspace_formatters.dart';
part 'scan_workspace_tree_helpers.dart';
part 'scan_workspace_permission_helpers.dart';

class ScanHomePage extends StatefulWidget {
  const ScanHomePage({
    super.key,
    required this.store,
    this.config = const ScanWorkspaceConfig(),
    this.diskUsageMapRenderer,
  });

  final ScanWorkspaceStore store;
  final ScanWorkspaceConfig config;
  final DiskUsageMapRenderer? diskUsageMapRenderer;

  @override
  State<ScanHomePage> createState() => _ScanHomePageState();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _ScanHomePageState extends State<ScanHomePage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'ScanSearchField');
  Timer? _searchDebounceTimer;
  Timer? _snapshotLoadTimer;
  ScanSessionId? _pendingSnapshotLoadSessionId;
  ScanSessionId? _lastAutoLoadedSessionId;
  SnapshotId? _lastAutoLoadedSnapshotId;
  late ScanTarget _activeTarget;
  var _commandSequence = 0;
  var _isLoadingSnapshotRows = false;
  var _targetHydrated = false;
  var _targetChooserVisible = false;
  var _aiPaneCollapsed = false;
  var _detailsPaneCollapsed = false;
  var _diskUsageMapCollapsed = false;
  var _nodeTableCollapsed = false;
  var _uiRefreshScheduled = false;
  var _scanFeedbackActive = false;
  var _searchSequence = 0;
  var _lastSubmittedSearchText = '';
  Timer? _scanFeedbackTimer;

  @override
  void initState() {
    super.initState();
    _activeTarget = widget.config.createDefaultTarget();
    widget.store.setChangeListener(_markStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.store.connectEvents();
      unawaited(_initializeWorkspace(widget.store));
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scanFeedbackTimer?.cancel();
    _stopPendingSnapshotLoadPolling();
    _searchFocusNode.dispose();
    _searchController.dispose();
    widget.store.setChangeListener(null);
    unawaited(widget.store.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _FocusSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _focusSearchField();
              return null;
            },
          ),
        },
        child: ScanWorkspaceView(
          key: const ValueKey('scan-workspace-view'),
          store: widget.store,
          activeTarget: _activeTarget,
          canChangeTarget:
              widget.config.requiresInitialTargetSelection &&
              widget.store.canPickScanTarget,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          canScan: _canRunScan,
          scanFeedbackActive: _scanFeedbackActive,
          showTargetChooser: _targetChooserVisible,
          aiPaneCollapsed: _aiPaneCollapsed,
          detailsPaneCollapsed: _detailsPaneCollapsed,
          diskUsageMapRenderer: widget.diskUsageMapRenderer,
          diskUsageMapCollapsed: _diskUsageMapCollapsed,
          nodeTableCollapsed: _nodeTableCollapsed,
          onScan: _canRunScan ? () => _startScan(widget.store) : null,
          onPause: () => _cancelScan(widget.store),
          onPickTarget: () => unawaited(_pickScanTarget(widget.store)),
          onToggleDetailsPane: _toggleDetailsPane,
          onToggleAiPane: _toggleAiPane,
          onToggleDiskUsageMap: _toggleDiskUsageMap,
          onToggleNodeTable: _toggleNodeTable,
          onChooseTarget: (choice) =>
              unawaited(_selectScanTarget(widget.store, choice.target)),
          onChooseFolderTarget: () =>
              unawaited(_pickScanTarget(widget.store, fromChooser: true)),
          onPermissionProbe: () => unawaited(_probePermission(widget.store)),
          onPermissionRepair: () => unawaited(_repairPermission(widget.store)),
          onRefreshCleanupPreview: () =>
              unawaited(_refreshCleanupPreview(widget.store)),
          onExecuteCleanup: () => unawaited(_executeCleanup(widget.store)),
          onRefreshFolderTarget: (target) =>
              unawaited(_refreshFolderTarget(widget.store, target)),
          onSearchChanged: (value) => _scheduleSearch(widget.store, value),
          onSearchSubmitted: (value) => _submitSearch(widget.store, value),
          onClearSearch: () => unawaited(_clearSearch(widget.store)),
          onSort: (sort) => unawaited(_changeSort(widget.store, sort)),
          onStoreChanged: _markStoreChanged,
        ),
      ),
    );
  }

  void _focusSearchField() {
    if (!widget.store.hasReadableSnapshot) {
      return;
    }
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _toggleDiskUsageMap() {
    setState(() {
      _diskUsageMapCollapsed = !_diskUsageMapCollapsed;
    });
  }

  void _toggleNodeTable() {
    setState(() {
      _nodeTableCollapsed = !_nodeTableCollapsed;
    });
  }

  void _toggleAiPane() {
    setState(() {
      _aiPaneCollapsed = !_aiPaneCollapsed;
    });
  }

  bool get _canRunScan {
    if (_scanFeedbackActive) {
      return false;
    }
    if (widget.store.sessionStatus?.state == SessionState.running) {
      return false;
    }
    if (!widget.config.requiresInitialTargetSelection) {
      return true;
    }
    return _targetHydrated && !_targetChooserVisible;
  }

  Future<void> _initializeWorkspace(ScanWorkspaceStore store) async {
    await store.checkDaemonCompatibility();
    _markStoreChanged();
    await _hydrateTargetState(store);
  }

  Future<void> _hydrateTargetState(ScanWorkspaceStore store) async {
    await store.loadTargetChoices();
    final savedTarget = widget.config.requiresInitialTargetSelection
        ? await store.loadLastScanTarget()
        : null;
    if (!mounted) {
      return;
    }

    final nextTarget = savedTarget ?? _activeTarget;
    setState(() {
      _activeTarget = nextTarget;
      _targetHydrated = true;
      _targetChooserVisible =
          widget.config.requiresInitialTargetSelection && savedTarget == null;
    });

    if (!_targetChooserVisible) {
      await store.probeTargetPermission(nextTarget);
    }
    _markStoreChanged();
  }

  Future<void> _startScan(ScanWorkspaceStore store) async {
    if (!_canRunScan) {
      setState(() {
        _targetChooserVisible = true;
      });
      unawaited(store.loadTargetChoices().whenComplete(_markStoreChanged));
      return;
    }

    _commandSequence += 1;
    _beginScanFeedback();
    _resetSearchState();
    _lastAutoLoadedSessionId = null;
    _lastAutoLoadedSnapshotId = null;
    unawaited(_ensurePermissionProbeForScan(store));
    await store.start(
      widget.config.createStartCommand(
        CommandId('$_commandSequence'),
        target: _activeTarget,
      ),
    );
    _markStoreChanged();
    _pendingSnapshotLoadSessionId = store.sessionId;
    _schedulePendingSnapshotLoad(store);
  }

  void _beginScanFeedback() {
    _scanFeedbackTimer?.cancel();
    setState(() {
      _scanFeedbackActive = true;
    });
    _scanFeedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanFeedbackActive = false;
      });
    });
  }

  Future<void> _loadPendingSnapshotRows(ScanWorkspaceStore store) async {
    final pendingSessionId = _pendingSnapshotLoadSessionId;
    if (_isLoadingSnapshotRows || pendingSessionId == null) {
      return;
    }
    if (store.sessionId != pendingSessionId) {
      _pendingSnapshotLoadSessionId = null;
      _stopPendingSnapshotLoadPolling();
      return;
    }
    _isLoadingSnapshotRows = true;
    try {
      if (!store.hasReadableSnapshot) {
        final isReady = await store.waitForReadableSnapshot(attempts: 1);
        _markStoreChanged();
        if (!isReady) {
          return;
        }
      }

      await store.loadPrimaryRootChildren(limit: 100, sort: ChildSort.sizeDesc);
      _markStoreChanged();
      final rows = store.visibleRows;
      if (rows.isNotEmpty) {
        await store.selectNode(rows.first.nodeId);
        _markStoreChanged();
      }
      _pendingSnapshotLoadSessionId = null;
      _stopPendingSnapshotLoadPolling();
    } finally {
      _isLoadingSnapshotRows = false;
    }
  }

  void _schedulePendingSnapshotLoad(ScanWorkspaceStore store) {
    unawaited(_loadPendingSnapshotRows(store));
    _snapshotLoadTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _pendingSnapshotLoadSessionId == null) {
        _stopPendingSnapshotLoadPolling();
        return;
      }
      unawaited(_loadPendingSnapshotRows(store));
    });
  }

  void _stopPendingSnapshotLoadPolling() {
    _snapshotLoadTimer?.cancel();
    _snapshotLoadTimer = null;
  }

  Future<void> _cancelScan(ScanWorkspaceStore store) async {
    final sessionId = store.sessionId;
    if (sessionId == null) {
      return;
    }
    _commandSequence += 1;
    await store.cancelCurrentScan(CommandId('$_commandSequence'));
    _markStoreChanged();
  }

  Future<void> _probePermission(ScanWorkspaceStore store) async {
    await store.probeTargetPermission(_activeTarget);
    _markStoreChanged();
  }

  Future<void> _ensurePermissionProbeForScan(ScanWorkspaceStore store) async {
    final probeStatus = store.runtimeProof.permissionProbe.status;
    if (probeStatus != PermissionProbeStatus.notProbed &&
        probeStatus != PermissionProbeStatus.unknown) {
      return;
    }
    await store.probeTargetPermission(_activeTarget);
    _markStoreChanged();
  }

  Future<void> _refreshCleanupPreview(ScanWorkspaceStore store) async {
    await store.refreshCleanupPreview(_activeTarget);
    _markStoreChanged();
  }

  Future<void> _executeCleanup(ScanWorkspaceStore store) async {
    _commandSequence += 1;
    final plan = await store.prepareCleanupPlan(
      commandId: CommandId('$_commandSequence'),
      target: _activeTarget,
    );
    _markStoreChanged();
    if (!mounted || plan == null) {
      return;
    }

    final confirmed = await _showCleanupConfirmDialog(context, plan);
    if (!mounted || !confirmed) {
      return;
    }

    _commandSequence += 1;
    await store.executeCleanup(CommandId('$_commandSequence'));
    _markStoreChanged();
  }

  Future<void> _refreshFolderTarget(
    ScanWorkspaceStore store,
    ScanTarget target,
  ) async {
    if (store.sessionStatus?.state == SessionState.running) {
      return;
    }

    _prepareForTargetChange(store);
    setState(() {
      _activeTarget = target;
      _targetHydrated = true;
      _targetChooserVisible = false;
    });
    await store.saveLastScanTarget(target);
    await store.probeTargetPermission(target);
    if (!mounted) {
      return;
    }
    await _startScan(store);
  }

  Future<void> _repairPermission(ScanWorkspaceStore store) async {
    final proof = store.runtimeProof;
    final action = await _showPermissionRepairDialog(context, proof);
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _PermissionRepairDialogAction.openSettings:
        await store.repairTargetPermission(_activeTarget);
      case _PermissionRepairDialogAction.recheck:
        await store.probeTargetPermission(_activeTarget);
    }
    _markStoreChanged();
  }

  Future<void> _selectScanTarget(
    ScanWorkspaceStore store,
    ScanTarget target,
  ) async {
    _prepareForTargetChange(store);
    setState(() {
      _activeTarget = target;
      _targetHydrated = true;
      _targetChooserVisible = false;
    });
    await store.saveLastScanTarget(target);
    await store.probeTargetPermission(target);
    await store.loadTargetChoices();
    _markStoreChanged();
  }

  Future<void> _pickScanTarget(
    ScanWorkspaceStore store, {
    bool fromChooser = false,
  }) async {
    final pickedTarget = await store.pickScanTarget(_activeTarget);
    if (!mounted || pickedTarget == null) {
      return;
    }

    _prepareForTargetChange(store);
    setState(() {
      _activeTarget = pickedTarget;
      _targetHydrated = true;
      if (fromChooser) {
        _targetChooserVisible = false;
      }
    });
    await store.saveLastScanTarget(pickedTarget);
    await store.probeTargetPermission(pickedTarget);
    await store.loadTargetChoices();
    _markStoreChanged();
  }

  void _prepareForTargetChange(ScanWorkspaceStore store) {
    _resetSearchState();
    _pendingSnapshotLoadSessionId = null;
    _stopPendingSnapshotLoadPolling();
    _lastAutoLoadedSessionId = null;
    _lastAutoLoadedSnapshotId = null;
    store.clearReadModelForTargetChange();
  }

  Future<void> _submitSearch(ScanWorkspaceStore store, String value) async {
    _searchDebounceTimer?.cancel();
    final query = _normalizedSearchText(value);
    if (query.isEmpty) {
      if (store.viewport.mode != ScanQueryMode.children ||
          _lastSubmittedSearchText.isNotEmpty) {
        await _clearSearch(store);
      }
      return;
    }
    if (!store.hasReadableSnapshot) {
      return;
    }
    if (query == _lastSubmittedSearchText &&
        store.viewport.mode == ScanQueryMode.search &&
        store.pageLoadState != ScanPageLoadState.failed) {
      return;
    }

    _lastSubmittedSearchText = query;
    _searchSequence += 1;
    final searchSequence = _searchSequence;
    await store.search(query, limit: 100);
    if (!mounted || searchSequence != _searchSequence) {
      return;
    }
    _markStoreChanged();
    final rows = store.visibleRows;
    if (rows.isNotEmpty) {
      await store.selectNode(rows.first.nodeId);
      _markStoreChanged();
    }
  }

  void _scheduleSearch(ScanWorkspaceStore store, String value) {
    _searchDebounceTimer?.cancel();
    final query = _normalizedSearchText(value);
    final debounce = query.isEmpty
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 260);
    _searchDebounceTimer = Timer(debounce, () {
      unawaited(_submitSearch(store, value));
    });
  }

  Future<void> _clearSearch(ScanWorkspaceStore store) async {
    _searchDebounceTimer?.cancel();
    _searchSequence += 1;
    _lastSubmittedSearchText = '';
    _searchController.clear();
    await store.loadPrimaryRootChildren(
      limit: store.viewport.pageSize,
      sort: store.viewport.sort,
    );
    _markStoreChanged();
    final rows = store.visibleRows;
    if (rows.isNotEmpty) {
      await store.selectNode(rows.first.nodeId);
      _markStoreChanged();
    }
  }

  Future<void> _changeSort(ScanWorkspaceStore store, ChildSort sort) async {
    if (store.viewport.mode != ScanQueryMode.children) {
      _resetSearchState();
    }
    await store.changeSort(sort);
    _markStoreChanged();
  }

  void _resetSearchState() {
    _searchDebounceTimer?.cancel();
    _searchSequence += 1;
    _lastSubmittedSearchText = '';
    _searchController.clear();
  }

  String _normalizedSearchText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _toggleDetailsPane() {
    setState(() {
      _detailsPaneCollapsed = !_detailsPaneCollapsed;
    });
    scheduleMicrotask(_requestVisualRefresh);
  }

  void _markStoreChanged() {
    if (!mounted || _uiRefreshScheduled) {
      return;
    }
    _uiRefreshScheduled = true;
    scheduleMicrotask(_flushStoreChanged);
  }

  void _flushStoreChanged() {
    _uiRefreshScheduled = false;
    if (!mounted) {
      return;
    }
    setState(() {});
    _requestVisualRefresh();
    _maybeAutoloadReadableTree(widget.store);
  }

  void _requestVisualRefresh() {
    if (!mounted) {
      return;
    }
    final binding = WidgetsBinding.instance;
    binding.ensureVisualUpdate();
    if (binding is WidgetsFlutterBinding &&
        SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      binding.scheduleWarmUpFrame();
    }
  }

  void _maybeAutoloadReadableTree(ScanWorkspaceStore store) {
    if (!mounted ||
        _targetChooserVisible ||
        _isLoadingSnapshotRows ||
        store.viewport.mode != ScanQueryMode.children ||
        !store.canQueryPages ||
        store.hasLoadedCurrentTreeRoot) {
      return;
    }

    final currentSessionId = store.sessionId;
    final currentSnapshotId = store.activeSnapshotId;
    if (currentSessionId == null || currentSnapshotId == null) {
      return;
    }
    if (_lastAutoLoadedSessionId == currentSessionId &&
        _lastAutoLoadedSnapshotId == currentSnapshotId) {
      return;
    }

    _lastAutoLoadedSessionId = currentSessionId;
    _lastAutoLoadedSnapshotId = currentSnapshotId;
    _pendingSnapshotLoadSessionId = currentSessionId;
    _schedulePendingSnapshotLoad(store);
  }
}

Future<bool> _showCleanupConfirmDialog(
  BuildContext context,
  DeletePlan plan,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _CleanupConfirmDialog(plan: plan),
  );
  return result ?? false;
}

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

class _CleanupConfirmDialog extends StatelessWidget {
  const _CleanupConfirmDialog({required this.plan});

  final DeletePlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return Dialog(
      key: const ValueKey('cleanup-confirm-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: _ScanColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _ScanColors.border),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    color: _ScanColors.pink,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.cleanupConfirmTitle,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.cleanupConfirmText,
                style: _bodyStyle(
                  context,
                ).copyWith(color: _ScanColors.textSoft),
              ),
              const SizedBox(height: 14),
              _StatePill(
                label: l10n.cleanupConfirmSummary(
                  count: plan.items.length,
                  size: _formatBytes(plan.knownReclaimBytes),
                ),
                maxWidth: double.infinity,
                color: _ScanColors.cyan,
              ),
              const SizedBox(height: 12),
              _CleanupConfirmItemList(plan: plan),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.cleanupConfirmCancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('cleanup-confirm-trash-action'),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: Text(l10n.cleanupConfirmMove),
                      style: FilledButton.styleFrom(
                        backgroundColor: _ScanColors.pink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PermissionRepairDialogAction { openSettings, recheck }

Future<_PermissionRepairDialogAction?> _showPermissionRepairDialog(
  BuildContext context,
  RuntimeProof proof,
) {
  return showDialog<_PermissionRepairDialogAction>(
    context: context,
    builder: (context) => _PermissionRepairDialog(proof: proof),
  );
}

class _PermissionRepairDialog extends StatelessWidget {
  const _PermissionRepairDialog({required this.proof});

  final RuntimeProof proof;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final canOpenSettings =
        proof.permissionProbe.requiredAction ==
        PermissionRequiredAction.openMacosFullDiskAccess;
    final steps = _permissionRepairSteps(l10n, proof);

    return Dialog(
      key: const ValueKey('permission-repair-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: _ScanColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _ScanColors.border),
          ),
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: _ScanColors.cyan,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.permissionRepairTitle,
                        overflow: TextOverflow.ellipsis,
                        style: _titleStyle(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.permissionRepairTrustCopy,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: _ScanColors.textSoft),
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < steps.length; index += 1) ...[
                  _PermissionRepairStep(number: index + 1, text: steps[index]),
                  if (index + 1 < steps.length) const SizedBox(height: 10),
                ],
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.permissionRepairCancel),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('permission-repair-recheck-action'),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_PermissionRepairDialogAction.recheck),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.permissionProbeAction),
                    ),
                    if (canOpenSettings)
                      FilledButton.icon(
                        key: const ValueKey(
                          'permission-repair-open-settings-action',
                        ),
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_PermissionRepairDialogAction.openSettings),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: Text(l10n.permissionRepairOpenSettings),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionRepairStep extends StatelessWidget {
  const _PermissionRepairStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _ScanColors.input,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _ScanColors.border),
          ),
          child: Text(
            '$number',
            style: _monoStyle(context).copyWith(color: _ScanColors.cyan),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: _bodyStyle(context).copyWith(color: _ScanColors.text),
          ),
        ),
      ],
    );
  }
}

class ScanWorkspaceView extends StatelessWidget {
  const ScanWorkspaceView({
    super.key,
    required this.store,
    required this.activeTarget,
    required this.canChangeTarget,
    required this.searchController,
    required this.searchFocusNode,
    required this.canScan,
    required this.scanFeedbackActive,
    required this.showTargetChooser,
    required this.aiPaneCollapsed,
    required this.detailsPaneCollapsed,
    required this.diskUsageMapCollapsed,
    required this.nodeTableCollapsed,
    this.diskUsageMapRenderer,
    required this.onScan,
    required this.onPause,
    required this.onPickTarget,
    required this.onToggleAiPane,
    required this.onToggleDetailsPane,
    required this.onToggleDiskUsageMap,
    required this.onToggleNodeTable,
    required this.onChooseTarget,
    required this.onChooseFolderTarget,
    required this.onPermissionProbe,
    required this.onPermissionRepair,
    required this.onRefreshCleanupPreview,
    required this.onExecuteCleanup,
    required this.onRefreshFolderTarget,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onSort,
    required this.onStoreChanged,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final bool canChangeTarget;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool canScan;
  final bool scanFeedbackActive;
  final bool showTargetChooser;
  final bool aiPaneCollapsed;
  final bool detailsPaneCollapsed;
  final bool diskUsageMapCollapsed;
  final bool nodeTableCollapsed;
  final DiskUsageMapRenderer? diskUsageMapRenderer;
  final VoidCallback? onScan;
  final VoidCallback onPause;
  final VoidCallback onPickTarget;
  final VoidCallback onToggleAiPane;
  final VoidCallback onToggleDetailsPane;
  final VoidCallback onToggleDiskUsageMap;
  final VoidCallback onToggleNodeTable;
  final ValueChanged<ScanTargetChoice> onChooseTarget;
  final VoidCallback onChooseFolderTarget;
  final VoidCallback onPermissionProbe;
  final VoidCallback onPermissionRepair;
  final VoidCallback onRefreshCleanupPreview;
  final VoidCallback onExecuteCleanup;
  final ValueChanged<ScanTarget> onRefreshFolderTarget;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<ChildSort> onSort;
  final VoidCallback onStoreChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final scanActionLabel = _scanActionLabel(l10n, store, scanFeedbackActive);

    return AppScaffold(
      body: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(color: _ScanColors.background),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 1120;
                return Column(
                  children: [
                    _TopBar(
                      compact: compact,
                      statusText: _statusText(l10n, store, scanFeedbackActive),
                      searchController: searchController,
                      searchFocusNode: searchFocusNode,
                      currentSort: store.viewport.sort,
                      queryMode: store.viewport.mode,
                      activeTarget: activeTarget,
                      targetChoices: store.targetChoices,
                      isLoadingTargetChoices: store.isLoadingTargetChoices,
                      runtimeProof: store.runtimeProof,
                      scanActionLabel: scanActionLabel,
                      canSearch: store.hasReadableSnapshot,
                      canSort: store.visibleRows.isNotEmpty,
                      canPickTarget:
                          store.canPickScanTarget &&
                          store.sessionStatus?.state != SessionState.running,
                      canRepairPermission: store.canRepairPermission,
                      canScan: canScan,
                      onScan: onScan,
                      onPickTarget: onPickTarget,
                      onChooseTarget: onChooseTarget,
                      onChooseFolderTarget: onChooseFolderTarget,
                      onPermissionProbe: onPermissionProbe,
                      onPermissionRepair: onPermissionRepair,
                      onPause: onPause,
                      canCancelScan: store.canCancelScan,
                      onSearchChanged: onSearchChanged,
                      onSearchSubmitted: onSearchSubmitted,
                      onSort: onSort,
                    ),
                    Expanded(
                      child: compact
                          ? _CompactWorkspace(
                              store: store,
                              activeTarget: activeTarget,
                              canChangeTarget: canChangeTarget,
                              onScan: onScan,
                              onPickTarget: onPickTarget,
                              onPermissionProbe: onPermissionProbe,
                              onPermissionRepair: onPermissionRepair,
                              onRefreshCleanupPreview: onRefreshCleanupPreview,
                              onExecuteCleanup: onExecuteCleanup,
                              onRefreshFolderTarget: onRefreshFolderTarget,
                              onClearSearch: onClearSearch,
                              onStoreChanged: onStoreChanged,
                              diskUsageMapRenderer: diskUsageMapRenderer,
                              diskUsageMapCollapsed: diskUsageMapCollapsed,
                              onToggleDiskUsageMap: onToggleDiskUsageMap,
                              nodeTableCollapsed: nodeTableCollapsed,
                              onToggleNodeTable: onToggleNodeTable,
                            )
                          : _WideWorkspace(
                              store: store,
                              activeTarget: activeTarget,
                              onScan: onScan,
                              onRefreshCleanupPreview: onRefreshCleanupPreview,
                              onExecuteCleanup: onExecuteCleanup,
                              onRefreshFolderTarget: onRefreshFolderTarget,
                              onClearSearch: onClearSearch,
                              onStoreChanged: onStoreChanged,
                              diskUsageMapRenderer: diskUsageMapRenderer,
                              diskUsageMapCollapsed: diskUsageMapCollapsed,
                              onToggleDiskUsageMap: onToggleDiskUsageMap,
                              nodeTableCollapsed: nodeTableCollapsed,
                              onToggleNodeTable: onToggleNodeTable,
                              aiPaneCollapsed: aiPaneCollapsed,
                              onToggleAiPane: onToggleAiPane,
                              detailsPaneCollapsed: detailsPaneCollapsed,
                              onToggleDetailsPane: onToggleDetailsPane,
                            ),
                    ),
                    _ScanFooter(store: store, onCancelScan: onPause),
                  ],
                );
              },
            ),
          ),
          if (showTargetChooser)
            _FirstRunTargetChooser(
              store: store,
              activeTarget: activeTarget,
              onChooseTarget: onChooseTarget,
              onChooseFolderTarget: onChooseFolderTarget,
            ),
        ],
      ),
    );
  }

  String _statusText(
    CleanDiskLocalizations l10n,
    ScanWorkspaceStore store,
    bool scanFeedbackActive,
  ) {
    if (scanFeedbackActive) {
      return l10n.scanRunningStatus;
    }
    return switch (store.daemonAvailability) {
      ScanDaemonAvailability.offline => l10n.scanOfflineStatus,
      ScanDaemonAvailability.incompatible => l10n.scanIncompatibleStatus,
      _ => switch (store.sessionStatus?.state) {
        SessionState.running => l10n.scanRunningStatus,
        SessionState.completed => l10n.scanCompletedStatus,
        _ => l10n.scanReadyStatus,
      },
    };
  }

  String _scanActionLabel(
    CleanDiskLocalizations l10n,
    ScanWorkspaceStore store,
    bool scanFeedbackActive,
  ) {
    if (scanFeedbackActive) {
      return l10n.scanRunningStatus;
    }
    return switch (store.sessionStatus?.state) {
      SessionState.running => l10n.scanRunningStatus,
      SessionState.completed => l10n.scanAgainAction,
      _ => l10n.scanAction,
    };
  }
}

final class ScanWorkspaceConfig {
  const ScanWorkspaceConfig({
    this.defaultTargetPath = '/',
    this.defaultTargetScope = TargetScope.volume,
    this.defaultBoundaryPolicy = BoundaryPolicy.stayOnInitialFilesystem,
    this.defaultHardlinkPolicy = HardlinkPolicy.ignore,
    this.defaultMeasurement = MeasuredQuantity.apparentBytes,
    this.defaultMode = ScanMode.balanced,
    this.requiresInitialTargetSelection = false,
  });

  final String defaultTargetPath;
  final TargetScope defaultTargetScope;
  final BoundaryPolicy defaultBoundaryPolicy;
  final HardlinkPolicy defaultHardlinkPolicy;
  final MeasuredQuantity defaultMeasurement;
  final ScanMode defaultMode;
  final bool requiresInitialTargetSelection;

  StartScanCommand createStartCommand(
    CommandId commandId, {
    ScanTarget? target,
  }) {
    return StartScanCommand(
      commandId: commandId,
      targets: [target ?? createDefaultTarget()],
      measurement: defaultMeasurement,
      mode: defaultMode,
    );
  }

  ScanTarget createDefaultTarget() {
    return ScanTarget(
      path: ScanTargetPath(defaultTargetPath),
      scope: defaultTargetScope,
      boundaryPolicy: defaultBoundaryPolicy,
      hardlinkPolicy: defaultHardlinkPolicy,
    );
  }
}

class _FirstRunTargetChooser extends StatelessWidget {
  const _FirstRunTargetChooser({
    required this.store,
    required this.activeTarget,
    required this.onChooseTarget,
    required this.onChooseFolderTarget,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final ValueChanged<ScanTargetChoice> onChooseTarget;
  final VoidCallback onChooseFolderTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final choices = store.targetChoices;

    return Positioned.fill(
      child: ColoredBox(
        key: const ValueKey('first-run-target-chooser'),
        color: Colors.black.withValues(alpha: 0.54),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.all(18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _ScanColors.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _ScanColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.drive_folder_upload_outlined,
                        color: _ScanColors.cyan,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.firstRunTargetTitle,
                          overflow: TextOverflow.ellipsis,
                          style: _titleStyle(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.firstRunTargetText,
                    style: _bodyStyle(
                      context,
                    ).copyWith(color: _ScanColors.textSoft),
                  ),
                  const SizedBox(height: 14),
                  if (store.isLoadingTargetChoices)
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _ScanColors.cyan,
                      backgroundColor: _ScanColors.progressTrack,
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final choice in choices)
                              _TargetChoiceRow(
                                choice: choice,
                                selected:
                                    choice.target.path == activeTarget.path,
                                onTap: () => onChooseTarget(choice),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      key: const ValueKey('first-run-choose-folder-action'),
                      onPressed: store.canPickScanTarget
                          ? onChooseFolderTarget
                          : null,
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: Text(l10n.targetPickAction),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ScanColors.cyan,
                        side: const BorderSide(color: _ScanColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetChoiceRow extends StatefulWidget {
  const _TargetChoiceRow({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final ScanTargetChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TargetChoiceRow> createState() => _TargetChoiceRowState();
}

class _TargetChoiceRowState extends State<_TargetChoiceRow> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() {
      _hovered = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final backgroundColor = widget.selected
        ? (_hovered
              ? _ScanColors.selectedSoft.withValues(alpha: 0.94)
              : _ScanColors.selectedSoft)
        : (_hovered
              ? _ScanColors.selectedSoft.withValues(alpha: 0.46)
              : _ScanColors.innerPanel);
    final borderColor = _hovered
        ? _ScanColors.cyan.withValues(alpha: 0.72)
        : widget.selected
        ? _ScanColors.cyan
        : _ScanColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: ValueKey('first-run-target-choice-${widget.choice.kind.name}'),
            onTap: widget.onTap,
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.transparent,
            splashColor: _ScanColors.cyan.withValues(alpha: 0.12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    _targetChoiceIcon(widget.choice.kind),
                    color: widget.selected
                        ? _ScanColors.cyan
                        : _ScanColors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _targetChoiceLabel(l10n, widget.choice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.choice.target.path.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _monoStyle(
                            context,
                          ).copyWith(color: _ScanColors.textSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: _ScanColors.textSoft,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

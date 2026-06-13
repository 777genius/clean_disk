import 'dart:async';

import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:clean_disk_localization/clean_disk_localization.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_catalog.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';
import 'package:clean_disk_scan/src/presentation/stores/scan_workspace_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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
  var _detailsPaneCollapsed = false;
  var _diskUsageMapCollapsed = false;
  var _uiRefreshScheduled = false;
  var _searchSequence = 0;
  var _lastSubmittedSearchText = '';

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
          showTargetChooser: _targetChooserVisible,
          detailsPaneCollapsed: _detailsPaneCollapsed,
          diskUsageMapRenderer: widget.diskUsageMapRenderer,
          diskUsageMapCollapsed: _diskUsageMapCollapsed,
          onScan: _canRunScan ? () => _startScan(widget.store) : null,
          onPause: () => _cancelScan(widget.store),
          onPickTarget: () => unawaited(_pickScanTarget(widget.store)),
          onToggleDetailsPane: _toggleDetailsPane,
          onToggleDiskUsageMap: _toggleDiskUsageMap,
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

  bool get _canRunScan {
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
    required this.showTargetChooser,
    required this.detailsPaneCollapsed,
    required this.diskUsageMapCollapsed,
    this.diskUsageMapRenderer,
    required this.onScan,
    required this.onPause,
    required this.onPickTarget,
    required this.onToggleDetailsPane,
    required this.onToggleDiskUsageMap,
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
  final bool showTargetChooser;
  final bool detailsPaneCollapsed;
  final bool diskUsageMapCollapsed;
  final DiskUsageMapRenderer? diskUsageMapRenderer;
  final VoidCallback? onScan;
  final VoidCallback onPause;
  final VoidCallback onPickTarget;
  final VoidCallback onToggleDetailsPane;
  final VoidCallback onToggleDiskUsageMap;
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
    final scanActionLabel = _scanActionLabel(l10n, store);

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
                      statusText: _statusText(l10n, store),
                      searchController: searchController,
                      searchFocusNode: searchFocusNode,
                      currentSort: store.viewport.sort,
                      queryMode: store.viewport.mode,
                      activeTarget: activeTarget,
                      scanActionLabel: scanActionLabel,
                      canSearch: store.hasReadableSnapshot,
                      canSort: store.visibleRows.isNotEmpty,
                      canPickTarget:
                          store.canPickScanTarget &&
                          store.sessionStatus?.state != SessionState.running,
                      canScan: canScan,
                      onScan: onScan,
                      onPickTarget: onPickTarget,
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
                            )
                          : _WideWorkspace(
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
                              onChooseTarget: onChooseTarget,
                              diskUsageMapRenderer: diskUsageMapRenderer,
                              diskUsageMapCollapsed: diskUsageMapCollapsed,
                              onToggleDiskUsageMap: onToggleDiskUsageMap,
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

  String _statusText(CleanDiskLocalizations l10n, ScanWorkspaceStore store) {
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
  ) {
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

class _TargetChoiceRow extends StatelessWidget {
  const _TargetChoiceRow({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final ScanTargetChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? _ScanColors.selectedSoft : _ScanColors.innerPanel,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('first-run-target-choice-${choice.kind.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? _ScanColors.cyan : _ScanColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _targetChoiceIcon(choice.kind),
                  color: selected ? _ScanColors.cyan : _ScanColors.blue,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _targetChoiceLabel(l10n, choice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        choice.target.path.value,
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
    );
  }
}

class _WideWorkspace extends StatefulWidget {
  const _WideWorkspace({
    required this.store,
    required this.activeTarget,
    required this.canChangeTarget,
    required this.onScan,
    required this.onPickTarget,
    required this.onPermissionProbe,
    required this.onPermissionRepair,
    required this.onRefreshCleanupPreview,
    required this.onExecuteCleanup,
    required this.onRefreshFolderTarget,
    required this.onClearSearch,
    required this.onStoreChanged,
    required this.onChooseTarget,
    required this.diskUsageMapRenderer,
    required this.diskUsageMapCollapsed,
    required this.onToggleDiskUsageMap,
    required this.detailsPaneCollapsed,
    required this.onToggleDetailsPane,
  });

  static const _targetRailWidth = 292.0;
  static const _detailsPaneWidth = 380.0;
  static const _collapsedDetailsPaneWidth = 52.0;

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final bool canChangeTarget;
  final VoidCallback? onScan;
  final VoidCallback onPickTarget;
  final VoidCallback onPermissionProbe;
  final VoidCallback onPermissionRepair;
  final VoidCallback onRefreshCleanupPreview;
  final VoidCallback onExecuteCleanup;
  final ValueChanged<ScanTarget> onRefreshFolderTarget;
  final VoidCallback onClearSearch;
  final VoidCallback onStoreChanged;
  final ValueChanged<ScanTargetChoice> onChooseTarget;
  final DiskUsageMapRenderer? diskUsageMapRenderer;
  final bool diskUsageMapCollapsed;
  final VoidCallback onToggleDiskUsageMap;
  final bool detailsPaneCollapsed;
  final VoidCallback onToggleDetailsPane;

  @override
  State<_WideWorkspace> createState() => _WideWorkspaceState();
}

class _WideWorkspaceState extends State<_WideWorkspace> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showDetailsPane =
        widget.store.hasReadableSnapshot || widget.store.selectedNodeId != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('scan-target-rail'),
          width: _WideWorkspace._targetRailWidth,
          child: _TargetRail(
            store: widget.store,
            activeTarget: widget.activeTarget,
            canChangeTarget: widget.canChangeTarget,
            onPickTarget: widget.onPickTarget,
            onChooseTarget: widget.onChooseTarget,
            onPermissionProbe: widget.onPermissionProbe,
            onPermissionRepair: widget.onPermissionRepair,
          ),
        ),
        const _Divider.vertical(),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            notificationPredicate: (notification) => notification.depth == 0,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                children: [
                  if (_shouldShowMetricStrip(widget.store)) ...[
                    _MetricStrip(store: widget.store),
                    const SizedBox(height: 8),
                  ],
                  if (_shouldShowDiskUsageMap(
                    widget.store,
                    widget.diskUsageMapRenderer,
                  )) ...[
                    _DiskUsageMapPanel(
                      store: widget.store,
                      activeTarget: widget.activeTarget,
                      renderer: widget.diskUsageMapRenderer!,
                      collapsed: widget.diskUsageMapCollapsed,
                      compact: false,
                      onToggle: widget.onToggleDiskUsageMap,
                      onStoreChanged: widget.onStoreChanged,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _NodeTable(
                    store: widget.store,
                    activeTarget: widget.activeTarget,
                    onScan: widget.onScan,
                    showEmptyScanAction: false,
                    onRefreshFolderTarget: widget.onRefreshFolderTarget,
                    onClearSearch: widget.onClearSearch,
                    onStoreChanged: widget.onStoreChanged,
                    rowsScrollable: false,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDetailsPane) ...[
          const _Divider.vertical(),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: widget.detailsPaneCollapsed
                  ? _WideWorkspace._collapsedDetailsPaneWidth
                  : _WideWorkspace._detailsPaneWidth,
              child: ClipRect(
                child: widget.detailsPaneCollapsed
                    ? _CollapsedDetailsRail(
                        onExpand: widget.onToggleDetailsPane,
                      )
                    : _DetailsPane(
                        store: widget.store,
                        activeTarget: widget.activeTarget,
                        onRefreshCleanupPreview: widget.onRefreshCleanupPreview,
                        onExecuteCleanup: widget.onExecuteCleanup,
                        onStoreChanged: widget.onStoreChanged,
                        onCollapse: widget.onToggleDetailsPane,
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactWorkspace extends StatelessWidget {
  const _CompactWorkspace({
    required this.store,
    required this.activeTarget,
    required this.canChangeTarget,
    required this.onScan,
    required this.onPickTarget,
    required this.onPermissionProbe,
    required this.onPermissionRepair,
    required this.onRefreshCleanupPreview,
    required this.onExecuteCleanup,
    required this.onRefreshFolderTarget,
    required this.onClearSearch,
    required this.onStoreChanged,
    required this.diskUsageMapRenderer,
    required this.diskUsageMapCollapsed,
    required this.onToggleDiskUsageMap,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final bool canChangeTarget;
  final VoidCallback? onScan;
  final VoidCallback onPickTarget;
  final VoidCallback onPermissionProbe;
  final VoidCallback onPermissionRepair;
  final VoidCallback onRefreshCleanupPreview;
  final VoidCallback onExecuteCleanup;
  final ValueChanged<ScanTarget> onRefreshFolderTarget;
  final VoidCallback onClearSearch;
  final VoidCallback onStoreChanged;
  final DiskUsageMapRenderer? diskUsageMapRenderer;
  final bool diskUsageMapCollapsed;
  final VoidCallback onToggleDiskUsageMap;

  @override
  Widget build(BuildContext context) {
    final showDetailsPane =
        store.hasReadableSnapshot || store.selectedNodeId != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Column(
        children: [
          _TargetChips(
            activeTarget: activeTarget,
            canChangeTarget: canChangeTarget,
            onPickTarget: onPickTarget,
          ),
          const SizedBox(height: 10),
          _PermissionProofCard(
            proof: store.runtimeProof,
            onProbe: onPermissionProbe,
            onRepair: store.canRepairPermission ? onPermissionRepair : null,
          ),
          const SizedBox(height: 10),
          if (_shouldShowMetricStrip(store)) ...[
            _MetricStrip(store: store),
            const SizedBox(height: 10),
          ],
          if (_shouldShowDiskUsageMap(store, diskUsageMapRenderer)) ...[
            _DiskUsageMapPanel(
              store: store,
              activeTarget: activeTarget,
              renderer: diskUsageMapRenderer!,
              collapsed: diskUsageMapCollapsed,
              compact: true,
              onToggle: onToggleDiskUsageMap,
              onStoreChanged: onStoreChanged,
            ),
            const SizedBox(height: 10),
          ],
          _NodeTable(
            store: store,
            activeTarget: activeTarget,
            onScan: onScan,
            showEmptyScanAction: true,
            onRefreshFolderTarget: onRefreshFolderTarget,
            onClearSearch: onClearSearch,
            onStoreChanged: onStoreChanged,
            rowsScrollable: false,
          ),
          if (showDetailsPane) ...[
            const SizedBox(height: 10),
            _DetailsPane(
              store: store,
              activeTarget: activeTarget,
              onRefreshCleanupPreview: onRefreshCleanupPreview,
              onExecuteCleanup: onExecuteCleanup,
              onStoreChanged: onStoreChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiskUsageMapPanel extends StatelessWidget {
  const _DiskUsageMapPanel({
    required this.store,
    required this.activeTarget,
    required this.renderer,
    required this.collapsed,
    required this.compact,
    required this.onToggle,
    required this.onStoreChanged,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final DiskUsageMapRenderer renderer;
  final bool collapsed;
  final bool compact;
  final VoidCallback onToggle;
  final VoidCallback onStoreChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final projection = _diskUsageMapProjection(
      l10n: l10n,
      store: store,
      activeTarget: activeTarget,
    );
    if (projection == null) {
      return const SizedBox.shrink();
    }

    final toggleLabel = collapsed
        ? l10n.diskUsageMapExpandAction
        : l10n.diskUsageMapCollapseAction;

    return Container(
      key: const ValueKey('scan-disk-usage-map-panel'),
      decoration: _panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('scan-disk-usage-map-toggle-action'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggle,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          color: _ScanColors.cyan,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.diskUsageMapTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _diskUsageMapSummaryText(
                                  l10n,
                                  projection,
                                  store.diskUsageMapFocusNode,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: _ScanColors.textSoft,
                                      letterSpacing: 0,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('scan-disk-usage-map-toggle-button'),
                  tooltip: toggleLabel,
                  onPressed: onToggle,
                  color: _ScanColors.textSoft,
                  iconSize: 24,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: collapsed
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: SizedBox(
                      height: compact ? 220 : 260,
                      child: DiskUsageMapView(
                        projection: projection,
                        renderer: renderer,
                        labels: _diskUsageMapLabels(l10n),
                        style: _diskUsageMapStyle,
                        selectedNodeId: store.selectedNodeId?.value,
                        focusedNodeId: store.diskUsageMapFocusNodeId?.value,
                        onTileSelected: (tile) =>
                            _selectDiskUsageMapTile(tile, store),
                        onTileActivated: (tile) =>
                            _selectDiskUsageMapTile(tile, store),
                        dataFallbackMaxItems: compact ? 8 : 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _selectDiskUsageMapTile(
    DiskUsageMapTile tile,
    ScanWorkspaceStore store,
  ) {
    if (!_isSelectableDiskUsageMapTile(tile)) {
      return;
    }

    final nodeId = NodeId(tile.nodeId);
    store.toggleDiskUsageMapFocus(nodeId);
    unawaited(store.selectNode(nodeId).whenComplete(onStoreChanged));
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.compact,
    required this.statusText,
    required this.searchController,
    required this.searchFocusNode,
    required this.currentSort,
    required this.queryMode,
    required this.activeTarget,
    required this.scanActionLabel,
    required this.canSearch,
    required this.canSort,
    required this.canPickTarget,
    required this.canScan,
    required this.onScan,
    required this.onPickTarget,
    required this.onPause,
    required this.canCancelScan,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSort,
  });

  final bool compact;
  final String statusText;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ChildSort currentSort;
  final ScanQueryMode queryMode;
  final ScanTarget activeTarget;
  final String scanActionLabel;
  final bool canSearch;
  final bool canSort;
  final bool canPickTarget;
  final bool canScan;
  final VoidCallback? onScan;
  final VoidCallback onPickTarget;
  final VoidCallback onPause;
  final bool canCancelScan;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<ChildSort> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final windowWidth = MediaQuery.sizeOf(context).width;
    final showSearch = canSearch;
    final showCompactTools = showSearch || canSort;
    final search = showSearch
        ? _ToolbarSearchField(
            controller: searchController,
            focusNode: searchFocusNode,
            placeholder: l10n.searchPlaceholder,
            enabled: true,
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
          )
        : null;
    final sortText = _sortLabel(currentSort, l10n);
    final sortButtonText = _sortButtonLabel(currentSort, l10n);

    return Container(
      height: compact && showCompactTools ? 96 : 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _ScanColors.topBar,
        border: Border(bottom: BorderSide(color: _ScanColors.border)),
      ),
      child: compact
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const _WindowChromeInset(compact: true),
                    const _AppTitle(),
                    const Spacer(),
                    _SquareAction(
                      key: const ValueKey('scan-toolbar-scan-action'),
                      icon: Icons.play_arrow,
                      tooltip: scanActionLabel,
                      onTap: canScan ? onScan : null,
                      primary: true,
                    ),
                    if (canCancelScan) ...[
                      const SizedBox(width: 8),
                      _SquareAction(
                        icon: Icons.stop_circle_outlined,
                        tooltip: l10n.cancelScanAction,
                        onTap: onPause,
                      ),
                    ],
                  ],
                ),
                if (showCompactTools) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (search case final search?)
                        Expanded(child: search)
                      else
                        const Spacer(),
                      if (canSort) ...[
                        const SizedBox(width: 8),
                        _SortMenuButton(
                          iconOnly: true,
                          currentSort: currentSort,
                          tooltip: sortText,
                          selected: queryMode == ScanQueryMode.children,
                          onSort: onSort,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            )
          : Row(
              children: [
                const _WindowChromeInset(compact: false),
                const _AppTitle(),
                const SizedBox(width: 18),
                _Breadcrumb(
                  target: activeTarget,
                  onTap: canPickTarget ? onPickTarget : null,
                ),
                const SizedBox(width: 16),
                _PrimaryActionButton(
                  key: const ValueKey('scan-toolbar-scan-action'),
                  label: scanActionLabel,
                  onTap: canScan ? onScan : null,
                ),
                if (canCancelScan) ...[
                  const SizedBox(width: 12),
                  _SquareAction(
                    icon: Icons.stop_circle_outlined,
                    tooltip: l10n.cancelScanAction,
                    onTap: onPause,
                  ),
                ],
                const Spacer(),
                _WideToolbarTrailingActions(
                  showStatus: windowWidth >= 1360,
                  statusText: statusText,
                  search: search,
                  currentSort: currentSort,
                  sortText: sortText,
                  sortButtonText: sortButtonText,
                  sortSelected: queryMode == ScanQueryMode.children,
                  canSort: canSort,
                  onSort: onSort,
                ),
              ],
            ),
    );
  }

  String _sortLabel(ChildSort sort, CleanDiskLocalizations l10n) {
    return switch (sort) {
      ChildSort.sizeDesc =>
        '${l10n.sortFilterAction}: ${l10n.sortSizeDescLabel}',
      ChildSort.sizeAsc => '${l10n.sortFilterAction}: ${l10n.sortSizeAscLabel}',
      ChildSort.nameAsc => '${l10n.sortFilterAction}: ${l10n.sortNameAscLabel}',
      ChildSort.nameDesc =>
        '${l10n.sortFilterAction}: ${l10n.sortNameDescLabel}',
      ChildSort.insertion => l10n.sortFilterAction,
    };
  }

  String _sortButtonLabel(ChildSort sort, CleanDiskLocalizations l10n) {
    return switch (sort) {
      ChildSort.sizeDesc => l10n.sortSizeDescLabel,
      ChildSort.sizeAsc => l10n.sortSizeAscLabel,
      ChildSort.nameAsc => l10n.sortNameAscLabel,
      ChildSort.nameDesc => l10n.sortNameDescLabel,
      ChildSort.insertion => l10n.sortFilterAction,
    };
  }
}

class _WideToolbarTrailingActions extends StatelessWidget {
  const _WideToolbarTrailingActions({
    required this.showStatus,
    required this.statusText,
    required this.search,
    required this.currentSort,
    required this.sortText,
    required this.sortButtonText,
    required this.sortSelected,
    required this.canSort,
    required this.onSort,
  });

  final bool showStatus;
  final String statusText;
  final Widget? search;
  final ChildSort currentSort;
  final String sortText;
  final String sortButtonText;
  final bool sortSelected;
  final bool canSort;
  final ValueChanged<ChildSort> onSort;

  @override
  Widget build(BuildContext context) {
    final search = this.search;
    if (!showStatus && search == null && !canSort) {
      return const SizedBox.shrink();
    }
    final searchWidth = showStatus ? 220.0 : 280.0;
    return Row(
      children: [
        if (showStatus && (search != null || canSort)) ...[
          const SizedBox(width: 12),
          _StatusPill(text: statusText),
          const SizedBox(width: 14),
        ] else if (search != null || canSort)
          const SizedBox(width: 12),
        if (search != null) SizedBox(width: searchWidth, child: search),
        if (canSort) ...[
          const SizedBox(width: 10),
          _SortMenuButton(
            iconOnly: false,
            currentSort: currentSort,
            text: sortButtonText,
            tooltip: sortText,
            selected: sortSelected,
            onSort: onSort,
          ),
        ],
      ],
    );
  }
}

class _TargetRail extends StatelessWidget {
  const _TargetRail({
    required this.store,
    required this.activeTarget,
    required this.canChangeTarget,
    required this.onPickTarget,
    required this.onChooseTarget,
    required this.onPermissionProbe,
    required this.onPermissionRepair,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final bool canChangeTarget;
  final VoidCallback onPickTarget;
  final ValueChanged<ScanTargetChoice> onChooseTarget;
  final VoidCallback onPermissionProbe;
  final VoidCallback onPermissionRepair;

  @override
  Widget build(BuildContext context) {
    final choices = _railTargetChoices(store.targetChoices, activeTarget);
    final canChoosePresetTarget =
        store.sessionStatus?.state != SessionState.running;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TargetItem(
                itemKey: const ValueKey('scan-target-current'),
                actionKey: const ValueKey('scan-target-picker-action'),
                icon: Icons.folder_open_outlined,
                label: _targetDisplayName(activeTarget),
                size: _metricSummarySizeText(store),
                selected: true,
                onTap: canChangeTarget ? onPickTarget : null,
              ),
              if (choices.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final choice in choices)
                  _TargetItem(
                    itemKey: ValueKey('scan-target-choice-${choice.id}'),
                    actionKey: ValueKey(
                      'scan-target-choice-action-${choice.id}',
                    ),
                    icon: _targetChoiceIcon(choice.kind),
                    label: _targetChoiceLabel(context.cleanDiskL10n, choice),
                    selected: false,
                    onTap: canChoosePresetTarget
                        ? () => onChooseTarget(choice)
                        : null,
                  ),
              ],
              const SizedBox(height: 12),
              _PermissionProofCard(
                proof: store.runtimeProof,
                onProbe: onPermissionProbe,
                onRepair: store.canRepairPermission ? onPermissionRepair : null,
              ),
              if (_shouldShowMetricStrip(store)) ...[
                const SizedBox(height: 12),
                _DriveSummary(store: store, target: activeTarget),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetChips extends StatelessWidget {
  const _TargetChips({
    required this.activeTarget,
    required this.canChangeTarget,
    required this.onPickTarget,
  });

  final ScanTarget activeTarget;
  final bool canChangeTarget;
  final VoidCallback onPickTarget;

  @override
  Widget build(BuildContext context) {
    return _ChipTarget(
      icon: Icons.folder_open_outlined,
      label: _targetDisplayName(activeTarget),
      selected: true,
      onTap: canChangeTarget ? onPickTarget : null,
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.store});

  final ScanWorkspaceStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final summary = _metricSummary(store);
    final largest = summary.largest;
    final scannedItems = store.progress?.scannedItems;
    final isRunning = store.sessionStatus?.state == SessionState.running;
    final totalValue = summary.totalSize == null
        ? (isRunning ? l10n.metricScanningValue : l10n.metricNoDataValue)
        : _formatBytes(summary.totalSize!);
    final totalSubtitle = scannedItems == null
        ? (isRunning ? l10n.metricScanningSubtitle : l10n.metricNoDataValue)
        : '$scannedItems ${l10n.filesCountSuffix}';
    final largestValue =
        largest?.name ??
        (isRunning ? l10n.metricScanningValue : l10n.metricNoDataValue);
    final largestSubtitle = largest == null
        ? (isRunning
              ? l10n.metricScanningLargestSubtitle
              : l10n.metricRunScanSubtitle)
        : _formatSize(largest.size);
    final cells = [
      _MetricCell(
        label: l10n.totalScannedLabel,
        value: totalValue,
        subtitle: totalSubtitle,
        accent: _ScanColors.blue,
        icon: Icons.storage_outlined,
      ),
      _MetricCell(
        label: l10n.largestFolderLabel,
        value: largestValue,
        subtitle: largestSubtitle,
        accent: _ScanColors.violet,
        icon: Icons.folder,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        return Container(
          height: stacked ? 128 : 64,
          decoration: _panelDecoration,
          child: stacked
              ? Column(
                  children: [
                    Expanded(child: cells[0]),
                    const _Divider.horizontal(),
                    Expanded(child: cells[1]),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: cells[0]),
                    const _Divider.vertical(),
                    Expanded(child: cells[1]),
                  ],
                ),
        );
      },
    );
  }
}

class _NodeTable extends StatelessWidget {
  const _NodeTable({
    required this.store,
    required this.activeTarget,
    required this.onScan,
    required this.showEmptyScanAction,
    required this.onRefreshFolderTarget,
    required this.onClearSearch,
    required this.onStoreChanged,
    this.rowsScrollable = true,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final VoidCallback? onScan;
  final bool showEmptyScanAction;
  final ValueChanged<ScanTarget> onRefreshFolderTarget;
  final VoidCallback onClearSearch;
  final VoidCallback onStoreChanged;
  final bool rowsScrollable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final rows = store.visibleRows;
    final finalTreeRows = store.viewport.mode == ScanQueryMode.children
        ? store.visibleTreeRows
        : rows
              .map(
                (item) => ScanTreeNodeRow(
                  item: item,
                  depth: 0,
                  expanded: false,
                  loading: false,
                ),
              )
              .toList(growable: false);
    final showPartialRows =
        store.sessionStatus?.state == SessionState.running &&
        store.hasPartialScanTree;
    final tableRows = showPartialRows
        ? _partialTreeRows(store.partialVisibleTreeRows)
        : _treeRows(
            finalTreeRows,
            l10n: l10n,
            selectedNodeId: store.selectedNodeId,
            isQueued: store.isQueued,
            isMovedToTrash: store.isMovedToTrash,
            stale: store.viewport.isStale,
            disabled: false,
            allowExpansion: store.viewport.mode == ScanQueryMode.children,
          );
    final state = rows.isEmpty
        ? null
        : _tableState(l10n: l10n, store: store, issueCount: _issueCount(rows));
    final queryBanner = _queryModeBanner(l10n, store);

    return Column(
      children: [
        if (queryBanner != null) ...[
          _QueryModeBanner(state: queryBanner, onClearSearch: onClearSearch),
          const SizedBox(height: 8),
        ],
        if (state != null) ...[
          _TableStateBanner(state: state),
          const SizedBox(height: 8),
        ],
        _nodeTableBody(
          context: context,
          l10n: l10n,
          tableRows: tableRows,
          contextMenuRows: finalTreeRows,
          allowRowActions: true,
          allowExpansion:
              showPartialRows || store.viewport.mode == ScanQueryMode.children,
          allowContextMenu: !showPartialRows,
          queryBanner: queryBanner,
        ),
        if (!showPartialRows && store.canLoadMoreVisibleTreeRows) ...[
          const SizedBox(height: 8),
          _TreeLoadMoreButton(
            loading: store.isLoadingMoreVisibleTreeRows,
            onTap: () => unawaited(
              store.loadMoreVisibleTreeRows().whenComplete(onStoreChanged),
            ),
          ),
        ],
      ],
    );
  }

  Widget _nodeTableBody({
    required BuildContext context,
    required CleanDiskLocalizations l10n,
    required List<AppTreeTableRow> tableRows,
    required List<ScanTreeNodeRow> contextMenuRows,
    required bool allowRowActions,
    required bool allowExpansion,
    required bool allowContextMenu,
    required _RowsStateContent? queryBanner,
  }) {
    final table = AppTreeTable(
      columns: AppTreeTableColumnLabels(
        name: l10n.nameColumn,
        size: l10n.sizeColumn,
        percent: l10n.percentColumn,
        items: l10n.itemsColumn,
      ),
      rows: tableRows,
      showHeader: tableRows.isNotEmpty || queryBanner != null,
      emptyState: _EmptyRowsState(
        store: store,
        onScan: onScan,
        showScanAction: showEmptyScanAction,
      ),
      style: AppTreeTableStyle(
        backgroundColor: _ScanColors.panel,
        headerColor: _ScanColors.panelHeader,
        borderColor: _ScanColors.border,
        rowBorderColor: _ScanColors.border.withAlpha(130),
        selectedRowColor: _ScanColors.selectedRow,
        textColor: _ScanColors.text,
        selectedTextColor: Colors.white,
        mutedTextColor: _ScanColors.textSoft,
        iconColor: _ScanColors.blue,
        progressTrackColor: _ScanColors.progressTrack,
        progressColor: _ScanColors.blue,
        selectedProgressColor: _ScanColors.cyan,
        percentFlex: 3,
        itemsFlex: 1,
      ),
      rowsScrollable: rowsScrollable,
      onRowTap: allowRowActions
          ? (row) => unawaited(_selectAndMaybeToggle(row))
          : null,
      onRowToggleExpansion: allowRowActions && allowExpansion
          ? (row) => unawaited(_toggleExpandedFromRow(row))
          : null,
      onRowContextMenu:
          allowContextMenu && store.viewport.mode == ScanQueryMode.children
          ? (row, position) => unawaited(
              _showRowContextMenu(context, row, position, contextMenuRows),
            )
          : null,
    );
    if (!rowsScrollable) {
      return table;
    }
    return Expanded(child: table);
  }

  Future<void> _selectAndMaybeToggle(AppTreeTableRow row) async {
    final partialNodeId = _partialNodeIdFromTreeRowId(row.id);
    if (partialNodeId != null) {
      store.clearDiskUsageMapFocus();
      if (row.hasChildren) {
        await store.togglePartialTreeNode(partialNodeId);
        onStoreChanged();
      }
      return;
    }

    final nodeId = NodeId(row.id);
    store.clearDiskUsageMapFocus();
    await store.selectNode(nodeId);
    if (store.viewport.mode == ScanQueryMode.children && row.hasChildren) {
      await store.toggleTreeNode(nodeId);
    }
    onStoreChanged();
  }

  Future<void> _toggleExpandedFromRow(AppTreeTableRow row) async {
    final partialNodeId = _partialNodeIdFromTreeRowId(row.id);
    if (partialNodeId != null) {
      await store.togglePartialTreeNode(partialNodeId);
      onStoreChanged();
      return;
    }

    await store.toggleTreeNode(NodeId(row.id));
    onStoreChanged();
  }

  Future<void> _showRowContextMenu(
    BuildContext context,
    AppTreeTableRow row,
    Offset position,
    List<ScanTreeNodeRow> tableRows,
  ) async {
    final l10n = context.cleanDiskL10n;
    final nodeId = NodeId(row.id);
    NodePageItem? item;
    for (final treeRow in tableRows) {
      if (treeRow.item.nodeId == nodeId) {
        item = treeRow.item;
        break;
      }
    }
    if (item == null) {
      return;
    }

    store.clearDiskUsageMapFocus();
    await store.selectNode(nodeId);
    if (!context.mounted) {
      return;
    }
    onStoreChanged();

    final displayPath = _displayPathForSelection(
      store: store,
      target: activeTarget,
      selected: item,
    );
    final canRefresh =
        item.kind == NodeKind.directory &&
        _isRevealableDisplayPath(displayPath) &&
        store.sessionStatus?.state != SessionState.running;
    final action = await showMenu<_NodeContextMenuAction>(
      context: context,
      color: _ScanColors.panel,
      surfaceTintColor: Colors.transparent,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem<_NodeContextMenuAction>(
          key: const ValueKey('node-context-refresh-folder-action'),
          enabled: canRefresh,
          value: _NodeContextMenuAction.refreshFolder,
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 18, color: _ScanColors.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.nodeContextRefreshFolderAction,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(context).copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (action != _NodeContextMenuAction.refreshFolder || !canRefresh) {
      return;
    }

    onRefreshFolderTarget(
      ScanTarget(
        path: ScanTargetPath(displayPath),
        scope: TargetScope.localPath,
        boundaryPolicy: activeTarget.boundaryPolicy,
        hardlinkPolicy: activeTarget.hardlinkPolicy,
      ),
    );
  }
}

enum _NodeContextMenuAction { refreshFolder }

class _TreeLoadMoreButton extends StatelessWidget {
  const _TreeLoadMoreButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: OutlinedButton.icon(
        key: const ValueKey('scan-tree-load-more-action'),
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more, size: 18),
        label: Text(loading ? l10n.loadMoreRowsBusy : l10n.loadMoreRowsAction),
        style: OutlinedButton.styleFrom(
          foregroundColor: _ScanColors.cyan,
          side: const BorderSide(color: _ScanColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({
    required this.store,
    required this.activeTarget,
    required this.onRefreshCleanupPreview,
    required this.onExecuteCleanup,
    required this.onStoreChanged,
    this.onCollapse,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final VoidCallback onRefreshCleanupPreview;
  final VoidCallback onExecuteCleanup;
  final VoidCallback onStoreChanged;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final onCollapse = this.onCollapse;
    final details = store.selectedDetails;
    final displayPath = details == null
        ? null
        : _displayPathForSelection(
            store: store,
            target: activeTarget,
            selected: details.summary,
          );
    final hasRevealableDisplayPath =
        displayPath != null && _isRevealableDisplayPath(displayPath);
    final canReveal =
        hasRevealableDisplayPath &&
        store.canRevealPath &&
        !store.isRevealingPath;
    final alreadyQueued =
        details != null &&
        store.queuedItems.any((item) => item.nodeId == details.summary.nodeId);
    final movedToTrash =
        details != null && store.isMovedToTrash(details.summary.nodeId);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Container(
            decoration: _panelDecoration,
            padding: const EdgeInsets.all(16),
            child: details == null
                ? _EmptyDetailsState()
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionCaption(l10n.detailsTitle.toUpperCase()),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Icon(
                              _nodeKindIcon(details.summary.kind),
                              key: const ValueKey('details-kind-icon'),
                              color: movedToTrash
                                  ? _ScanColors.pink
                                  : _ScanColors.blue,
                              size: 46,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    details.summary.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                  ),
                                  Text(
                                    l10n.detailsItemsCount(
                                      count: details.summary.childCount,
                                    ),
                                    style: _bodyStyle(
                                      context,
                                    ).copyWith(color: _ScanColors.textSoft),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatSize(details.summary.size),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: movedToTrash
                                        ? _ScanColors.pink
                                        : _ScanColors.cyan,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                        if (movedToTrash) ...[
                          const SizedBox(height: 12),
                          _InlineDangerBanner(
                            key: const ValueKey('details-moved-to-trash-hint'),
                            message: l10n.movedToTrashDetailsHint,
                          ),
                        ],
                        const SizedBox(height: 22),
                        _DetailLine(
                          label: l10n.detailsTypeLabel,
                          value: _nodeKindText(l10n, details.summary.kind),
                        ),
                        _DetailLine(
                          label: l10n.detailsPathLabel,
                          value: displayPath ?? details.summary.name,
                        ),
                        _DetailLine(
                          label: l10n.detailsCreatedLabel,
                          value: _formatNodeTimestamp(
                            l10n,
                            details.timestamps?.createdAtUnixMs,
                          ),
                        ),
                        _DetailLine(
                          label: l10n.detailsModifiedLabel,
                          value: _formatNodeTimestamp(
                            l10n,
                            details.timestamps?.modifiedAtUnixMs,
                          ),
                        ),
                        _DetailLine(
                          label: l10n.detailsChildrenLabel,
                          value: '${details.summary.childCount}',
                        ),
                        _DetailLine(
                          label: l10n.detailsAccountingLabel,
                          value: _sizeQuantityText(
                            l10n,
                            details.summary.size.quantity,
                          ),
                        ),
                        _DetailLine(
                          label: l10n.detailsConfidenceLabel,
                          value: _sizeConfidenceText(
                            l10n,
                            details.summary.size.confidence,
                          ),
                        ),
                        _DetailLine(
                          label: l10n.detailsFlagsLabel,
                          value: _nodeFlagsText(l10n, details.summary.flags),
                        ),
                        _DetailLine(
                          label: l10n.detailsWarningsLabel,
                          value: '${details.issues.length}',
                        ),
                        if (details.issues.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _IssueList(issues: details.issues),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _OutlinedAction(
                                key: const ValueKey('details-reveal-action'),
                                icon: store.isRevealingPath
                                    ? Icons.hourglass_empty_outlined
                                    : Icons.folder_open_outlined,
                                label: store.isRevealingPath
                                    ? l10n.revealBusyAction
                                    : l10n.revealAction,
                                onTap: canReveal
                                    ? () {
                                        unawaited(
                                          store
                                              .revealPath(
                                                ScanTargetPath(displayPath),
                                              )
                                              .whenComplete(onStoreChanged),
                                        );
                                        onStoreChanged();
                                      }
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _OutlinedAction(
                                key: const ValueKey(
                                  'details-add-to-queue-action',
                                ),
                                icon: alreadyQueued
                                    ? Icons.check_circle_outline
                                    : movedToTrash
                                    ? Icons.delete_outline
                                    : Icons.add_circle_outline,
                                label: movedToTrash
                                    ? l10n.movedToTrashRowLabel
                                    : alreadyQueued
                                    ? l10n.reviewAddedAction
                                    : l10n.addToQueueAction,
                                accent: movedToTrash
                                    ? _ScanColors.pink
                                    : _ScanColors.cyan,
                                onTap: alreadyQueued || movedToTrash
                                    ? null
                                    : () {
                                        store.queueSelectedNode();
                                        onStoreChanged();
                                      },
                              ),
                            ),
                          ],
                        ),
                        if (store.lastRevealFailure case final failure?) ...[
                          const SizedBox(height: 10),
                          _InlineFailureBanner(message: failure.message),
                        ],
                        if (displayPath != null &&
                            !hasRevealableDisplayPath) ...[
                          const SizedBox(height: 10),
                          _InlineInfoBanner(
                            key: const ValueKey(
                              'details-reveal-unavailable-hint',
                            ),
                            message: l10n.revealUnavailableDisplayPath,
                          ),
                        ],
                        const SizedBox(height: 20),
                        _DeleteQueuePreview(
                          store: store,
                          onRefreshPreview: onRefreshCleanupPreview,
                          onExecuteCleanup: onExecuteCleanup,
                          onStoreChanged: onStoreChanged,
                        ),
                      ],
                    ),
                  ),
          ),
          if (onCollapse != null)
            Positioned(
              top: 10,
              right: 10,
              child: _PaneToggleAction(
                buttonKey: const ValueKey('details-pane-collapse-action'),
                icon: Icons.keyboard_double_arrow_right,
                tooltip: l10n.detailsTitle,
                onTap: onCollapse,
              ),
            ),
        ],
      ),
    );
  }
}

class _CollapsedDetailsRail extends StatelessWidget {
  const _CollapsedDetailsRail({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return Container(
      key: const ValueKey('details-pane-collapsed-rail'),
      width: _WideWorkspace._collapsedDetailsPaneWidth,
      color: _ScanColors.background,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          _PaneToggleAction(
            buttonKey: const ValueKey('details-pane-expand-action'),
            icon: Icons.keyboard_double_arrow_left,
            tooltip: l10n.detailsTitle,
            onTap: onExpand,
          ),
          const SizedBox(height: 8),
          const Icon(Icons.info_outline, color: _ScanColors.violet, size: 20),
        ],
      ),
    );
  }
}

class _ScanFooter extends StatefulWidget {
  const _ScanFooter({required this.store, required this.onCancelScan});

  final ScanWorkspaceStore store;
  final VoidCallback onCancelScan;

  @override
  State<_ScanFooter> createState() => _ScanFooterState();
}

class _ScanFooterState extends State<_ScanFooter>
    with SingleTickerProviderStateMixin {
  static const _runningProgressCap = 0.94;
  static const _runningProgressDuration = Duration(minutes: 3);

  late final AnimationController _progressController;
  ScanSessionId? _runningSessionId;
  DateTime? _runningStartedAt;
  Timer? _runningProgressTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this);
    _syncProgressController();
  }

  @override
  void didUpdateWidget(_ScanFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncProgressController();
  }

  @override
  void dispose() {
    _runningProgressTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _syncProgressController() {
    final status = widget.store.sessionStatus;
    final running = status?.state == SessionState.running;
    final hasSnapshot = widget.store.activeSnapshotId != null;

    if (running) {
      final sessionId = status?.sessionId;
      if (_runningSessionId != sessionId) {
        _runningSessionId = sessionId;
        _runningStartedAt = DateTime.now();
        _progressController
          ..stop()
          ..value = 0;
      }
      _ensureRunningProgressTimer();
      _syncEstimatedRunningProgress();
      return;
    }

    _runningSessionId = null;
    _runningStartedAt = null;
    _runningProgressTimer?.cancel();
    _runningProgressTimer = null;
    _progressController.stop();
    if (hasSnapshot) {
      if (_progressController.value < 1) {
        _progressController.animateTo(
          1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (_progressController.value != 0) {
      _progressController.value = 0;
    }
  }

  void _ensureRunningProgressTimer() {
    if (_runningProgressTimer != null) {
      return;
    }
    _runningProgressTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _syncEstimatedRunningProgress(),
    );
  }

  void _syncEstimatedRunningProgress() {
    if (!mounted) {
      return;
    }
    if (widget.store.sessionStatus?.state != SessionState.running) {
      _runningProgressTimer?.cancel();
      _runningProgressTimer = null;
      return;
    }

    final startedAt = _runningStartedAt;
    if (startedAt == null) {
      return;
    }

    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final rawFraction =
        elapsedMs / _runningProgressDuration.inMilliseconds.toDouble();
    final easedFraction = Curves.easeOutCubic.transform(
      rawFraction.clamp(0.0, 1.0),
    );
    final nextValue = (easedFraction * _runningProgressCap).clamp(
      0.0,
      _runningProgressCap,
    );
    if (nextValue > _progressController.value) {
      _progressController.value = nextValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final progress = widget.store.progress;
    final running = widget.store.sessionStatus?.state == SessionState.running;
    final canCancelScan = running && widget.store.canCancelScan;
    final hasSnapshot = widget.store.activeSnapshotId != null;
    final hasBlockingRuntimeState =
        widget.store.daemonAvailability == ScanDaemonAvailability.offline ||
        widget.store.daemonAvailability == ScanDaemonAvailability.incompatible;
    final shouldHideFooter =
        (!running && !hasSnapshot && !hasBlockingRuntimeState) ||
        (widget.store.sessionStatus?.state == SessionState.completed &&
            widget.store.hasReadableSnapshot);
    if (shouldHideFooter) {
      return const SizedBox.shrink(key: ValueKey('scan-footer-hidden'));
    }

    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        final progressFraction = _progressController.value.clamp(0.0, 1.0);
        final statusText = running
            ? '${l10n.scanRunningStatus} ${_progressPercentText(progressFraction)}'
            : _footerStatus(l10n, widget.store);

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;

            return Container(
              key: const ValueKey('scan-footer'),
              height: compact ? 70 : 56,
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 24),
              decoration: const BoxDecoration(
                color: _ScanColors.footer,
                border: Border(top: BorderSide(color: _ScanColors.border)),
              ),
              child: compact
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            _FooterStatusIndicator(
                              running: running,
                              completed: hasSnapshot,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                statusText,
                                overflow: TextOverflow.ellipsis,
                                style: _bodyStyle(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (canCancelScan) ...[
                              const SizedBox(width: 8),
                              _FooterStopAction(
                                tooltip: l10n.cancelScanAction,
                                onTap: widget.onCancelScan,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        _FooterProgress(progressFraction: progressFraction),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: _FooterStat(
                                label: l10n.progressFilesScannedLabel,
                                value: _progressItemsText(
                                  l10n,
                                  progress,
                                  isRunning: running,
                                ),
                                compact: true,
                              ),
                            ),
                            Expanded(
                              child: _FooterStat(
                                label: l10n.progressElapsedLabel,
                                value: _progressElapsedText(
                                  l10n,
                                  progress,
                                  isRunning: running,
                                ),
                                compact: true,
                              ),
                            ),
                            Expanded(
                              child: _FooterStat(
                                label: l10n.progressThroughputLabel,
                                value: _progressThroughputText(
                                  l10n,
                                  progress,
                                  isRunning: running,
                                ),
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _FooterStatusIndicator(
                                    running: running,
                                    completed: hasSnapshot,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    statusText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _bodyStyle(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              _FooterProgress(
                                progressFraction: progressFraction,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        if (canCancelScan) ...[
                          _FooterStopAction(
                            tooltip: l10n.cancelScanAction,
                            onTap: widget.onCancelScan,
                          ),
                          const SizedBox(width: 16),
                        ],
                        _FooterStat(
                          label: l10n.progressFilesScannedLabel,
                          value: _progressItemsText(
                            l10n,
                            progress,
                            isRunning: running,
                          ),
                        ),
                        _FooterStat(
                          label: l10n.progressElapsedLabel,
                          value: _progressElapsedText(
                            l10n,
                            progress,
                            isRunning: running,
                          ),
                        ),
                        _FooterStat(
                          label: l10n.progressThroughputLabel,
                          value: _progressThroughputText(
                            l10n,
                            progress,
                            isRunning: running,
                          ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  String _footerStatus(CleanDiskLocalizations l10n, ScanWorkspaceStore store) {
    return switch (store.daemonAvailability) {
      ScanDaemonAvailability.offline => l10n.scanOfflineStatus,
      ScanDaemonAvailability.incompatible => l10n.scanIncompatibleStatus,
      _ =>
        store.activeSnapshotId == null
            ? l10n.scanReadyStatus
            : l10n.scanCompletedStatus,
    };
  }

  String _progressPercentText(double value) {
    final percent = (value * 100).floor().clamp(0, 99);
    return '$percent%';
  }
}

class _FooterStatusIndicator extends StatelessWidget {
  const _FooterStatusIndicator({
    required this.running,
    required this.completed,
  });

  final bool running;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    if (running) {
      return const SizedBox(
        key: ValueKey('scan-footer-running-indicator'),
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _ScanColors.cyan,
        ),
      );
    }

    if (completed) {
      return Container(
        key: const ValueKey('scan-footer-completed-indicator'),
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _ScanColors.cyan,
        ),
        child: const Icon(Icons.check, size: 14, color: _ScanColors.background),
      );
    }

    return SizedBox(
      key: const ValueKey('scan-footer-idle-indicator'),
      width: 18,
      height: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _ScanColors.cyan, width: 2),
        ),
      ),
    );
  }
}

class _FooterProgress extends StatelessWidget {
  const _FooterProgress({required this.progressFraction});

  final double progressFraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        key: const ValueKey('scan-footer-progress'),
        value: progressFraction.clamp(0.0, 1.0),
        minHeight: 4,
        backgroundColor: _ScanColors.progressTrack,
        valueColor: const AlwaysStoppedAnimation<Color>(_ScanColors.cyan),
      ),
    );
  }
}

class _FooterStopAction extends StatelessWidget {
  const _FooterStopAction({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        key: const ValueKey('scan-footer-stop-action'),
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        icon: const Icon(Icons.stop_rounded),
        color: _ScanColors.pink,
        style: IconButton.styleFrom(
          backgroundColor: _ScanColors.input,
          side: const BorderSide(color: _ScanColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _EmptyRowsState extends StatelessWidget {
  const _EmptyRowsState({
    required this.store,
    required this.onScan,
    required this.showScanAction,
  });

  final ScanWorkspaceStore store;
  final VoidCallback? onScan;
  final bool showScanAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final state = _emptyRowsState(l10n: l10n, store: store);
    final canShowScanAction =
        showScanAction &&
        onScan != null &&
        store.pageLoadState != ScanPageLoadState.loading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final lifted = constraints.maxHeight >= 360;
        return Align(
          alignment: Alignment(0, lifted ? -0.34 : 0),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                key: const ValueKey('scan-empty-state-content'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(state.icon, color: state.accent, size: 34),
                  const SizedBox(height: 10),
                  Text(
                    state.title,
                    textAlign: TextAlign.center,
                    style: _titleStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: _bodyStyle(
                      context,
                    ).copyWith(color: _ScanColors.textSoft),
                  ),
                  if (canShowScanAction) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const ValueKey('scan-empty-scan-action'),
                      onPressed: onScan,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(
                        store.sessionStatus?.state == SessionState.completed
                            ? l10n.scanAgainAction
                            : l10n.scanAction,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _ScanColors.cyan,
                        foregroundColor: _ScanColors.background,
                        minimumSize: const Size(150, 38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TableStateBanner extends StatelessWidget {
  const _TableStateBanner({required this.state});

  final _RowsStateContent state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: state.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: state.accent.withAlpha(110)),
      ),
      child: Row(
        children: [
          Icon(state.icon, color: state.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.message,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueryModeBanner extends StatelessWidget {
  const _QueryModeBanner({required this.state, required this.onClearSearch});

  final _RowsStateContent state;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: state.accent.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: state.accent.withAlpha(105)),
      ),
      child: Row(
        children: [
          Icon(state.icon, color: state.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            key: const ValueKey('scan-query-clear-action'),
            onPressed: onClearSearch,
            icon: const Icon(Icons.account_tree_outlined, size: 16),
            label: Text(l10n.searchBackToTreeAction),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ScanColors.cyan,
              side: BorderSide(color: _ScanColors.cyan.withAlpha(150)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineFailureBanner extends StatelessWidget {
  const _InlineFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _ScanColors.yellow.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.yellow.withAlpha(120)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _ScanColors.yellow, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineInfoBanner extends StatelessWidget {
  const _InlineInfoBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _ScanColors.cyan.withAlpha(16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.cyan.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _ScanColors.cyan, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineDangerBanner extends StatelessWidget {
  const _InlineDangerBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _ScanColors.pink.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.pink.withAlpha(100)),
      ),
      child: Row(
        children: [
          const Icon(Icons.delete_outline, color: _ScanColors.pink, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});

  final List<ScanIssue> issues;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ScanColors.innerPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.yellow.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in issues.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _issueIcon(issue.severity),
                    color: _issueColor(issue.severity),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _issueText(issue),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: _bodyStyle(
                        context,
                      ).copyWith(color: _ScanColors.textSoft),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

final class _RowsStateContent {
  const _RowsStateContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
}

class _EmptyDetailsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: _ScanColors.violet, size: 40),
          const SizedBox(height: 12),
          Text(
            context.cleanDiskL10n.noSelectionTitle,
            style: _titleStyle(context),
          ),
          const SizedBox(height: 6),
          Text(
            context.cleanDiskL10n.noSelectionText,
            style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionCaption(label.toUpperCase()),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(context).copyWith(
                    color: _ScanColors.textSoft,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetItem extends StatefulWidget {
  const _TargetItem({
    required this.itemKey,
    required this.icon,
    required this.label,
    this.actionKey,
    this.size,
    this.selected = false,
    this.onTap,
  });

  final Key itemKey;
  final Key? actionKey;
  final IconData icon;
  final String label;
  final String? size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_TargetItem> createState() => _TargetItemState();
}

class _TargetItemState extends State<_TargetItem> {
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
    final isInteractive = widget.onTap != null;
    final backgroundColor = widget.selected
        ? (_hovered && isInteractive
              ? _ScanColors.selectedSoft.withValues(alpha: 0.92)
              : _ScanColors.selectedSoft)
        : (_hovered && isInteractive
              ? _ScanColors.selectedSoft.withValues(alpha: 0.52)
              : Colors.transparent);
    final borderColor = _hovered && isInteractive
        ? _ScanColors.cyan.withValues(alpha: 0.58)
        : _ScanColors.border;
    final content = Container(
      key: widget.itemKey,
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: widget.selected || (_hovered && isInteractive)
            ? Border.all(color: borderColor)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            widget.icon,
            size: 22,
            color: widget.selected ? _ScanColors.cyan : Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(
                context,
              ).copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          if (widget.size case final size?) ...[
            const SizedBox(width: 8),
            Text(size, style: _monoStyle(context)),
          ],
        ],
      ),
    );
    if (!isInteractive) {
      return content;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: widget.actionKey,
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          focusColor: _ScanColors.cyan.withValues(alpha: 0.10),
          highlightColor: _ScanColors.cyan.withValues(alpha: 0.08),
          hoverColor: Colors.transparent,
          splashColor: _ScanColors.cyan.withValues(alpha: 0.12),
          child: content,
        ),
      ),
    );
  }
}

class _ChipTarget extends StatefulWidget {
  const _ChipTarget({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_ChipTarget> createState() => _ChipTargetState();
}

class _ChipTargetState extends State<_ChipTarget> {
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
    final isInteractive = widget.onTap != null;
    final backgroundColor = widget.selected
        ? (_hovered && isInteractive
              ? _ScanColors.selectedSoft.withValues(alpha: 0.92)
              : _ScanColors.selectedSoft)
        : (_hovered && isInteractive
              ? _ScanColors.selectedSoft.withValues(alpha: 0.52)
              : _ScanColors.panel);
    final content = Container(
      key: widget.onTap == null && widget.selected
          ? const ValueKey('scan-target-chip-current')
          : null,
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _hovered && isInteractive
              ? _ScanColors.cyan.withValues(alpha: 0.74)
              : widget.selected
              ? _ScanColors.cyan
              : _ScanColors.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            widget.icon,
            color: widget.selected ? _ScanColors.cyan : Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(
                color: widget.selected ? _ScanColors.cyan : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
    if (!isInteractive) {
      return content;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: widget.selected
              ? const ValueKey('scan-target-chip-current')
              : null,
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          focusColor: _ScanColors.cyan.withValues(alpha: 0.10),
          highlightColor: _ScanColors.cyan.withValues(alpha: 0.08),
          hoverColor: Colors.transparent,
          splashColor: _ScanColors.cyan.withValues(alpha: 0.12),
          child: content,
        ),
      ),
    );
  }
}

class _DriveSummary extends StatelessWidget {
  const _DriveSummary({required this.store, required this.target});

  final ScanWorkspaceStore store;
  final ScanTarget target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final isRunning = store.sessionStatus?.state == SessionState.running;
    final sizeText =
        _metricSummarySizeText(store) ??
        (isRunning ? l10n.metricScanningValue : l10n.metricNoDataValue);
    return Container(
      key: const ValueKey('scan-drive-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _targetDisplayName(target),
            style: _bodyStyle(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: store.hasReadableSnapshot ? 1 : 0,
              minHeight: 7,
              backgroundColor: _ScanColors.progressTrack,
              valueColor: const AlwaysStoppedAnimation<Color>(
                _ScanColors.violet,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            sizeText,
            style: _monoStyle(context).copyWith(color: _ScanColors.textSoft),
          ),
          const SizedBox(height: 4),
          Text(
            target.path.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(
              context,
            ).copyWith(color: _ScanColors.cyan, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PermissionProofCard extends StatelessWidget {
  const _PermissionProofCard({
    required this.proof,
    this.onProbe,
    this.onRepair,
  });

  final RuntimeProof proof;
  final VoidCallback? onProbe;
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final identity = proof.scannerIdentity.verification;
    final probe = proof.permissionProbe.status;
    final warning = _permissionWarningData(l10n, proof);
    final checkedAt = proof.permissionProbe.checkedAtUnixMs;
    final showDetailedProof = _shouldShowDetailedPermissionProof(
      proof,
      onRepair: onRepair,
    );
    final summaryLines = [
      _ProofStatusData(
        label: l10n.permissionProbeLabel,
        value: _permissionProbeText(l10n, probe),
        color: _permissionProbeColor(probe),
      ),
      if (_shouldShowPermissionCheckedLine(probe, checkedAt))
        _ProofStatusData(
          label: l10n.permissionCheckedLabel,
          value: _lastProbeText(l10n, checkedAt),
          color: checkedAt == null ? _ScanColors.textSoft : _ScanColors.cyan,
        ),
    ];
    final detailLines = [
      _ProofStatusData(
        label: l10n.permissionIdentityLabel,
        value: _identityProofText(l10n, identity),
        color: _identityProofColor(identity),
      ),
      _ProofStatusData(
        label: l10n.permissionScannerLabel,
        value: _scannerProcessText(l10n, proof.scannerIdentity.processKind),
        color: _scannerProcessColor(proof.scannerIdentity.processKind),
      ),
      _ProofStatusData(
        label: l10n.permissionActionLabel,
        value: _permissionActionText(l10n, proof),
        color: _permissionActionColor(proof),
      ),
      _ProofStatusData(
        label: l10n.permissionPackageLabel,
        value: _packagingProofText(l10n, proof.packaging),
        color: _packagingProofColor(proof.packaging),
      ),
      _ProofStatusData(
        label: l10n.permissionUpdateLabel,
        value: _updateSafetyText(l10n, proof.packaging.updateSafety),
        color: _updateSafetyColor(proof.packaging.updateSafety),
      ),
    ];

    if (_isNeutralPermissionProof(
      proof,
      warning: warning,
      onRepair: onRepair,
    )) {
      return const _NeutralPermissionProofCard();
    }

    if (_shouldUseCompactPermissionProof(
      proof,
      warning: warning,
      showDetailedProof: showDetailedProof,
      onRepair: onRepair,
    )) {
      return _CompactPermissionProofCard(
        proof: proof,
        warning: warning,
        onProbe: onProbe,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ScanColors.innerPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: _ScanColors.cyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.permissionProofTitle,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: onProbe,
                  tooltip: l10n.permissionProbeAction,
                  icon: const Icon(Icons.refresh, size: 17),
                  color: _ScanColors.cyan,
                  style: IconButton.styleFrom(
                    backgroundColor: _ScanColors.input,
                    side: const BorderSide(color: _ScanColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (onRepair != null) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    key: const ValueKey('permission-repair-action'),
                    onPressed: onRepair,
                    tooltip: _permissionActionText(l10n, proof),
                    icon: const Icon(Icons.settings_suggest_outlined, size: 17),
                    color: _ScanColors.yellow,
                    style: IconButton.styleFrom(
                      backgroundColor: _ScanColors.input,
                      side: const BorderSide(color: _ScanColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _ProofStatusGrid(lines: summaryLines),
          if (showDetailedProof) ...[
            const SizedBox(height: 10),
            _ProofStatusGrid(lines: detailLines),
          ],
          if (warning != null) ...[
            const SizedBox(height: 10),
            _PermissionWarning(warning: warning),
          ],
        ],
      ),
    );
  }
}

class _CompactPermissionProofCard extends StatelessWidget {
  const _CompactPermissionProofCard({
    required this.proof,
    required this.warning,
    required this.onProbe,
  });

  final RuntimeProof proof;
  final _PermissionWarningData? warning;
  final VoidCallback? onProbe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final status = _permissionProbeText(l10n, proof.permissionProbe.status);
    final checked = _lastProbeText(l10n, proof.permissionProbe.checkedAtUnixMs);
    return Container(
      key: const ValueKey('permission-proof-compact'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _ScanColors.innerPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: _ScanColors.cyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.permissionProofTitle,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          status,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle(context).copyWith(
                            color: _ScanColors.cyan,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: _ScanColors.textSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            checked,
                            overflow: TextOverflow.ellipsis,
                            style: _bodyStyle(
                              context,
                            ).copyWith(color: _ScanColors.textSoft),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: onProbe,
                  tooltip: l10n.permissionProbeAction,
                  icon: const Icon(Icons.refresh, size: 17),
                  color: _ScanColors.cyan,
                  style: IconButton.styleFrom(
                    backgroundColor: _ScanColors.input,
                    side: const BorderSide(color: _ScanColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (warning case final warning?) ...[
            const SizedBox(height: 6),
            _CompactPermissionWarningLine(warning: warning),
          ],
        ],
      ),
    );
  }
}

class _CompactPermissionWarningLine extends StatelessWidget {
  const _CompactPermissionWarningLine({required this.warning});

  final _PermissionWarningData warning;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('permission-warning-compact'),
      children: [
        Icon(warning.icon, color: warning.color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${warning.title}: ${warning.message}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
          ),
        ),
      ],
    );
  }
}

class _NeutralPermissionProofCard extends StatelessWidget {
  const _NeutralPermissionProofCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return SizedBox(
      key: const ValueKey('permission-proof-neutral'),
      width: double.infinity,
      height: 32,
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: _ScanColors.cyan,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.permissionNeutralProbeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ProofStatusData {
  const _ProofStatusData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _ProofStatusGrid extends StatelessWidget {
  const _ProofStatusGrid({required this.lines});

  final List<_ProofStatusData> lines;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ProofStatusColumn(lines: _evenLines)),
              const SizedBox(width: 16),
              Expanded(child: _ProofStatusColumn(lines: _oddLines)),
            ],
          );
        }
        return _ProofStatusColumn(lines: lines);
      },
    );
  }

  List<_ProofStatusData> get _evenLines {
    return [
      for (var index = 0; index < lines.length; index += 1)
        if (index.isEven) lines[index],
    ];
  }

  List<_ProofStatusData> get _oddLines {
    return [
      for (var index = 0; index < lines.length; index += 1)
        if (index.isOdd) lines[index],
    ];
  }
}

class _PermissionWarning extends StatelessWidget {
  const _PermissionWarning({required this.warning});

  final _PermissionWarningData warning;

  @override
  Widget build(BuildContext context) {
    final compact = warning.compact;
    return Container(
      key: ValueKey(
        compact ? 'permission-warning-compact' : 'permission-warning-prominent',
      ),
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warning.color.withAlpha(compact ? 14 : 20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warning.color.withAlpha(compact ? 90 : 120)),
      ),
      child: Row(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Icon(warning.icon, color: warning.color, size: compact ? 17 : 18),
          const SizedBox(width: 8),
          Expanded(
            child: compact
                ? Text(
                    '${warning.title}: ${warning.message}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(
                      context,
                    ).copyWith(color: _ScanColors.textSoft),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        warning.title,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        warning.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle(
                          context,
                        ).copyWith(color: _ScanColors.textSoft),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProofStatusColumn extends StatelessWidget {
  const _ProofStatusColumn({required this.lines});

  final List<_ProofStatusData> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < lines.length; index += 1) ...[
          if (index > 0) const SizedBox(height: 6),
          _ProofStatusLine(
            label: lines[index].label,
            value: lines[index].value,
            color: lines[index].color,
          ),
        ],
      ],
    );
  }
}

class _ProofStatusLine extends StatelessWidget {
  const _ProofStatusLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 280;
        final labelText = Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
        );
        final valueText = Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _bodyStyle(
            context,
          ).copyWith(color: color, fontWeight: FontWeight.w800),
        );
        final statusDot = Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );

        return Row(
          children: [
            SizedBox(width: compact ? 82 : 88, child: labelText),
            SizedBox(width: compact ? 6 : 8),
            statusDot,
            SizedBox(width: compact ? 6 : 8),
            Expanded(child: valueText),
          ],
        );
      },
    );
  }
}

class _CleanupConfirmItemList extends StatelessWidget {
  const _CleanupConfirmItemList({required this.plan});

  final DeletePlan plan;

  @override
  Widget build(BuildContext context) {
    final shown = plan.items.take(4).toList(growable: false);
    return Container(
      key: const ValueKey('cleanup-confirm-items'),
      constraints: const BoxConstraints(maxHeight: 172),
      decoration: BoxDecoration(
        color: _ScanColors.input.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in shown.indexed)
            _CleanupConfirmItemRow(
              key: ValueKey(
                'cleanup-confirm-item-${entry.$2.intent.nodeId.value}',
              ),
              item: entry.$2,
              showDivider: entry.$1 < shown.length - 1,
            ),
          if (plan.items.length > shown.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+${plan.items.length - shown.length}',
                  style: _monoStyle(
                    context,
                  ).copyWith(color: _ScanColors.textSoft),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CleanupConfirmItemRow extends StatelessWidget {
  const _CleanupConfirmItemRow({
    super.key,
    required this.item,
    required this.showDivider,
  });

  final DeletePlanItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: _ScanColors.border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            _nodeKindIcon(item.intent.kind),
            size: 18,
            color: _ScanColors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.intent.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatSize(item.intent.measuredSize),
            style: _monoStyle(context).copyWith(color: _ScanColors.pink),
          ),
        ],
      ),
    );
  }
}

class _DeleteQueuePreview extends StatelessWidget {
  const _DeleteQueuePreview({
    required this.store,
    required this.onRefreshPreview,
    required this.onExecuteCleanup,
    required this.onStoreChanged,
  });

  final ScanWorkspaceStore store;
  final VoidCallback onRefreshPreview;
  final VoidCallback onExecuteCleanup;
  final VoidCallback onStoreChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final queued = store.queuedItems;
    final plan = store.deletePlan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: _ScanColors.border),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              Icons.playlist_add_check_outlined,
              color: _ScanColors.cyan,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.deleteQueueTitle,
                style: _bodyStyle(context).copyWith(color: Colors.white),
              ),
            ),
            if (queued.isNotEmpty)
              Text(
                _formatBytes(plan.knownReclaimBytes),
                style: _monoStyle(context).copyWith(color: _ScanColors.cyan),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (queued.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deleteQueueEmpty,
                style: _bodyStyle(
                  context,
                ).copyWith(color: _ScanColors.textSoft),
              ),
              if (store.cleanupReceipt case final receipt?) ...[
                const SizedBox(height: 8),
                _CleanupReceiptSummary(receipt: receipt),
              ],
            ],
          )
        else ...[
          for (final item in plan.items.take(3))
            _DeleteQueueItem(
              item: item,
              onRemove: () {
                store.removeQueuedNode(item.intent.nodeId);
                onStoreChanged();
              },
            ),
          if (queued.length > 3)
            Text(
              l10n.deleteQueueMoreCount(count: queued.length - 3),
              style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
            ),
          const SizedBox(height: 8),
          Text(
            plan.hasBlockingStates
                ? l10n.cleanupPreviewBlocked
                : l10n.cleanupPreviewReady,
            style: _bodyStyle(context).copyWith(
              color: plan.hasBlockingStates
                  ? _ScanColors.yellow
                  : _ScanColors.cyan,
            ),
          ),
          if (store.cleanupReceipt case final receipt?) ...[
            const SizedBox(height: 8),
            _CleanupReceiptSummary(receipt: receipt),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              key: const ValueKey('cleanup-preview-refresh-action'),
              onPressed: onRefreshPreview,
              icon: const Icon(Icons.verified_user_outlined, size: 16),
              label: Text(l10n.cleanupPreviewRefreshAction),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              key: const ValueKey('cleanup-preview-trash-action'),
              onPressed: plan.canAuthorizeCleanup ? onExecuteCleanup : null,
              icon: const Icon(Icons.delete_outline, size: 17),
              label: Text(l10n.cleanupPreviewTrashAction),
              style: FilledButton.styleFrom(
                backgroundColor: _ScanColors.pink,
                disabledBackgroundColor: _ScanColors.input,
                foregroundColor: Colors.white,
                disabledForegroundColor: _ScanColors.textSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _CleanupTrashNotice(),
        ],
      ],
    );
  }
}

class _CleanupTrashNotice extends StatelessWidget {
  const _CleanupTrashNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return Container(
      key: const ValueKey('cleanup-preview-trash-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _ScanColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: _ScanColors.textSoft, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cleanupPreviewTrashNoticeTitle,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.cleanupPreviewTrashNoticeText,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: _ScanColors.textSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteQueueItem extends StatelessWidget {
  const _DeleteQueueItem({required this.item, required this.onRemove});

  final DeletePlanItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final stateColor = item.isBlocked ? _ScanColors.yellow : _ScanColors.cyan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Icon(
                  _nodeKindIcon(item.intent.kind),
                  size: 20,
                  color: _ScanColors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.intent.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(context).copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSize(item.intent.measuredSize),
                  style: _monoStyle(context).copyWith(color: _ScanColors.pink),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: IconButton(
                    tooltip: l10n.deleteQueueRemoveAction,
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 16),
                    color: _ScanColors.textSoft,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _StatePill(
                label: item.isBlocked
                    ? l10n.cleanupPreviewBlockedShort
                    : l10n.cleanupPreviewReadyShort,
                color: stateColor,
              ),
              _StatePill(
                label: _reclaimConfidenceText(
                  l10n,
                  item.reclaimEstimate.confidence,
                ),
                color: _ScanColors.textSoft,
              ),
              for (final state in item.states.take(2))
                _StatePill(
                  label: _deletePlanStateText(l10n, state),
                  color: _ScanColors.yellow,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CleanupReceiptSummary extends StatelessWidget {
  const _CleanupReceiptSummary({required this.receipt});

  final CleanupReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final review = receipt.hasReviewItems;
    final color = review ? _ScanColors.yellow : _ScanColors.cyan;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review ? l10n.cleanupReceiptNeedsReview : l10n.cleanupReceiptReady,
            style: _bodyStyle(context).copyWith(color: color),
          ),
          const SizedBox(height: 6),
          for (final item in receipt.items.take(3))
            Text(
              '${item.displayName}: ${_cleanupReceiptItemStateText(l10n, item.state)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _monoStyle(context).copyWith(color: _ScanColors.textSoft),
            ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.label,
    required this.color,
    this.maxWidth = 150,
  });

  final String label;
  final Color color;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: _monoStyle(context).copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

class _ToolbarSearchField extends StatelessWidget {
  const _ToolbarSearchField({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: IgnorePointer(
        ignoring: !enabled,
        child: AppTextField(
          key: const ValueKey('scan-search-field'),
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          height: 36,
          textInputAction: TextInputAction.search,
          prefixIcon: Icons.search,
          prefixIconSize: 18,
          prefixIconColor: _ScanColors.textSoft,
          placeholderColor: _ScanColors.textSoft,
          textStyle: _bodyStyle(context).copyWith(color: _ScanColors.text),
          containerPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}

class _SortMenuButton extends StatelessWidget {
  const _SortMenuButton({
    required this.iconOnly,
    required this.currentSort,
    required this.tooltip,
    required this.selected,
    required this.onSort,
    this.text,
  });

  final bool iconOnly;
  final ChildSort currentSort;
  final String tooltip;
  final bool selected;
  final ValueChanged<ChildSort> onSort;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return PopupMenuButton<ChildSort>(
      key: const ValueKey('scan-toolbar-sort-action'),
      tooltip: tooltip,
      color: _ScanColors.innerPanel,
      elevation: 12,
      position: PopupMenuPosition.under,
      onSelected: onSort,
      itemBuilder: (context) => [
        _sortMenuItem(context, l10n, ChildSort.sizeDesc),
        _sortMenuItem(context, l10n, ChildSort.sizeAsc),
        _sortMenuItem(context, l10n, ChildSort.nameAsc),
        _sortMenuItem(context, l10n, ChildSort.nameDesc),
      ],
      child: iconOnly
          ? _SortIconSurface(selected: selected)
          : _SortTextSurface(
              text: text ?? _sortButtonLabelForMenu(currentSort, l10n),
              selected: selected,
            ),
    );
  }

  PopupMenuItem<ChildSort> _sortMenuItem(
    BuildContext context,
    CleanDiskLocalizations l10n,
    ChildSort sort,
  ) {
    final active = currentSort == sort;
    return PopupMenuItem<ChildSort>(
      key: ValueKey('scan-sort-option-${sort.name}'),
      value: sort,
      child: Row(
        children: [
          Icon(
            active ? Icons.check : Icons.sort,
            color: active ? _ScanColors.cyan : _ScanColors.textSoft,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _sortMenuLabel(sort, l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(
                color: active ? Colors.white : _ScanColors.text,
                fontWeight: active ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortIconSurface extends StatelessWidget {
  const _SortIconSurface({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _ScanColors.selectedRow : _ScanColors.input,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? _ScanColors.cyan : _ScanColors.border,
        ),
      ),
      child: Icon(
        Icons.tune,
        size: 20,
        color: selected ? _ScanColors.cyan : _ScanColors.textSoft,
      ),
    );
  }
}

class _SortTextSurface extends StatelessWidget {
  const _SortTextSurface({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 148),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? _ScanColors.selectedRow : _ScanColors.input,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? _ScanColors.cyan : _ScanColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tune,
            size: 18,
            color: selected ? _ScanColors.cyan : _ScanColors.textSoft,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(
                color: selected ? _ScanColors.text : _ScanColors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(
            Icons.play_arrow,
            size: 18,
            color: _ScanColors.onPrimary,
          ),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(context).copyWith(
              color: _ScanColors.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _ScanColors.cyan,
            foregroundColor: _ScanColors.onPrimary,
            disabledBackgroundColor: _ScanColors.input,
            disabledForegroundColor: _ScanColors.textSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        color: !enabled
            ? _ScanColors.textSoft.withValues(alpha: 0.56)
            : primary
            ? _ScanColors.onPrimary
            : Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: primary && enabled
              ? _ScanColors.cyan
              : _ScanColors.input,
          disabledBackgroundColor: _ScanColors.input.withValues(alpha: 0.72),
          side: BorderSide(
            color: !enabled
                ? _ScanColors.border.withValues(alpha: 0.72)
                : primary
                ? _ScanColors.cyan
                : _ScanColors.border,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _PaneToggleAction extends StatelessWidget {
  const _PaneToggleAction({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _ScanColors.input,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _ScanColors.border),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    super.key,
    required this.icon,
    required this.label,
    this.accent = _ScanColors.text,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color foreground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return _ScanColors.textSoft.withAlpha(120);
      }
      return accent;
    }

    Color? overlay(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      if (states.contains(WidgetState.pressed)) {
        return accent.withAlpha(30);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return accent.withAlpha(18);
      }
      return null;
    }

    BorderSide side(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: _ScanColors.border.withAlpha(150));
      }
      return BorderSide(color: accent.withAlpha(180));
    }

    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(foreground),
          overlayColor: WidgetStateProperty.resolveWith(overlay),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10),
          ),
          textStyle: WidgetStatePropertyAll(
            _bodyStyle(context).copyWith(fontSize: 13),
          ),
          side: WidgetStateProperty.resolveWith(side),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _ScanColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 136,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: value,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: _monoStyle(context).copyWith(color: _ScanColors.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : 132,
      height: compact ? 30 : null,
      padding: EdgeInsets.only(left: compact ? 8 : 18),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _ScanColors.border)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(context).copyWith(
              color: _ScanColors.textSoft,
              fontSize: compact ? 11 : 12,
              height: 1.05,
            ),
          ),
          SizedBox(height: compact ? 1 : 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _monoStyle(context).copyWith(
              color: Colors.white,
              fontSize: compact ? 12 : 14,
              height: 1.08,
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowChromeInset extends StatelessWidget {
  const _WindowChromeInset({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final needsNativeTrafficLightInset =
        Theme.of(context).platform == TargetPlatform.macOS;
    if (!needsNativeTrafficLightInset) {
      return const SizedBox.shrink();
    }

    return SizedBox(width: compact ? 78 : 82);
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          context.cleanDiskL10n.appTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatefulWidget {
  const _Breadcrumb({required this.target, this.onTap});

  final ScanTarget target;
  final VoidCallback? onTap;

  @override
  State<_Breadcrumb> createState() => _BreadcrumbState();
}

class _BreadcrumbState extends State<_Breadcrumb> {
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
    final isInteractive = widget.onTap != null;
    final content = Container(
      key: const ValueKey('scan-target-breadcrumb'),
      height: 36,
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _hovered && isInteractive
            ? _ScanColors.selectedSoft.withValues(alpha: 0.56)
            : _ScanColors.input,
        border: Border.all(
          color: _hovered && isInteractive
              ? _ScanColors.cyan.withValues(alpha: 0.72)
              : _ScanColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Tooltip(
        message: widget.target.path.value,
        child: Row(
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 17,
              color: _ScanColors.cyan,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.target.path.value,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(context).copyWith(color: _ScanColors.text),
              ),
            ),
          ],
        ),
      ),
    );
    if (!isInteractive) {
      return content;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: const ValueKey('scan-target-breadcrumb-action'),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          focusColor: _ScanColors.cyan.withValues(alpha: 0.10),
          highlightColor: _ScanColors.cyan.withValues(alpha: 0.08),
          hoverColor: Colors.transparent,
          splashColor: _ScanColors.cyan.withValues(alpha: 0.12),
          child: content,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _ScanColors.innerPanel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Center(
        child: Text(
          text,
          style: _bodyStyle(context).copyWith(color: _ScanColors.cyan),
        ),
      ),
    );
  }
}

class _SectionCaption extends StatelessWidget {
  const _SectionCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: _ScanColors.textSoft,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider.vertical() : vertical = true;
  const _Divider.horizontal() : vertical = false;

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return vertical
        ? const VerticalDivider(width: 1, color: _ScanColors.border)
        : const Divider(height: 1, color: _ScanColors.border);
  }
}

abstract final class _ScanColors {
  static const background = Color(0xFF050914);
  static const topBar = Color(0xFF070B17);
  static const footer = Color(0xFF060B16);
  static const panel = Color(0xFF0A1020);
  static const innerPanel = Color(0xFF0D1428);
  static const panelHeader = Color(0xFF10172B);
  static const input = Color(0xFF0B1224);
  static const border = Color(0xFF263148);
  static const selectedRow = Color(0xFF14265E);
  static const selectedSoft = Color(0xFF0D2142);
  static const progressTrack = Color(0xFF20283D);
  static const text = Color(0xFFDCE6FF);
  static const textSoft = Color(0xFF93A0BF);
  static const onPrimary = Color(0xFF011216);
  static const blue = Color(0xFF3B82F6);
  static const cyan = Color(0xFF22E7F2);
  static const violet = Color(0xFF8B5CF6);
  static const pink = Color(0xFFFF5C8A);
  static const yellow = Color(0xFFFFCA3A);
}

final _panelDecoration = BoxDecoration(
  color: _ScanColors.panel,
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: _ScanColors.border),
);

TextStyle _bodyStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: _ScanColors.text,
        letterSpacing: 0,
      ) ??
      const TextStyle(color: _ScanColors.text, letterSpacing: 0);
}

TextStyle _titleStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ) ??
      const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      );
}

TextStyle _monoStyle(BuildContext context) {
  return _bodyStyle(context).copyWith(
    color: _ScanColors.textSoft,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

bool _shouldShowDiskUsageMap(
  ScanWorkspaceStore store,
  DiskUsageMapRenderer? renderer,
) {
  return renderer != null &&
      _availableDiskUsageMapRows(
        store,
      ).any((row) => _diskUsageMapSize(row) > BigInt.zero);
}

bool _shouldShowMetricStrip(ScanWorkspaceStore store) {
  return store.progress != null || _metricSummary(store).hasData;
}

final class _MetricSummary {
  const _MetricSummary({required this.totalSize, required this.largest});

  final BigInt? totalSize;
  final NodePageItem? largest;

  bool get hasData => totalSize != null || largest != null;
}

_MetricSummary _metricSummary(ScanWorkspaceStore store) {
  final focusedNode = store.diskUsageMapFocusNode;
  final rootNode = focusedNode ?? store.diskUsageMapRootNode;
  final diskRows = store.diskUsageMapRows;
  if (diskRows.isNotEmpty || rootNode != null) {
    final positiveRows = _positiveSizeRows(diskRows);
    final rootSize = rootNode == null ? null : _diskUsageMapSize(rootNode);
    return _MetricSummary(
      totalSize: rootSize != null && rootSize > BigInt.zero
          ? rootSize
          : _coveredRowsSizeOrNull(positiveRows),
      largest: _largestSummaryRow(
        positiveRows,
        excludedNodeId: rootNode?.nodeId,
      ),
    );
  }

  final rows = _positiveSizeRows(_summaryRows(store));
  return _MetricSummary(
    totalSize: _coveredRowsSizeOrNull(rows),
    largest: _largestSummaryRow(rows),
  );
}

String? _metricSummarySizeText(ScanWorkspaceStore store) {
  final totalSize = _metricSummary(store).totalSize;
  return totalSize == null ? null : _formatBytes(totalSize);
}

List<NodePageItem> _positiveSizeRows(List<NodePageItem> rows) {
  return [
    for (final row in rows)
      if (_diskUsageMapSize(row) > BigInt.zero) row,
  ];
}

BigInt? _coveredRowsSizeOrNull(List<NodePageItem> rows) {
  if (rows.isEmpty) {
    return null;
  }
  final sortedRows = [...rows]
    ..sort((left, right) {
      return _diskUsageMapSize(right).compareTo(_diskUsageMapSize(left));
    });
  return _diskUsageMapCoveredSize(
    sortedRows,
    rowById: <NodeId, NodePageItem>{
      for (final row in sortedRows) row.nodeId: row,
    },
  );
}

NodePageItem? _largestSummaryRow(
  List<NodePageItem> rows, {
  NodeId? excludedNodeId,
}) {
  final candidates = [
    for (final row in rows)
      if (row.nodeId != excludedNodeId && _diskUsageMapSize(row) > BigInt.zero)
        row,
  ];
  if (candidates.isEmpty) {
    return null;
  }

  final directories = [
    for (final row in candidates)
      if (row.kind == NodeKind.directory) row,
  ];
  final pool = directories.isEmpty ? candidates : directories;
  pool.sort((left, right) {
    return _diskUsageMapSize(right).compareTo(_diskUsageMapSize(left));
  });
  return pool.first;
}

const _diskUsageMapMaxTiles = 18;

final _diskUsageMapStyle = DiskUsageMapStyle(
  backgroundColor: _ScanColors.innerPanel,
  borderColor: _ScanColors.border,
  textColor: _ScanColors.text,
  mutedTextColor: _ScanColors.textSoft,
  tileBorderColor: const Color(0x99263148),
  selectedTileBorderColor: _ScanColors.cyan,
  focusedTileBorderColor: _ScanColors.blue,
  warningColor: _ScanColors.yellow,
  protectedColor: const Color(0xFF64748B),
  otherColor: const Color(0xFF20283D),
  palette: const <Color>[
    _ScanColors.blue,
    _ScanColors.violet,
    _ScanColors.cyan,
    Color(0xFF14B8A6),
    Color(0xFF60A5FA),
    Color(0xFFA78BFA),
  ],
);

DiskUsageMapViewLabels _diskUsageMapLabels(CleanDiskLocalizations l10n) {
  return DiskUsageMapViewLabels(
    title: l10n.diskUsageMapTitle,
    description: l10n.diskUsageMapDescription,
    emptyTitle: l10n.diskUsageMapEmptyTitle,
    emptyMessage: l10n.diskUsageMapEmptyMessage,
    dataFallbackTitle: l10n.diskUsageMapDataFallbackTitle,
    unsupportedRendererMessage: l10n.diskUsageMapUnsupportedRendererMessage,
    renderFailureMessage: l10n.diskUsageMapRenderFailureMessage,
    otherLabel: l10n.diskUsageMapOtherLabel,
    stalePrefix: l10n.diskUsageMapStalePrefix,
    warningPrefix: l10n.diskUsageMapWarningPrefix,
  );
}

String _diskUsageMapSummaryText(
  CleanDiskLocalizations l10n,
  DiskUsageMapProjection projection,
  NodePageItem? focusedNode,
) {
  final totalSize = BigInt.tryParse(projection.totalSizeBytesDecimal);
  final sizeText = totalSize == null
      ? projection.totalSizeBytesDecimal
      : _formatBytes(totalSize);
  final itemText = l10n.detailsItemsCount(count: projection.visualTiles.length);
  if (focusedNode == null) {
    return '$sizeText - $itemText';
  }
  return '${focusedNode.name} - $sizeText - $itemText';
}

DiskUsageMapProjection? _diskUsageMapProjection({
  required CleanDiskLocalizations l10n,
  required ScanWorkspaceStore store,
  required ScanTarget activeTarget,
}) {
  final mapRows = _availableDiskUsageMapRows(store);
  final positiveRows = [
    for (final row in mapRows)
      if (_diskUsageMapSize(row) > BigInt.zero) row,
  ];
  if (positiveRows.isEmpty) {
    return null;
  }

  final focusedNode = store.diskUsageMapFocusNode;
  final rootNode = focusedNode ?? store.diskUsageMapRootNode;
  final rootNodeId =
      rootNode?.nodeId.value ??
      store.viewport.parentId?.value ??
      store.primaryRootNodeId?.value ??
      positiveRows.first.parentId?.value ??
      positiveRows.first.nodeId.value;
  final rowById = <NodeId, NodePageItem>{
    for (final row in positiveRows) row.nodeId: row,
  };
  final sortedRows = [...positiveRows]
    ..sort((left, right) {
      return _diskUsageMapSize(right).compareTo(_diskUsageMapSize(left));
    });
  final fallbackTotalSize = _diskUsageMapCoveredSize(
    sortedRows,
    rowById: rowById,
  );
  final rootSize = rootNode == null ? BigInt.zero : _diskUsageMapSize(rootNode);
  final totalSize = rootSize > BigInt.zero ? rootSize : fallbackTotalSize;
  final visualRows = sortedRows.take(_diskUsageMapMaxTiles).toList();
  final coveredSize = _diskUsageMapCoveredSize(visualRows, rowById: rowById);
  final uncoveredSize = totalSize - coveredSize;
  final otherSize = uncoveredSize > BigInt.zero ? uncoveredSize : BigInt.zero;
  final snapshotId = store.activeSnapshotId?.value ?? 'unknown';

  return DiskUsageMapProjection(
    scanSnapshotId: snapshotId,
    rootNodeId: rootNodeId,
    projectionId:
        '$snapshotId:$rootNodeId:${store.viewport.mode.name}:'
        '${store.diskUsageMapFocusNodeId?.value ?? 'all'}:'
        '${store.viewport.isStale ? 'stale' : 'current'}:'
        '${positiveRows.length}',
    kind: DiskUsageMapKind.treemap,
    sizeBasis: _diskUsageMapSizeBasis(positiveRows.first.size),
    totalSizeBytesDecimal: totalSize.toString(),
    freshness: store.viewport.isStale
        ? DiskUsageMapFreshness.stale
        : DiskUsageMapFreshness.current,
    tiles: [
      for (final row in visualRows)
        _diskUsageMapTile(
          row,
          totalSize: totalSize,
          depth: _diskUsageMapDepth(
            row,
            rootNodeId: rootNodeId,
            rowById: rowById,
          ),
          store: store,
          activeTarget: activeTarget,
        ),
    ],
    otherTile: otherSize > BigInt.zero
        ? DiskUsageMapTile(
            nodeId: '__other__',
            label: l10n.diskUsageMapOtherLabel,
            sizeBytesDecimal: otherSize.toString(),
            percentOfRootBasisPoints: _basisPoints(otherSize, totalSize),
            colorKey: 'other',
            depth: 0,
            kind: DiskUsageMapTileKind.other,
            issueCount: 0,
            childCount: 0,
            hasMoreChildren: false,
            disabled: true,
          )
        : null,
  );
}

List<NodePageItem> _availableDiskUsageMapRows(ScanWorkspaceStore store) {
  final diskRows = store.diskUsageMapRows;
  if (diskRows.isNotEmpty) {
    return diskRows;
  }
  return store.visibleRows;
}

DiskUsageMapTile _diskUsageMapTile(
  NodePageItem row, {
  required BigInt totalSize,
  required int depth,
  required ScanWorkspaceStore store,
  required ScanTarget activeTarget,
}) {
  final size = _diskUsageMapSize(row);
  final issueCount = row.issueCount + row.subtreeIssueCount;
  return DiskUsageMapTile(
    nodeId: row.nodeId.value,
    parentNodeId: row.parentId?.value,
    label: row.name,
    displayPathHint: _displayPathForSelection(
      store: store,
      target: activeTarget,
      selected: row,
    ),
    sizeBytesDecimal: size.toString(),
    percentOfRootBasisPoints: _basisPoints(size, totalSize),
    colorKey: _diskUsageMapColorKey(row),
    depth: depth,
    kind: _diskUsageMapTileKind(row, issueCount),
    riskHint: _diskUsageMapRiskHint(row, issueCount),
    issueCount: issueCount,
    childCount: row.childCount,
    hasMoreChildren: row.childCompleteness != ChildCompleteness.complete,
  );
}

BigInt _diskUsageMapCoveredSize(
  List<NodePageItem> rows, {
  required Map<NodeId, NodePageItem> rowById,
}) {
  var total = BigInt.zero;
  final covered = <NodeId>{};
  for (final row in rows) {
    if (_hasDiskUsageMapCoveredAncestor(row, covered, rowById)) {
      continue;
    }
    covered.add(row.nodeId);
    total += _diskUsageMapSize(row);
  }
  return total;
}

bool _hasDiskUsageMapCoveredAncestor(
  NodePageItem row,
  Set<NodeId> covered,
  Map<NodeId, NodePageItem> rowById,
) {
  var parentId = row.parentId;
  final visited = <NodeId>{row.nodeId};
  while (parentId != null && visited.add(parentId)) {
    if (covered.contains(parentId)) {
      return true;
    }
    parentId = rowById[parentId]?.parentId;
  }
  return false;
}

int _diskUsageMapDepth(
  NodePageItem row, {
  required String rootNodeId,
  required Map<NodeId, NodePageItem> rowById,
}) {
  var depth = 0;
  var parentId = row.parentId;
  final visited = <NodeId>{row.nodeId};
  while (parentId != null &&
      parentId.value != rootNodeId &&
      visited.add(parentId)) {
    final parent = rowById[parentId];
    if (parent == null) {
      break;
    }
    depth += 1;
    parentId = parent.parentId;
  }
  return depth;
}

BigInt _diskUsageMapSize(NodePageItem row) {
  return row.size.byteEquivalentBigInt ?? row.size.rawBigInt;
}

DiskUsageMapSizeBasis _diskUsageMapSizeBasis(SizeFact size) {
  return switch (size.quantity) {
    MeasuredQuantity.allocatedBytes => DiskUsageMapSizeBasis.allocatedBytes,
    MeasuredQuantity.apparentBytes => DiskUsageMapSizeBasis.logicalBytes,
    MeasuredQuantity.blockCount ||
    MeasuredQuantity.unknown => DiskUsageMapSizeBasis.logicalBytes,
  };
}

DiskUsageMapTileKind _diskUsageMapTileKind(NodePageItem row, int issueCount) {
  if (issueCount > 0) {
    return DiskUsageMapTileKind.warning;
  }
  if (row.flags.system) {
    return DiskUsageMapTileKind.protected;
  }
  if (row.flags.hidden) {
    return DiskUsageMapTileKind.hidden;
  }
  return DiskUsageMapTileKind.node;
}

DiskUsageMapRiskHint _diskUsageMapRiskHint(NodePageItem row, int issueCount) {
  if (issueCount > 0) {
    return DiskUsageMapRiskHint.high;
  }
  if (row.flags.system || row.flags.hidden) {
    return DiskUsageMapRiskHint.medium;
  }
  return DiskUsageMapRiskHint.none;
}

String _diskUsageMapColorKey(NodePageItem row) {
  return '${row.kind.name}:${row.flags.package ? 'package' : 'node'}';
}

int _basisPoints(BigInt size, BigInt totalSize) {
  if (size <= BigInt.zero || totalSize <= BigInt.zero) {
    return 0;
  }
  final value = (size * BigInt.from(10000)) ~/ totalSize;
  if (value > BigInt.from(10000)) {
    return 10000;
  }
  return value.toInt();
}

bool _isSelectableDiskUsageMapTile(DiskUsageMapTile tile) {
  return !tile.disabled &&
      tile.kind != DiskUsageMapTileKind.other &&
      RegExp(r'^\d+$').hasMatch(tile.nodeId);
}

List<NodePageItem> _summaryRows(ScanWorkspaceStore store) {
  if (store.viewport.mode != ScanQueryMode.children) {
    return store.visibleRows;
  }
  return [
    for (final row in store.visibleTreeRows)
      if (row.depth == 0) row.item,
  ];
}

String _formatSize(SizeFact size) {
  return _formatBytes(size.byteEquivalentBigInt ?? size.rawBigInt);
}

String _progressItemsText(
  CleanDiskLocalizations l10n,
  ScanProgress? progress, {
  required bool isRunning,
}) {
  final scannedItems = progress?.scannedItems;
  if (scannedItems == null) {
    return isRunning ? l10n.metricScanningValue : l10n.metricNoDataValue;
  }
  return scannedItems.toString();
}

String _progressElapsedText(
  CleanDiskLocalizations l10n,
  ScanProgress? progress, {
  required bool isRunning,
}) {
  final elapsedMs = progress?.elapsedMs;
  if (elapsedMs == null) {
    return isRunning ? l10n.metricScanningValue : l10n.metricNoDataValue;
  }
  return _formatElapsed(elapsedMs);
}

String _progressThroughputText(
  CleanDiskLocalizations l10n,
  ScanProgress? progress, {
  required bool isRunning,
}) {
  if (progress == null) {
    return isRunning ? l10n.metricScanningValue : l10n.metricNoDataValue;
  }
  final bytesPerSecond = progress.throughputBytesPerSec;
  if (bytesPerSecond != null) {
    return '${_formatBytes(bytesPerSecond)} /s';
  }

  final elapsedMs = progress.elapsedMs;
  if (elapsedMs == null || elapsedMs <= BigInt.zero) {
    return isRunning ? l10n.metricScanningValue : l10n.metricNoDataValue;
  }

  final itemsPerSecond =
      progress.scannedItems.toDouble() / (elapsedMs.toDouble() / 1000);
  if (!itemsPerSecond.isFinite || itemsPerSecond <= 0) {
    return isRunning ? l10n.metricScanningValue : l10n.metricNoDataValue;
  }

  return '${_formatRate(itemsPerSecond)} ${l10n.progressItemsPerSecondSuffix}';
}

String _targetDisplayName(ScanTarget target) {
  final parts = target.path.value
      .split(RegExp(r'[/\\]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return target.path.value;
  }
  return parts.last;
}

String _targetChoiceLabel(
  CleanDiskLocalizations l10n,
  ScanTargetChoice choice,
) {
  return switch (choice.kind) {
    ScanTargetChoiceKind.home => l10n.targetHome,
    ScanTargetChoiceKind.downloads => l10n.targetDownloads,
    ScanTargetChoiceKind.library => l10n.targetLibrary,
    ScanTargetChoiceKind.applications => l10n.targetApplications,
    ScanTargetChoiceKind.root => l10n.targetRoot,
    ScanTargetChoiceKind.volume =>
      choice.displayName.isEmpty ? l10n.targetVolume : choice.displayName,
  };
}

List<ScanTargetChoice> _railTargetChoices(
  List<ScanTargetChoice> choices,
  ScanTarget activeTarget,
) {
  return choices
      .where((choice) => choice.target.path.value != activeTarget.path.value)
      .take(6)
      .toList(growable: false);
}

IconData _targetChoiceIcon(ScanTargetChoiceKind kind) {
  return switch (kind) {
    ScanTargetChoiceKind.home => Icons.home_outlined,
    ScanTargetChoiceKind.downloads => Icons.download_outlined,
    ScanTargetChoiceKind.library => Icons.folder_special_outlined,
    ScanTargetChoiceKind.applications => Icons.apps_outlined,
    ScanTargetChoiceKind.root => Icons.storage_outlined,
    ScanTargetChoiceKind.volume => Icons.dns_outlined,
  };
}

String _displayPathForSelection({
  required ScanWorkspaceStore store,
  required ScanTarget target,
  required NodePageItem selected,
}) {
  final parts = _visibleTreePathParts(store, selected.nodeId);
  if (parts.isEmpty) {
    return _joinDisplayPath(target.path.value, ['...', selected.name]);
  }
  return _joinDisplayPath(
    target.path.value,
    _pathPartsRelativeToTarget(target.path.value, parts),
  );
}

List<String> _visibleTreePathParts(ScanWorkspaceStore store, NodeId nodeId) {
  final rowsById = <NodeId, ScanTreeNodeRow>{
    for (final row in store.visibleTreeRows) row.item.nodeId: row,
  };
  final selectedRow = rowsById[nodeId];
  if (selectedRow == null) {
    return const [];
  }

  final parts = <String>[];
  var current = selectedRow.item;
  final treeRootParentId = store.viewport.parentId;
  while (true) {
    parts.add(current.name);
    final parentId = current.parentId;
    if (parentId == null || parentId == treeRootParentId) {
      break;
    }
    final parent = rowsById[parentId];
    if (parent == null) {
      break;
    }
    current = parent.item;
  }
  return parts.reversed.toList(growable: false);
}

List<String> _pathPartsRelativeToTarget(String basePath, List<String> parts) {
  final baseParts = basePath
      .split(RegExp(r'[/\\]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (baseParts.isEmpty || parts.isEmpty) {
    return parts;
  }

  final maxOverlap = baseParts.length < parts.length
      ? baseParts.length
      : parts.length;
  for (var length = maxOverlap; length > 0; length -= 1) {
    final baseSuffix = baseParts.sublist(baseParts.length - length);
    final pathPrefix = parts.take(length).toList(growable: false);
    if (_samePathParts(baseSuffix, pathPrefix)) {
      return parts.skip(length).toList(growable: false);
    }
  }
  return parts;
}

bool _samePathParts(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _joinDisplayPath(String basePath, List<String> parts) {
  final normalizedBase = basePath == '/'
      ? '/'
      : basePath.replaceAll(RegExp(r'[/\\]+$'), '');
  final suffix = parts.where((part) => part.isNotEmpty).join('/');
  if (suffix.isEmpty) {
    return normalizedBase;
  }
  if (normalizedBase == '/') {
    return '/$suffix';
  }
  return '$normalizedBase/$suffix';
}

bool _isRevealableDisplayPath(String path) {
  if (path.trim().isEmpty) {
    return false;
  }
  return !path
      .split(RegExp(r'[/\\]+'))
      .where((part) {
        return part.isNotEmpty;
      })
      .any((part) => part.contains('...') || part.contains('…'));
}

String _nodeKindText(CleanDiskLocalizations l10n, NodeKind kind) {
  return switch (kind) {
    NodeKind.file => l10n.nodeTypeFile,
    NodeKind.directory => l10n.nodeTypeDirectory,
    NodeKind.symlink => l10n.nodeTypeSymlink,
    NodeKind.other => l10n.nodeTypeOther,
    NodeKind.unknown => l10n.nodeTypeUnknown,
  };
}

IconData _nodeKindIcon(NodeKind kind) {
  return switch (kind) {
    NodeKind.file => Icons.insert_drive_file_outlined,
    NodeKind.directory => Icons.folder_outlined,
    NodeKind.symlink => Icons.link_outlined,
    NodeKind.other => Icons.storage_outlined,
    NodeKind.unknown => Icons.help_outline,
  };
}

String _sizeQuantityText(
  CleanDiskLocalizations l10n,
  MeasuredQuantity quantity,
) {
  return switch (quantity) {
    MeasuredQuantity.apparentBytes => l10n.sizeQuantityApparent,
    MeasuredQuantity.allocatedBytes => l10n.sizeQuantityAllocated,
    MeasuredQuantity.blockCount => l10n.sizeQuantityBlocks,
    MeasuredQuantity.unknown => l10n.sizeQuantityUnknown,
  };
}

String _sizeConfidenceText(
  CleanDiskLocalizations l10n,
  SizeConfidence confidence,
) {
  return switch (confidence) {
    SizeConfidence.exact => l10n.sizeConfidenceExact,
    SizeConfidence.high => l10n.sizeConfidenceHigh,
    SizeConfidence.medium => l10n.sizeConfidenceMedium,
    SizeConfidence.low => l10n.sizeConfidenceLow,
    SizeConfidence.unknown => l10n.sizeConfidenceUnknown,
  };
}

String _nodeFlagsText(CleanDiskLocalizations l10n, NodeFlags flags) {
  final labels = [
    if (flags.hidden) l10n.nodeFlagHidden,
    if (flags.system) l10n.nodeFlagSystem,
    if (flags.package) l10n.nodeFlagPackage,
    if (flags.symlink) l10n.nodeFlagSymlink,
  ];
  if (labels.isEmpty) {
    return l10n.nodeFlagsNone;
  }
  return labels.join(', ');
}

String _formatBytes(BigInt value) {
  final bytes = value.toDouble();
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / (1000 * 1000 * 1000)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1000 * 1000) {
    return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1000) {
    return '${(bytes / 1000).toStringAsFixed(1)} KB';
  }
  return '$value B';
}

String _formatElapsed(BigInt elapsedMs) {
  final duration = Duration(milliseconds: elapsedMs.toInt());
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _formatRate(double value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  if (value >= 10) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _deletePlanStateText(
  CleanDiskLocalizations l10n,
  DeletePlanItemState state,
) {
  return switch (state) {
    DeletePlanItemState.staleSnapshot => l10n.cleanupStateStaleSnapshot,
    DeletePlanItemState.changedMetadata => l10n.cleanupStateChangedMetadata,
    DeletePlanItemState.missingPermission => l10n.cleanupStateMissingPermission,
    DeletePlanItemState.policyConflict => l10n.cleanupStatePolicyConflict,
    DeletePlanItemState.unknownReclaim => l10n.cleanupStateUnknownReclaim,
  };
}

String _reclaimConfidenceText(
  CleanDiskLocalizations l10n,
  ReclaimEstimateConfidence confidence,
) {
  return switch (confidence) {
    ReclaimEstimateConfidence.high => l10n.reclaimConfidenceHigh,
    ReclaimEstimateConfidence.medium => l10n.reclaimConfidenceMedium,
    ReclaimEstimateConfidence.low => l10n.reclaimConfidenceLow,
    ReclaimEstimateConfidence.unknown => l10n.reclaimConfidenceUnknown,
  };
}

String _cleanupReceiptItemStateText(
  CleanDiskLocalizations l10n,
  CleanupItemOutcomeState state,
) {
  return switch (state) {
    CleanupItemOutcomeState.movedToTrash => l10n.cleanupReceiptItemMoved,
    CleanupItemOutcomeState.blocked => l10n.cleanupReceiptItemBlocked,
    CleanupItemOutcomeState.failed => l10n.cleanupReceiptItemFailed,
    CleanupItemOutcomeState.unknownRequiresReview =>
      l10n.cleanupReceiptItemUnknown,
    CleanupItemOutcomeState.pending ||
    CleanupItemOutcomeState.dispatchRecorded ||
    CleanupItemOutcomeState.unknown => l10n.cleanupReceiptItemPending,
  };
}

List<AppTreeTableRow> _treeRows(
  List<ScanTreeNodeRow> rows, {
  required CleanDiskLocalizations l10n,
  required NodeId? selectedNodeId,
  required bool Function(NodeId nodeId) isQueued,
  required bool Function(NodeId nodeId) isMovedToTrash,
  required bool stale,
  required bool disabled,
  required bool allowExpansion,
}) {
  final maxSize = rows.fold<BigInt>(
    BigInt.zero,
    (current, row) =>
        row.item.size.rawBigInt > current ? row.item.size.rawBigInt : current,
  );

  return rows.map((row) {
    final item = row.item;
    final movedToTrash = isMovedToTrash(item.nodeId);
    final percent = maxSize == BigInt.zero
        ? 0.0
        : item.size.rawBigInt.toDouble() / maxSize.toDouble();
    return AppTreeTableRow(
      id: item.nodeId.value,
      name: item.name,
      sizeText: _formatSize(item.size),
      percentText: '${(percent * 100).clamp(0, 100).toStringAsFixed(1)}%',
      itemsText: '${item.childCount}',
      progress: percent,
      depth: row.depth,
      selected: item.nodeId == selectedNodeId,
      hasChildren: allowExpansion && item.childCount > 0,
      expanded: row.expanded,
      loading: row.loading,
      queued: isQueued(item.nodeId),
      danger: movedToTrash,
      dangerText: movedToTrash ? l10n.movedToTrashRowLabel : null,
      warning: item.issueCount > 0 || item.subtreeIssueCount > 0,
      stale: stale,
      disabled: disabled,
      icon: item.kind == NodeKind.file
          ? Icons.insert_drive_file_outlined
          : Icons.folder_outlined,
    );
  }).toList();
}

const _partialTreeRowIdPrefix = 'partial:';

String _partialTreeRowId(PartialNodeId nodeId) {
  return '$_partialTreeRowIdPrefix${nodeId.value}';
}

PartialNodeId? _partialNodeIdFromTreeRowId(String rowId) {
  if (!rowId.startsWith(_partialTreeRowIdPrefix)) {
    return null;
  }
  final value = rowId.substring(_partialTreeRowIdPrefix.length);
  if (value.isEmpty) {
    return null;
  }
  return PartialNodeId(value);
}

List<AppTreeTableRow> _partialTreeRows(List<PartialScanTreeNodeRow> rows) {
  final maxSize = rows.fold<BigInt>(
    BigInt.zero,
    (current, row) => row.item.aggregateSize.rawBigInt > current
        ? row.item.aggregateSize.rawBigInt
        : current,
  );

  return rows.map((row) {
    final item = row.item;
    final percent = maxSize == BigInt.zero
        ? 0.0
        : item.aggregateSize.rawBigInt.toDouble() / maxSize.toDouble();
    return AppTreeTableRow(
      id: _partialTreeRowId(item.nodeId),
      name: item.name,
      sizeText: _formatSize(item.aggregateSize),
      percentText: '${(percent * 100).clamp(0, 100).toStringAsFixed(1)}%',
      itemsText: '',
      progress: percent,
      depth: row.depth,
      selected: false,
      hasChildren: row.hasChildren,
      expanded: row.expanded,
      loading: row.loading,
      queued: false,
      warning: item.issueCount > 0,
      stale: false,
      disabled: false,
      icon: item.kind == NodeKind.file
          ? Icons.insert_drive_file_outlined
          : Icons.folder_outlined,
    );
  }).toList();
}

int _issueCount(List<NodePageItem> rows) {
  return rows.fold<int>(
    0,
    (sum, row) => sum + row.issueCount + row.subtreeIssueCount,
  );
}

_RowsStateContent? _tableState({
  required CleanDiskLocalizations l10n,
  required ScanWorkspaceStore store,
  required int issueCount,
}) {
  final failure = store.lastFailure;
  if (failure != null) {
    return _RowsStateContent(
      icon: Icons.error_outline,
      title: l10n.errorRowsTitle,
      message: failure.message,
      accent: _ScanColors.pink,
    );
  }
  if (store.pageLoadState == ScanPageLoadState.loading) {
    return _RowsStateContent(
      icon: Icons.sync,
      title: l10n.loadingRowsTitle,
      message: l10n.loadingRowsText,
      accent: _ScanColors.cyan,
    );
  }
  if (store.sessionStatus?.state == SessionState.running) {
    return _RowsStateContent(
      icon: Icons.sync,
      title: l10n.scanRunningStatus,
      message: l10n.noRowsText,
      accent: _ScanColors.cyan,
    );
  }
  if (store.viewport.isStale) {
    return _RowsStateContent(
      icon: Icons.history_toggle_off_outlined,
      title: l10n.staleRowsTitle,
      message: l10n.staleRowsText,
      accent: _ScanColors.violet,
    );
  }
  if (issueCount > 0) {
    return _RowsStateContent(
      icon: Icons.warning_amber_rounded,
      title: l10n.partialRowsTitle,
      message: l10n.partialRowsText,
      accent: _ScanColors.yellow,
    );
  }
  return null;
}

_RowsStateContent? _queryModeBanner(
  CleanDiskLocalizations l10n,
  ScanWorkspaceStore store,
) {
  return switch (store.viewport.mode) {
    ScanQueryMode.search => _RowsStateContent(
      icon: Icons.search,
      title: l10n.searchResultsTitle,
      message: l10n.searchResultsText(query: store.viewport.searchText),
      accent: _ScanColors.blue,
    ),
    ScanQueryMode.topItems => _RowsStateContent(
      icon: Icons.leaderboard_outlined,
      title: l10n.topItemsResultsTitle,
      message: l10n.topItemsResultsText,
      accent: _ScanColors.violet,
    ),
    ScanQueryMode.children => null,
  };
}

_RowsStateContent _emptyRowsState({
  required CleanDiskLocalizations l10n,
  required ScanWorkspaceStore store,
}) {
  final failure = store.lastFailure;
  if (failure != null) {
    return _RowsStateContent(
      icon: Icons.error_outline,
      title: l10n.errorRowsTitle,
      message: failure.message,
      accent: _ScanColors.pink,
    );
  }
  if (store.pageLoadState == ScanPageLoadState.loading) {
    return _RowsStateContent(
      icon: Icons.sync,
      title: l10n.loadingRowsTitle,
      message: l10n.loadingRowsText,
      accent: _ScanColors.cyan,
    );
  }
  if (store.sessionStatus?.state == SessionState.running) {
    return _RowsStateContent(
      icon: Icons.sync,
      title: l10n.scanRunningStatus,
      message: l10n.noRowsText,
      accent: _ScanColors.cyan,
    );
  }
  if (store.viewport.isStale) {
    return _RowsStateContent(
      icon: Icons.history_toggle_off_outlined,
      title: l10n.staleRowsTitle,
      message: l10n.staleRowsText,
      accent: _ScanColors.violet,
    );
  }
  return _RowsStateContent(
    icon: Icons.folder_open_outlined,
    title: l10n.noRowsTitle,
    message: l10n.noRowsText,
    accent: _ScanColors.blue,
  );
}

String _sortButtonLabelForMenu(ChildSort sort, CleanDiskLocalizations l10n) {
  return switch (sort) {
    ChildSort.sizeDesc => l10n.sortSizeDescLabel,
    ChildSort.sizeAsc => l10n.sortSizeAscLabel,
    ChildSort.nameAsc => l10n.sortNameAscLabel,
    ChildSort.nameDesc => l10n.sortNameDescLabel,
    ChildSort.insertion => l10n.sortFilterAction,
  };
}

String _sortMenuLabel(ChildSort sort, CleanDiskLocalizations l10n) {
  return switch (sort) {
    ChildSort.sizeDesc => l10n.sortLargestFirstLabel,
    ChildSort.sizeAsc => l10n.sortSmallestFirstLabel,
    ChildSort.nameAsc => l10n.sortNameAscLabel,
    ChildSort.nameDesc => l10n.sortNameDescLabel,
    ChildSort.insertion => l10n.sortFilterAction,
  };
}

IconData _issueIcon(IssueSeverity severity) {
  return switch (severity) {
    IssueSeverity.info => Icons.info_outline,
    IssueSeverity.warning => Icons.warning_amber_rounded,
    IssueSeverity.error => Icons.error_outline,
    IssueSeverity.unknown => Icons.help_outline,
  };
}

Color _issueColor(IssueSeverity severity) {
  return switch (severity) {
    IssueSeverity.info => _ScanColors.blue,
    IssueSeverity.warning => _ScanColors.yellow,
    IssueSeverity.error => _ScanColors.pink,
    IssueSeverity.unknown => _ScanColors.textSoft,
  };
}

String _identityProofText(
  CleanDiskLocalizations l10n,
  ScannerIdentityVerification verification,
) {
  return switch (verification) {
    ScannerIdentityVerification.verified => l10n.permissionIdentityVerified,
    ScannerIdentityVerification.unverified => l10n.permissionIdentityUnverified,
    ScannerIdentityVerification.unknown => l10n.permissionIdentityUnknown,
  };
}

Color _identityProofColor(ScannerIdentityVerification verification) {
  return switch (verification) {
    ScannerIdentityVerification.verified => _ScanColors.cyan,
    ScannerIdentityVerification.unverified => _ScanColors.yellow,
    ScannerIdentityVerification.unknown => _ScanColors.textSoft,
  };
}

String _permissionProbeText(
  CleanDiskLocalizations l10n,
  PermissionProbeStatus status,
) {
  return switch (status) {
    PermissionProbeStatus.verified => l10n.permissionProbeVerified,
    PermissionProbeStatus.denied => l10n.permissionProbeDenied,
    PermissionProbeStatus.notDetermined => l10n.permissionProbeNotDetermined,
    PermissionProbeStatus.notProbed => l10n.permissionProbePending,
    PermissionProbeStatus.degraded => l10n.permissionProbeDegraded,
    PermissionProbeStatus.unsupported => l10n.permissionProbeUnsupported,
    PermissionProbeStatus.unknown => l10n.permissionProbeUnknown,
  };
}

Color _permissionProbeColor(PermissionProbeStatus status) {
  return switch (status) {
    PermissionProbeStatus.verified => _ScanColors.cyan,
    PermissionProbeStatus.denied => _ScanColors.pink,
    PermissionProbeStatus.notDetermined => _ScanColors.yellow,
    PermissionProbeStatus.degraded => _ScanColors.violet,
    PermissionProbeStatus.notProbed ||
    PermissionProbeStatus.unsupported ||
    PermissionProbeStatus.unknown => _ScanColors.textSoft,
  };
}

String _scannerProcessText(
  CleanDiskLocalizations l10n,
  ScannerProcessKind processKind,
) {
  return switch (processKind) {
    ScannerProcessKind.appBundle => l10n.permissionScannerAppBundle,
    ScannerProcessKind.bundledHelper => l10n.permissionScannerBundledHelper,
    ScannerProcessKind.currentProcess => l10n.permissionScannerCurrentProcess,
    ScannerProcessKind.externalProcess => l10n.permissionScannerExternalProcess,
    ScannerProcessKind.unknown => l10n.permissionScannerUnknown,
  };
}

Color _scannerProcessColor(ScannerProcessKind processKind) {
  return switch (processKind) {
    ScannerProcessKind.appBundle ||
    ScannerProcessKind.bundledHelper => _ScanColors.cyan,
    ScannerProcessKind.currentProcess => _ScanColors.yellow,
    ScannerProcessKind.externalProcess => _ScanColors.pink,
    ScannerProcessKind.unknown => _ScanColors.textSoft,
  };
}

String _permissionActionText(CleanDiskLocalizations l10n, RuntimeProof proof) {
  final action = proof.permissionProbe.requiredAction;
  if (action != PermissionRequiredAction.none &&
      action != PermissionRequiredAction.unknown) {
    return switch (action) {
      PermissionRequiredAction.openMacosFullDiskAccess =>
        l10n.permissionActionMacosFullDiskAccess,
      PermissionRequiredAction.runAsAdministrator =>
        l10n.permissionActionWindowsAdministrator,
      PermissionRequiredAction.reviewLinuxPermissions =>
        l10n.permissionActionLinuxPermissions,
      PermissionRequiredAction.none => l10n.permissionActionNone,
      PermissionRequiredAction.unknown => l10n.permissionActionUnknown,
    };
  }
  if (_hasReducedCapabilityWarning(proof.packaging)) {
    return l10n.permissionActionReducedPackage;
  }
  if (action == PermissionRequiredAction.unknown) {
    return l10n.permissionActionUnknown;
  }
  return l10n.permissionActionNone;
}

Color _permissionActionColor(RuntimeProof proof) {
  final action = proof.permissionProbe.requiredAction;
  if (action != PermissionRequiredAction.none &&
      action != PermissionRequiredAction.unknown) {
    return _ScanColors.yellow;
  }
  if (_hasReducedCapabilityWarning(proof.packaging)) {
    return _ScanColors.yellow;
  }
  if (action == PermissionRequiredAction.unknown) {
    return _ScanColors.textSoft;
  }
  return _ScanColors.cyan;
}

bool _shouldShowDetailedPermissionProof(
  RuntimeProof proof, {
  required VoidCallback? onRepair,
}) {
  final probe = proof.permissionProbe.status;
  final action = proof.permissionProbe.requiredAction;
  final needsRepairGuidance =
      action != PermissionRequiredAction.none &&
      action != PermissionRequiredAction.unknown;
  final hasConfirmedAccessProblem =
      probe == PermissionProbeStatus.denied ||
      probe == PermissionProbeStatus.degraded ||
      probe == PermissionProbeStatus.unsupported;
  return onRepair != null || hasConfirmedAccessProblem || needsRepairGuidance;
}

bool _shouldUseCompactPermissionProof(
  RuntimeProof proof, {
  required _PermissionWarningData? warning,
  required bool showDetailedProof,
  required VoidCallback? onRepair,
}) {
  if (showDetailedProof || onRepair != null) {
    return false;
  }
  return proof.permissionProbe.status == PermissionProbeStatus.verified &&
      (warning == null || warning.compact);
}

_PermissionWarningData? _permissionWarningData(
  CleanDiskLocalizations l10n,
  RuntimeProof proof,
) {
  final probe = proof.permissionProbe.status;
  final identity = proof.scannerIdentity.verification;
  final hasAccessWarning = _hasActivePermissionWarning(probe);
  final identityRisk = identity == ScannerIdentityVerification.unverified;
  final packagingRisk = _hasReducedCapabilityWarning(proof.packaging);
  if (!hasAccessWarning &&
      probe != PermissionProbeStatus.verified &&
      !identityRisk &&
      !packagingRisk) {
    return null;
  }
  if (!hasAccessWarning &&
      probe == PermissionProbeStatus.verified &&
      !identityRisk &&
      !packagingRisk) {
    return null;
  }
  if (probe == PermissionProbeStatus.denied) {
    return _PermissionWarningData(
      title: l10n.permissionWarningTitle,
      message: l10n.permissionWarningDeniedText,
      icon: Icons.warning_amber_outlined,
      color: _ScanColors.yellow,
      compact: false,
    );
  }
  if (hasAccessWarning) {
    return _PermissionWarningData(
      title: l10n.permissionWarningTitle,
      message: l10n.permissionWarningUnverifiedText,
      icon: Icons.warning_amber_outlined,
      color: _ScanColors.yellow,
      compact: false,
    );
  }
  return _PermissionWarningData(
    title: l10n.permissionWarningDevTitle,
    message: l10n.permissionWarningDevIdentityText,
    icon: Icons.info_outline,
    color: _ScanColors.cyan,
    compact: true,
  );
}

bool _hasActivePermissionWarning(PermissionProbeStatus probe) {
  return switch (probe) {
    PermissionProbeStatus.denied ||
    PermissionProbeStatus.notDetermined ||
    PermissionProbeStatus.degraded ||
    PermissionProbeStatus.unsupported => true,
    PermissionProbeStatus.verified ||
    PermissionProbeStatus.notProbed ||
    PermissionProbeStatus.unknown => false,
  };
}

bool _isNeutralPermissionProof(
  RuntimeProof proof, {
  required _PermissionWarningData? warning,
  required VoidCallback? onRepair,
}) {
  final probe = proof.permissionProbe;
  final isPending =
      probe.status == PermissionProbeStatus.notProbed ||
      probe.status == PermissionProbeStatus.unknown;
  return isPending &&
      probe.checkedAtUnixMs == null &&
      warning == null &&
      onRepair == null;
}

bool _shouldShowPermissionCheckedLine(
  PermissionProbeStatus probe,
  BigInt? checkedAt,
) {
  if (checkedAt != null) {
    return true;
  }
  return switch (probe) {
    PermissionProbeStatus.notProbed || PermissionProbeStatus.unknown => false,
    PermissionProbeStatus.verified ||
    PermissionProbeStatus.denied ||
    PermissionProbeStatus.notDetermined ||
    PermissionProbeStatus.degraded ||
    PermissionProbeStatus.unsupported => true,
  };
}

final class _PermissionWarningData {
  const _PermissionWarningData({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.compact,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final bool compact;
}

List<String> _permissionRepairSteps(
  CleanDiskLocalizations l10n,
  RuntimeProof proof,
) {
  return switch (proof.permissionProbe.requiredAction) {
    PermissionRequiredAction.openMacosFullDiskAccess => [
      l10n.permissionRepairMacosStepOne,
      l10n.permissionRepairMacosStepTwo,
      l10n.permissionRepairMacosStepThree,
    ],
    PermissionRequiredAction.runAsAdministrator => [
      l10n.permissionRepairWindowsStepOne,
      l10n.permissionRepairWindowsStepTwo,
      l10n.permissionRepairWindowsStepThree,
    ],
    PermissionRequiredAction.reviewLinuxPermissions => [
      l10n.permissionRepairLinuxStepOne,
      l10n.permissionRepairLinuxStepTwo,
      l10n.permissionRepairLinuxStepThree,
    ],
    PermissionRequiredAction.none ||
    PermissionRequiredAction.unknown => [l10n.permissionRepairManualStep],
  };
}

bool _hasReducedCapabilityWarning(PackagingProof packaging) {
  final packageMode = packaging.packageMode;
  if (packageMode == PackageMode.unknown &&
      !packaging.debugBuild &&
      packaging.scannerProcess == ScannerProcessKind.unknown) {
    return false;
  }
  return packaging.debugBuild ||
      (!packaging.signedBuild && packageMode != PackageMode.unknown) ||
      packageMode == PackageMode.developmentShell ||
      packaging.scannerProcess == ScannerProcessKind.externalProcess;
}

String _packagingProofText(
  CleanDiskLocalizations l10n,
  PackagingProof packaging,
) {
  final mode = switch (packaging.packageMode) {
    PackageMode.developmentShell => l10n.permissionPackageDevelopment,
    PackageMode.appBundle => l10n.permissionPackageAppBundle,
    PackageMode.bundledDaemon => l10n.permissionPackageBundledDaemon,
    PackageMode.systemService => l10n.permissionPackageSystemService,
    PackageMode.portable => l10n.permissionPackagePortable,
    PackageMode.unknown => l10n.permissionPackageUnknown,
  };
  if (packaging.packageMode == PackageMode.unknown) {
    return mode;
  }
  final signature = packaging.signedBuild
      ? l10n.permissionSignedBuild
      : l10n.permissionUnsignedBuild;
  return '$mode / $signature';
}

Color _packagingProofColor(PackagingProof packaging) {
  if (packaging.packageMode == PackageMode.unknown) {
    return _ScanColors.textSoft;
  }
  if (packaging.signedBuild &&
      packaging.scannerProcess != ScannerProcessKind.externalProcess) {
    return _ScanColors.cyan;
  }
  return _ScanColors.yellow;
}

String _updateSafetyText(
  CleanDiskLocalizations l10n,
  UpdateSafety updateSafety,
) {
  if (updateSafety.quiesceRequiredBeforeUpdate) {
    return l10n.permissionUpdateQuiesceRequired;
  }
  if (updateSafety.rollbackSupported == SupportLevel.unknown ||
      updateSafety.receiptPreservation == SupportLevel.unknown) {
    return l10n.permissionUpdateUnknown;
  }
  return l10n.permissionUpdateNoQuiesce;
}

Color _updateSafetyColor(UpdateSafety updateSafety) {
  if (updateSafety.quiesceRequiredBeforeUpdate) {
    return _ScanColors.yellow;
  }
  if (updateSafety.rollbackSupported == SupportLevel.unknown ||
      updateSafety.receiptPreservation == SupportLevel.unknown) {
    return _ScanColors.textSoft;
  }
  return _ScanColors.cyan;
}

String _lastProbeText(CleanDiskLocalizations l10n, BigInt? checkedAtUnixMs) {
  if (checkedAtUnixMs == null) {
    return l10n.permissionCheckedNever;
  }
  final maxDateTimeMs = BigInt.from(8640000000000000);
  if (checkedAtUnixMs < BigInt.zero || checkedAtUnixMs > maxDateTimeMs) {
    return l10n.permissionCheckedUnknown;
  }
  final checkedAt = DateTime.fromMillisecondsSinceEpoch(
    checkedAtUnixMs.toInt(),
  ).toLocal();
  return [
    _twoDigits(checkedAt.hour),
    _twoDigits(checkedAt.minute),
    _twoDigits(checkedAt.second),
  ].join(':');
}

String _formatNodeTimestamp(CleanDiskLocalizations l10n, BigInt? unixMs) {
  if (unixMs == null) {
    return l10n.metricNoDataValue;
  }
  final maxDateTimeMs = BigInt.from(8640000000000000);
  if (unixMs < BigInt.zero || unixMs > maxDateTimeMs) {
    return l10n.metricNoDataValue;
  }
  final value = DateTime.fromMillisecondsSinceEpoch(unixMs.toInt()).toLocal();
  return [
    [
      value.year.toString().padLeft(4, '0'),
      _twoDigits(value.month),
      _twoDigits(value.day),
    ].join('-'),
    [_twoDigits(value.hour), _twoDigits(value.minute)].join(':'),
  ].join(' ');
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _issueText(ScanIssue issue) {
  final evidence = issue.evidence;
  final message = evidence.message;
  if (message != null && message.trim().isNotEmpty) {
    return message;
  }
  final path = evidence.path?.text;
  if (path != null && path.trim().isNotEmpty) {
    return '${issue.code.name}: $path';
  }
  return issue.code.name;
}

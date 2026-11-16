part of 'scan_home_page.dart';

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

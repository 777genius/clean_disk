part of 'scan_home_page.dart';

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
        ? (isRunning ? _formatBytes(BigInt.zero) : l10n.metricNoDataValue)
        : _formatBytes(summary.totalSize!);
    final totalSubtitle = scannedItems == null
        ? (isRunning ? l10n.metricScanningSubtitle : l10n.metricNoDataValue)
        : '$scannedItems ${l10n.filesCountSuffix}';
    final largestValue = largest?.name ?? l10n.metricNoDataValue;
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
    required this.collapsed,
    required this.onToggleCollapsed,
    this.rowsScrollable = true,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final VoidCallback? onScan;
  final bool showEmptyScanAction;
  final ValueChanged<ScanTarget> onRefreshFolderTarget;
  final VoidCallback onClearSearch;
  final VoidCallback onStoreChanged;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
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
    final showTableHeader = tableRows.isNotEmpty || queryBanner != null;

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
          showTableHeader: showTableHeader,
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
    required bool showTableHeader,
  }) {
    final table = AppTreeTable(
      title: showTableHeader ? l10n.nodeTableTitle : null,
      subtitle: showTableHeader
          ? '${_targetDisplayName(activeTarget)} - ${l10n.detailsItemsCount(count: tableRows.length)}'
          : null,
      collapsed: showTableHeader && collapsed,
      expandTooltip: l10n.nodeTableExpandAction,
      collapseTooltip: l10n.nodeTableCollapseAction,
      onToggleCollapsed: showTableHeader ? onToggleCollapsed : null,
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
                                  Tooltip(
                                    message: details.summary.name,
                                    child: Text(
                                      details.summary.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0,
                                            height: 1.05,
                                          ),
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
                            const SizedBox(width: 10),
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
                          valueMaxLines: 2,
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
                                    : Icons.delete_outline,
                                label: movedToTrash
                                    ? l10n.movedToTrashRowLabel
                                    : alreadyQueued
                                    ? l10n.reviewAddedAction
                                    : l10n.addToQueueAction,
                                accent: movedToTrash || !alreadyQueued
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
          _PaneToggleAction(
            buttonKey: const ValueKey('details-pane-info-action'),
            icon: Icons.info_outline,
            iconColor: _ScanColors.violet,
            tooltip: l10n.detailsTitle,
            onTap: onExpand,
          ),
        ],
      ),
    );
  }
}

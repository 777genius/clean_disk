part of 'scan_home_page.dart';

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.compact,
    required this.statusText,
    required this.searchController,
    required this.searchFocusNode,
    required this.currentSort,
    required this.queryMode,
    required this.activeTarget,
    required this.targetChoices,
    required this.isLoadingTargetChoices,
    required this.runtimeProof,
    required this.scanActionLabel,
    required this.canSearch,
    required this.canSort,
    required this.canPickTarget,
    required this.canRepairPermission,
    required this.canScan,
    required this.onScan,
    required this.onPickTarget,
    required this.onChooseTarget,
    required this.onChooseFolderTarget,
    required this.onPermissionProbe,
    required this.onPermissionRepair,
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
  final List<ScanTargetChoice> targetChoices;
  final bool isLoadingTargetChoices;
  final RuntimeProof runtimeProof;
  final String scanActionLabel;
  final bool canSearch;
  final bool canSort;
  final bool canPickTarget;
  final bool canRepairPermission;
  final bool canScan;
  final VoidCallback? onScan;
  final VoidCallback onPickTarget;
  final ValueChanged<ScanTargetChoice> onChooseTarget;
  final VoidCallback onChooseFolderTarget;
  final VoidCallback onPermissionProbe;
  final VoidCallback onPermissionRepair;
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
                _HeaderTargetPicker(
                  activeTarget: activeTarget,
                  targetChoices: targetChoices,
                  isLoadingTargetChoices: isLoadingTargetChoices,
                  runtimeProof: runtimeProof,
                  scanActionLabel: scanActionLabel,
                  canPickTarget: canPickTarget,
                  canScan: canScan,
                  canRepairPermission: canRepairPermission,
                  onPickTarget: onPickTarget,
                  onChooseTarget: onChooseTarget,
                  onChooseFolderTarget: onChooseFolderTarget,
                  onPermissionProbe: onPermissionProbe,
                  onPermissionRepair: onPermissionRepair,
                  onScan: onScan,
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

class _AiAssistantRail extends StatelessWidget {
  const _AiAssistantRail({
    required this.store,
    required this.activeTarget,
    required this.onScan,
    required this.onCollapse,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final VoidCallback? onScan;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final summary = _metricSummary(store);
    final selected = store.selectedDetails?.summary;
    final focusName =
        selected?.name ??
        summary.largest?.name ??
        _targetDisplayName(activeTarget);
    final focusSize = selected == null
        ? (summary.largest == null
              ? (_metricSummarySizeText(store) ?? l10n.metricNoDataValue)
              : _formatSize(summary.largest!.size))
        : _formatSize(selected.size);
    final isRunning = store.sessionStatus?.state == SessionState.running;
    final statusText = isRunning
        ? l10n.aiStatusScanning
        : store.hasReadableSnapshot
        ? l10n.aiStatusReady
        : l10n.aiStatusRunScanFirst;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _ScanColors.cyan.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: _ScanColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiAssistantTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(context),
                    ),
                    Text(
                      l10n.aiAssistantSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(
                        context,
                      ).copyWith(color: _ScanColors.textSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PaneToggleAction(
                buttonKey: const ValueKey('scan-ai-collapse-action'),
                icon: Icons.keyboard_double_arrow_left,
                iconColor: _ScanColors.cyan,
                tooltip: l10n.aiAssistantTitle,
                onTap: onCollapse,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AiFocusSummary(
            title: focusName,
            subtitle: focusSize,
            status: statusText,
          ),
          const SizedBox(height: 16),
          _SectionCaption(l10n.aiHistorySection.toUpperCase()),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _AiMessageBubble(
                  author: l10n.aiAuthorAssistant,
                  text: l10n.aiIntroMessage,
                ),
                const SizedBox(height: 8),
                _AiMessageBubble(
                  author: l10n.aiAuthorUser,
                  text: l10n.aiUserStarterMessage,
                  user: true,
                ),
                const SizedBox(height: 8),
                _AiMessageBubble(
                  author: l10n.aiAuthorAssistant,
                  text: store.hasReadableSnapshot
                      ? l10n.aiSnapshotAdvice(focusName: focusName)
                      : l10n.aiNoSnapshotAdvice,
                ),
                const SizedBox(height: 12),
                _AiQuickHint(
                  icon: Icons.rule_folder_outlined,
                  title: l10n.aiSafeModeTitle,
                  text: l10n.aiSafeModeText,
                ),
                const SizedBox(height: 8),
                _AiQuickHint(
                  icon: Icons.history,
                  title: l10n.aiDialogMemoryTitle,
                  text: l10n.aiDialogMemoryText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('scan-ai-chat-input'),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _ScanColors.input,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: _ScanColors.cyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.aiAskPlaceholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(
                      context,
                    ).copyWith(color: _ScanColors.textSoft),
                  ),
                ),
              ],
            ),
          ),
          if (!store.hasReadableSnapshot && onScan != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(l10n.scanAction),
                style: FilledButton.styleFrom(
                  backgroundColor: _ScanColors.cyan,
                  foregroundColor: _ScanColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollapsedAiRail extends StatelessWidget {
  const _CollapsedAiRail({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;

    return Container(
      key: const ValueKey('scan-ai-collapsed-rail'),
      width: _WideWorkspace._collapsedAssistantRailWidth,
      color: _ScanColors.background,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          _PaneToggleAction(
            buttonKey: const ValueKey('scan-ai-expand-action'),
            icon: Icons.keyboard_double_arrow_right,
            tooltip: l10n.aiAssistantTitle,
            onTap: onExpand,
          ),
          const SizedBox(height: 8),
          _PaneToggleAction(
            buttonKey: const ValueKey('scan-ai-indicator-action'),
            icon: Icons.auto_awesome,
            iconColor: _ScanColors.cyan,
            tooltip: l10n.aiAssistantTitle,
            onTap: onExpand,
          ),
          const SizedBox(height: 14),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              'AI',
              maxLines: 1,
              style: _titleStyle(context).copyWith(
                color: _ScanColors.cyan,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chat_bubble_outline,
            color: _ScanColors.textSoft.withValues(alpha: 0.72),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _AiFocusSummary extends StatelessWidget {
  const _AiFocusSummary({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('scan-ai-focus-summary'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _ScanColors.border),
          bottom: BorderSide(color: _ScanColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.saved_search, color: _ScanColors.violet, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subtitle - $status',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: _ScanColors.textSoft, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMessageBubble extends StatelessWidget {
  const _AiMessageBubble({
    required this.author,
    required this.text,
    this.user = false,
  });

  final String author;
  final String text;
  final bool user;

  @override
  Widget build(BuildContext context) {
    final accent = user ? _ScanColors.blue : _ScanColors.cyan;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: user ? 0.86 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: user
                ? _ScanColors.selectedSoft.withAlpha(160)
                : _ScanColors.innerPanel,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: _bodyStyle(
                  context,
                ).copyWith(color: _ScanColors.text, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiQuickHint extends StatelessWidget {
  const _AiQuickHint({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _ScanColors.textSoft, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: _bodyStyle(
                context,
              ).copyWith(color: _ScanColors.textSoft, height: 1.22),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    color: _ScanColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
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

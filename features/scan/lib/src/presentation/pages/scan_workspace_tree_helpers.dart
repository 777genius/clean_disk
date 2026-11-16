part of 'scan_home_page.dart';

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

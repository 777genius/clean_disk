part of 'scan_home_page.dart';

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
  final _MetricSummaryItem? largest;

  bool get hasData => totalSize != null || largest != null;
}

final class _MetricSummaryItem {
  const _MetricSummaryItem({
    required this.id,
    required this.parentId,
    required this.name,
    required this.kind,
    required this.size,
  });

  final String id;
  final String? parentId;
  final String name;
  final NodeKind kind;
  final SizeFact size;

  BigInt get sizeBytes => size.byteEquivalentBigInt ?? size.rawBigInt;
}

_MetricSummary _metricSummary(ScanWorkspaceStore store) {
  final focusedNode = store.diskUsageMapFocusNode;
  final rootNode = focusedNode ?? store.diskUsageMapRootNode;
  final diskRows = store.diskUsageMapRows;
  if (diskRows.isNotEmpty || rootNode != null) {
    final rootSummaryItem = rootNode == null
        ? null
        : _metricSummaryItemFromRow(rootNode);
    final positiveRows = _positiveSummaryItems(
      diskRows.map(_metricSummaryItemFromRow),
    );
    final rootSize = rootNode == null ? null : _diskUsageMapSize(rootNode);
    return _MetricSummary(
      totalSize: rootSize != null && rootSize > BigInt.zero
          ? rootSize
          : _coveredSummarySizeOrNull(positiveRows),
      largest: _largestSummaryItem(
        positiveRows,
        excludedIds: rootSummaryItem == null ? const {} : {rootSummaryItem.id},
      ),
    );
  }

  final partialRows = store.partialVisibleRows;
  if (partialRows.isNotEmpty) {
    final rows = _positiveSummaryItems(
      partialRows.map(_metricSummaryItemFromPartialRow),
    );
    final rootIds = {
      for (final row in rows)
        if (row.parentId == null) row.id,
    };
    return _MetricSummary(
      totalSize: _coveredSummarySizeOrNull(rows),
      largest: _largestSummaryItem(rows, excludedIds: rootIds),
    );
  }

  final rows = _positiveSummaryItems(
    _summaryRows(store).map(_metricSummaryItemFromRow),
  );
  return _MetricSummary(
    totalSize: _coveredSummarySizeOrNull(rows),
    largest: _largestSummaryItem(rows),
  );
}

String? _metricSummarySizeText(ScanWorkspaceStore store) {
  final totalSize = _metricSummary(store).totalSize;
  return totalSize == null ? null : _formatBytes(totalSize);
}

_MetricSummaryItem _metricSummaryItemFromRow(NodePageItem row) {
  return _MetricSummaryItem(
    id: row.nodeId.value,
    parentId: row.parentId?.value,
    name: row.name,
    kind: row.kind,
    size: row.size,
  );
}

_MetricSummaryItem _metricSummaryItemFromPartialRow(PartialNodeItem row) {
  return _MetricSummaryItem(
    id: row.nodeId.value,
    parentId: row.parentId?.value,
    name: row.name,
    kind: row.kind,
    size: row.aggregateSize,
  );
}

List<_MetricSummaryItem> _positiveSummaryItems(
  Iterable<_MetricSummaryItem> rows,
) {
  return [
    for (final row in rows)
      if (row.sizeBytes > BigInt.zero) row,
  ];
}

BigInt? _coveredSummarySizeOrNull(List<_MetricSummaryItem> rows) {
  if (rows.isEmpty) {
    return null;
  }
  final sortedRows = [...rows]
    ..sort((left, right) {
      return right.sizeBytes.compareTo(left.sizeBytes);
    });
  var total = BigInt.zero;
  final covered = <String>{};
  final rowById = {for (final row in sortedRows) row.id: row};
  for (final row in sortedRows) {
    if (_hasCoveredMetricAncestor(row, covered, rowById)) {
      continue;
    }
    covered.add(row.id);
    total += row.sizeBytes;
  }
  return total;
}

bool _hasCoveredMetricAncestor(
  _MetricSummaryItem row,
  Set<String> covered,
  Map<String, _MetricSummaryItem> rowById,
) {
  var parentId = row.parentId;
  final visited = <String>{row.id};
  while (parentId != null && visited.add(parentId)) {
    if (covered.contains(parentId)) {
      return true;
    }
    parentId = rowById[parentId]?.parentId;
  }
  return false;
}

_MetricSummaryItem? _largestSummaryItem(
  List<_MetricSummaryItem> rows, {
  Set<String> excludedIds = const {},
}) {
  if (rows.isEmpty) {
    return null;
  }
  final candidates = [
    for (final row in rows)
      if (!excludedIds.contains(row.id) && row.sizeBytes > BigInt.zero) row,
  ];
  if (candidates.isEmpty && excludedIds.isEmpty) {
    return null;
  }
  final effectiveCandidates = candidates.isEmpty ? rows : candidates;

  final directories = [
    for (final row in effectiveCandidates)
      if (row.kind == NodeKind.directory) row,
  ];
  final pool = directories.isEmpty ? effectiveCandidates : directories;
  pool.sort((left, right) {
    return right.sizeBytes.compareTo(left.sizeBytes);
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

final class _DiskUsageMapBreadcrumbItem {
  const _DiskUsageMapBreadcrumbItem({
    required this.label,
    required this.nodeId,
    required this.selected,
  });

  final String label;
  final NodeId? nodeId;
  final bool selected;
}

List<_DiskUsageMapBreadcrumbItem> _diskUsageMapBreadcrumbItems({
  required ScanWorkspaceStore store,
  required ScanTarget activeTarget,
}) {
  final focusedNode = store.diskUsageMapFocusNode;
  final rootLabel = _targetDisplayName(activeTarget);
  if (focusedNode == null) {
    return [
      _DiskUsageMapBreadcrumbItem(
        label: rootLabel,
        nodeId: null,
        selected: true,
      ),
    ];
  }

  final rowsById = <NodeId, NodePageItem>{};
  final rootNode = store.diskUsageMapRootNode;
  if (rootNode != null) {
    rowsById[rootNode.nodeId] = rootNode;
  }
  for (final row in store.diskUsageMapAllRows) {
    rowsById[row.nodeId] = row;
  }
  for (final row in store.visibleRows) {
    rowsById[row.nodeId] = row;
  }
  final focusedPath = <NodePageItem>[];
  var current = focusedNode;
  final visited = <NodeId>{};
  while (visited.add(current.nodeId)) {
    focusedPath.add(current);
    final parentId = current.parentId;
    if (parentId == null ||
        parentId == store.viewport.parentId ||
        parentId == store.primaryRootNodeId ||
        parentId == store.diskUsageMapRootNode?.nodeId) {
      break;
    }
    final parent = rowsById[parentId];
    if (parent == null) {
      break;
    }
    current = parent;
  }

  return [
    _DiskUsageMapBreadcrumbItem(
      label: rootLabel,
      nodeId: null,
      selected: false,
    ),
    for (final row in focusedPath.reversed)
      _DiskUsageMapBreadcrumbItem(
        label: row.name,
        nodeId: row.nodeId,
        selected: row.nodeId == focusedNode.nodeId,
      ),
  ];
}

NodeId? _diskUsageMapParentBreadcrumbNodeId(
  List<_DiskUsageMapBreadcrumbItem> items,
) {
  if (items.length <= 1) {
    return null;
  }
  return items[items.length - 2].nodeId;
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
    return isRunning ? '0' : l10n.metricNoDataValue;
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
    return isRunning ? _formatElapsed(BigInt.zero) : l10n.metricNoDataValue;
  }
  return _formatElapsed(elapsedMs);
}

String _progressThroughputText(
  CleanDiskLocalizations l10n,
  ScanProgress? progress, {
  required bool isRunning,
}) {
  if (progress == null) {
    return isRunning
        ? '0 ${l10n.progressItemsPerSecondSuffix}'
        : l10n.metricNoDataValue;
  }
  final bytesPerSecond = progress.throughputBytesPerSec;
  if (bytesPerSecond != null) {
    return '${_formatBytes(bytesPerSecond)} /s';
  }

  final elapsedMs = progress.elapsedMs;
  if (elapsedMs == null || elapsedMs <= BigInt.zero) {
    return isRunning
        ? '0 ${l10n.progressItemsPerSecondSuffix}'
        : l10n.metricNoDataValue;
  }

  final itemsPerSecond =
      progress.scannedItems.toDouble() / (elapsedMs.toDouble() / 1000);
  if (!itemsPerSecond.isFinite || itemsPerSecond <= 0) {
    return isRunning
        ? '0 ${l10n.progressItemsPerSecondSuffix}'
        : l10n.metricNoDataValue;
  }

  return '${_formatRate(itemsPerSecond)} ${l10n.progressItemsPerSecondSuffix}';
}

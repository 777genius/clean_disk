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
  final parts = _knownTreePathParts(store, selected.nodeId);
  if (parts.isEmpty) {
    return _joinDisplayPath(target.path.value, ['...', selected.name]);
  }
  return _joinDisplayPath(
    target.path.value,
    _pathPartsRelativeToTarget(target.path.value, parts),
  );
}

List<String> _knownTreePathParts(ScanWorkspaceStore store, NodeId nodeId) {
  final visibleParts = _visibleTreePathParts(store, nodeId);
  if (visibleParts.isNotEmpty) {
    return visibleParts;
  }

  final rowsById = <NodeId, NodePageItem>{};
  for (final row in store.visibleTreeRows) {
    rowsById[row.item.nodeId] = row.item;
  }
  for (final row in store.visibleRows) {
    rowsById.putIfAbsent(row.nodeId, () => row);
  }
  for (final row in store.diskUsageMapAllRows) {
    rowsById.putIfAbsent(row.nodeId, () => row);
  }

  final selected = rowsById[nodeId];
  if (selected == null) {
    return const [];
  }

  final parts = <String>[];
  var current = selected;
  final treeRootParentId = store.viewport.parentId;
  final visited = <NodeId>{};
  while (visited.add(current.nodeId)) {
    parts.add(current.name);
    final parentId = current.parentId;
    if (parentId == null || parentId == treeRootParentId) {
      break;
    }
    final parent = rowsById[parentId];
    if (parent == null) {
      return const [];
    }
    current = parent;
  }
  return parts.reversed.toList(growable: false);
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

bool _shouldShowPermissionProof(
  RuntimeProof proof, {
  required VoidCallback? onRepair,
}) {
  if (onRepair != null) {
    return true;
  }
  return !_hasConfirmedPermissionAccess(proof);
}

bool _hasConfirmedPermissionAccess(RuntimeProof proof) {
  return proof.permissionProbe.status == PermissionProbeStatus.verified &&
      proof.permissionProbe.requiredAction == PermissionRequiredAction.none;
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

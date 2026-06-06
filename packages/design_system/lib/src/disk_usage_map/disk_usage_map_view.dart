import 'package:flutter/material.dart';

import 'disk_usage_map_models.dart';
import 'disk_usage_map_renderer.dart';

class DiskUsageMapView extends StatelessWidget {
  const DiskUsageMapView({
    super.key,
    required this.projection,
    required this.renderer,
    required this.labels,
    required this.style,
    this.selectedNodeId,
    this.focusedNodeId,
    this.onTileHoverChanged,
    this.onTileSelected,
    this.onTileActivated,
    this.onTileContextMenu,
    this.emptyState,
    this.showDataFallback = false,
    this.dataFallbackMaxItems = 8,
  });

  final DiskUsageMapProjection projection;
  final DiskUsageMapRenderer renderer;
  final DiskUsageMapViewLabels labels;
  final DiskUsageMapStyle style;
  final String? selectedNodeId;
  final String? focusedNodeId;
  final DiskUsageMapTileHoverCallback? onTileHoverChanged;
  final DiskUsageMapTileCallback? onTileSelected;
  final DiskUsageMapTileCallback? onTileActivated;
  final DiskUsageMapTileContextMenuCallback? onTileContextMenu;
  final Widget? emptyState;
  final bool showDataFallback;
  final int dataFallbackMaxItems;

  @override
  Widget build(BuildContext context) {
    if (projection.isEmpty) {
      return emptyState ?? _DiskUsageMapMessage(labels: labels, style: style);
    }

    if (!renderer.capabilities.supportsKind(projection.kind)) {
      return DiskUsageMapDataFallback(
        projection: projection,
        labels: labels,
        style: style,
        selectedNodeId: selectedNodeId,
        maxItems: dataFallbackMaxItems,
        message: labels.unsupportedRendererMessage,
        onTileSelected: onTileSelected,
      );
    }

    final renderContext = DiskUsageMapRenderContext(
      projection: projection,
      labels: labels,
      style: style,
      selectedNodeId: selectedNodeId,
      focusedNodeId: focusedNodeId,
      onTileHoverChanged: onTileHoverChanged,
      onTileSelected: onTileSelected,
      onTileActivated: onTileActivated,
      onTileContextMenu: onTileContextMenu,
    );

    late final Widget renderedMap;
    try {
      renderedMap = renderer.build(context, renderContext);
    } catch (_) {
      return DiskUsageMapDataFallback(
        projection: projection,
        labels: labels,
        style: style,
        selectedNodeId: selectedNodeId,
        maxItems: dataFallbackMaxItems,
        message: labels.renderFailureMessage,
        onTileSelected: onTileSelected,
      );
    }

    return Semantics(
      container: true,
      label: labels.title,
      value: _semanticValue(),
      child: showDataFallback
          ? Column(
              children: [
                Expanded(child: renderedMap),
                const SizedBox(height: 8),
                SizedBox(
                  height: 128,
                  child: DiskUsageMapDataFallback(
                    projection: projection,
                    labels: labels,
                    style: style,
                    selectedNodeId: selectedNodeId,
                    maxItems: dataFallbackMaxItems,
                    onTileSelected: onTileSelected,
                  ),
                ),
              ],
            )
          : renderedMap,
    );
  }

  String _semanticValue() {
    final parts = <String>[
      labels.description,
      '${projection.visualTiles.length} tiles',
    ];

    if (projection.freshness == DiskUsageMapFreshness.stale) {
      parts.add(labels.stalePrefix);
    }

    if (projection.warnings.isNotEmpty) {
      parts.add('${labels.warningPrefix}: ${projection.warnings.length}');
    }

    final hidden = projection.hiddenSummary;
    if (hidden != null) {
      parts.add('${hidden.label}: ${hidden.itemCount}');
    }

    return parts.join('. ');
  }
}

class DiskUsageMapDataFallback extends StatelessWidget {
  const DiskUsageMapDataFallback({
    super.key,
    required this.projection,
    required this.labels,
    required this.style,
    this.selectedNodeId,
    this.maxItems = 8,
    this.message,
    this.onTileSelected,
  });

  final DiskUsageMapProjection projection;
  final DiskUsageMapViewLabels labels;
  final DiskUsageMapStyle style;
  final String? selectedNodeId;
  final int maxItems;
  final String? message;
  final DiskUsageMapTileCallback? onTileSelected;

  @override
  Widget build(BuildContext context) {
    final visibleTiles = projection.visualTiles.take(maxItems).toList();

    return Container(
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(style.borderRadius),
        border: Border.all(color: style.borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labels.dataFallbackTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: style.textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: style.mutedTextColor,
                letterSpacing: 0,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              primary: false,
              itemCount: visibleTiles.length,
              itemBuilder: (context, index) {
                final tile = visibleTiles[index];
                return _DiskUsageMapFallbackRow(
                  tile: tile,
                  selected: tile.nodeId == selectedNodeId,
                  style: style,
                  onTap: onTileSelected == null
                      ? null
                      : () => onTileSelected!(tile),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiskUsageMapMessage extends StatelessWidget {
  const _DiskUsageMapMessage({required this.labels, required this.style});

  final DiskUsageMapViewLabels labels;
  final DiskUsageMapStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(style.borderRadius),
        border: Border.all(color: style.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            labels.emptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: style.textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            labels.emptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.mutedTextColor,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiskUsageMapFallbackRow extends StatelessWidget {
  const _DiskUsageMapFallbackRow({
    required this.tile,
    required this.selected,
    required this.style,
    this.onTap,
  });

  final DiskUsageMapTile tile;
  final bool selected;
  final DiskUsageMapStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tileColor = style.colorForTile(tile);
    final sizeText = _formatSizeBytesDecimal(tile.sizeBytesDecimal);

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${tile.label}, $sizeText',
      child: InkWell(
        onTap: tile.disabled ? null : onTap,
        child: Opacity(
          opacity: tile.disabled ? style.disabledOpacity : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tile.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? style.selectedTileBorderColor
                          : style.textColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  sizeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: style.mutedTextColor,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatSizeBytesDecimal(String value) {
  final bytes = BigInt.tryParse(value);
  if (bytes == null) {
    return value;
  }
  final decimalBytes = bytes.toDouble();
  if (decimalBytes >= 1000 * 1000 * 1000) {
    return '${(decimalBytes / (1000 * 1000 * 1000)).toStringAsFixed(1)} GB';
  }
  if (decimalBytes >= 1000 * 1000) {
    return '${(decimalBytes / (1000 * 1000)).toStringAsFixed(1)} MB';
  }
  if (decimalBytes >= 1000) {
    return '${(decimalBytes / 1000).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

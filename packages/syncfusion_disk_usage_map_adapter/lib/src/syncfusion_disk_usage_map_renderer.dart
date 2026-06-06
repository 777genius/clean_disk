import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_treemap/treemap.dart';

class SyncfusionDiskUsageMapRenderer implements DiskUsageMapRenderer {
  const SyncfusionDiskUsageMapRenderer();

  @override
  DiskUsageMapRendererCapabilities get capabilities =>
      const DiskUsageMapRendererCapabilities(
        rendererName: 'syncfusion_flutter_treemap',
        trustLevel: DiskUsageMapRendererTrustLevel.experimental,
        supportedKinds: <DiskUsageMapKind>{DiskUsageMapKind.treemap},
        keyboardSelection: DiskUsageMapRendererCapabilityLevel.degraded,
        semanticSummary: DiskUsageMapRendererCapabilityLevel.supported,
        individualTileSemantics: DiskUsageMapRendererCapabilityLevel.degraded,
        reducedMotion: DiskUsageMapRendererCapabilityLevel.degraded,
        rtl: DiskUsageMapRendererCapabilityLevel.degraded,
        highContrast: DiskUsageMapRendererCapabilityLevel.degraded,
        dataFallback: DiskUsageMapRendererCapabilityLevel.supported,
      );

  @override
  Widget build(BuildContext context, DiskUsageMapRenderContext renderContext) {
    final projection = renderContext.projection;
    final data = _SyncfusionDiskUsageMapData.fromProjection(projection);
    if (data.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(renderContext.style.borderRadius),
      child: ColoredBox(
        color: renderContext.style.backgroundColor,
        child: SfTreemap(
          dataCount: data.entries.length,
          weightValueMapper: (index) => data.entries[index].weight,
          tileHoverColor: renderContext.style.selectedTileBorderColor
              .withValues(alpha: 0.12),
          tileHoverBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              renderContext.style.tileBorderRadius,
            ),
            side: BorderSide(
              color: renderContext.style.focusedTileBorderColor,
              width: 1.5,
            ),
          ),
          tooltipSettings: TreemapTooltipSettings(
            color: renderContext.style.backgroundColor,
            borderColor: renderContext.style.borderColor,
            borderWidth: 1,
            borderRadius: BorderRadius.circular(
              renderContext.style.borderRadius,
            ),
          ),
          levels: <TreemapLevel>[
            for (var levelIndex = 0; levelIndex < data.levelCount; levelIndex++)
              TreemapLevel(
                padding: EdgeInsets.all(renderContext.style.tileGap),
                border: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    renderContext.style.tileBorderRadius,
                  ),
                  side: BorderSide(color: renderContext.style.tileBorderColor),
                ),
                groupMapper: (index) => data.entries[index].groupAt(levelIndex),
                colorValueMapper: (syncfusionTile) {
                  final tile = data.tileForGroup(syncfusionTile.group);
                  if (tile == null) {
                    return renderContext.style.otherColor;
                  }

                  return renderContext.style.colorForTile(tile);
                },
                tooltipBuilder: (context, syncfusionTile) {
                  final tile = data.tileForGroup(syncfusionTile.group);
                  if (tile == null) {
                    return null;
                  }

                  return _SyncfusionDiskUsageMapTooltip(
                    tile: tile,
                    style: renderContext.style,
                  );
                },
                labelBuilder: (context, syncfusionTile) {
                  if (!syncfusionTile.hasDescendants) {
                    return null;
                  }
                  final tile = data.tileForGroup(syncfusionTile.group);
                  if (tile == null) {
                    return const SizedBox.shrink();
                  }

                  return _SyncfusionDiskUsageMapTile(
                    tile: tile,
                    selected: tile.nodeId == renderContext.selectedNodeId,
                    focused: tile.nodeId == renderContext.focusedNodeId,
                    compact: syncfusionTile.hasDescendants,
                    style: renderContext.style,
                    onHoverChanged: renderContext.onTileHoverChanged,
                    onSelected: renderContext.onTileSelected,
                    onActivated: renderContext.onTileActivated,
                    onContextMenu: renderContext.onTileContextMenu,
                  );
                },
                itemBuilder: (context, syncfusionTile) {
                  if (syncfusionTile.hasDescendants) {
                    return null;
                  }
                  final tile = data.tileForGroup(syncfusionTile.group);
                  if (tile == null) {
                    return const SizedBox.shrink();
                  }

                  return _SyncfusionDiskUsageMapTile(
                    tile: tile,
                    selected: tile.nodeId == renderContext.selectedNodeId,
                    focused: tile.nodeId == renderContext.focusedNodeId,
                    compact: false,
                    style: renderContext.style,
                    onHoverChanged: renderContext.onTileHoverChanged,
                    onSelected: renderContext.onTileSelected,
                    onActivated: renderContext.onTileActivated,
                    onContextMenu: renderContext.onTileContextMenu,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

final class _SyncfusionDiskUsageMapData {
  const _SyncfusionDiskUsageMapData({
    required this.entries,
    required this.levelCount,
    required this.tileByGroup,
  });

  factory _SyncfusionDiskUsageMapData.fromProjection(
    DiskUsageMapProjection projection,
  ) {
    final tiles = [
      for (final tile in projection.visualTiles)
        if (_tileSizeBytes(tile) > BigInt.zero) tile,
    ];
    final tileByGroup = <String, DiskUsageMapTile>{
      for (final tile in tiles) tile.nodeId: tile,
    };
    final entries = <_SyncfusionDiskUsageMapEntry>[];
    for (final tile in tiles) {
      entries.add(
        _SyncfusionDiskUsageMapEntry(
          groups: <String>[tile.nodeId],
          weight: _tileWeight(tile),
        ),
      );
    }

    return _SyncfusionDiskUsageMapData(
      entries: entries,
      levelCount: entries.isEmpty ? 0 : 1,
      tileByGroup: tileByGroup,
    );
  }

  final List<_SyncfusionDiskUsageMapEntry> entries;
  final int levelCount;
  final Map<String, DiskUsageMapTile> tileByGroup;

  DiskUsageMapTile? tileForGroup(String group) => tileByGroup[group];
}

final class _SyncfusionDiskUsageMapEntry {
  const _SyncfusionDiskUsageMapEntry({
    required this.groups,
    required this.weight,
  });

  final List<String> groups;
  final double weight;

  String? groupAt(int index) {
    if (index >= groups.length) {
      return null;
    }
    return groups[index];
  }
}

double _tileWeight(DiskUsageMapTile tile) {
  final bytes = _tileSizeBytes(tile);
  if (bytes <= BigInt.zero) {
    return 0.01;
  }
  return bytes.toDouble();
}

BigInt _tileSizeBytes(DiskUsageMapTile tile) {
  return BigInt.tryParse(tile.sizeBytesDecimal) ?? BigInt.zero;
}

class _SyncfusionDiskUsageMapTile extends StatelessWidget {
  const _SyncfusionDiskUsageMapTile({
    required this.tile,
    required this.selected,
    required this.focused,
    required this.compact,
    required this.style,
    this.onHoverChanged,
    this.onSelected,
    this.onActivated,
    this.onContextMenu,
  });

  final DiskUsageMapTile tile;
  final bool selected;
  final bool focused;
  final bool compact;
  final DiskUsageMapStyle style;
  final DiskUsageMapTileHoverCallback? onHoverChanged;
  final DiskUsageMapTileCallback? onSelected;
  final DiskUsageMapTileCallback? onActivated;
  final DiskUsageMapTileContextMenuCallback? onContextMenu;

  static const _labelColor = Color(0xFFFFFFFF);
  static const _sizeColor = Color(0xFFFFE08A);
  static const _textShadows = <Shadow>[
    Shadow(color: Color(0xB3000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? style.selectedTileBorderColor
        : focused
        ? style.focusedTileBorderColor
        : Colors.transparent;
    final enabled = !tile.disabled;
    final sizeText = _formatSizeBytesDecimal(tile.sizeBytesDecimal);

    return Semantics(
      button: enabled && onSelected != null,
      selected: selected,
      label: '${tile.label}, $sizeText',
      child: MouseRegion(
        onEnter: (_) => onHoverChanged?.call(tile),
        onExit: (_) => onHoverChanged?.call(null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled && onSelected != null ? () => onSelected!(tile) : null,
          onDoubleTap: enabled && onActivated != null
              ? () => onActivated!(tile)
              : null,
          onSecondaryTapDown: enabled && onContextMenu != null
              ? (details) => onContextMenu!(tile, details.globalPosition)
              : null,
          child: Opacity(
            opacity: enabled ? 1 : style.disabledOpacity,
            child: Container(
              width: double.infinity,
              height: compact ? 30 : double.infinity,
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
                  : const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(style.tileBorderRadius),
                border: Border.all(color: borderColor, width: selected ? 2 : 1),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final labelStyle =
                      Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _labelColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        shadows: _textShadows,
                      ) ??
                      const TextStyle(
                        color: _labelColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        shadows: _textShadows,
                      );
                  final sizeStyle =
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _sizeColor,
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        shadows: _textShadows,
                      ) ??
                      const TextStyle(
                        color: _sizeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        shadows: _textShadows,
                      );
                  final maxTextWidth =
                      constraints.maxWidth.isFinite && constraints.maxWidth > 0
                      ? constraints.maxWidth
                      : 160.0;

                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: FittedBox(
                        alignment: Alignment.topLeft,
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxTextWidth),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tile.label,
                                maxLines: compact || constraints.maxHeight < 54
                                    ? 1
                                    : 2,
                                overflow: TextOverflow.ellipsis,
                                style: labelStyle,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                sizeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: sizeStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncfusionDiskUsageMapTooltip extends StatelessWidget {
  const _SyncfusionDiskUsageMapTooltip({
    required this.tile,
    required this.style,
  });

  final DiskUsageMapTile tile;
  final DiskUsageMapStyle style;

  @override
  Widget build(BuildContext context) {
    final sizeText = _formatSizeBytesDecimal(tile.sizeBytesDecimal);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: DefaultTextStyle(
        style:
            Theme.of(context).textTheme.bodySmall?.copyWith(
              color: style.textColor,
              letterSpacing: 0,
            ) ??
            TextStyle(color: style.textColor, letterSpacing: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tile.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(sizeText),
            if (tile.displayPathHint != null) ...[
              const SizedBox(height: 4),
              Text(
                tile.displayPathHint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: style.mutedTextColor),
              ),
            ],
          ],
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

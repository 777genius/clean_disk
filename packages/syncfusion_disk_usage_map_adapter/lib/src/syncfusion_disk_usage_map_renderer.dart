import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';

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
        child: _FilledDiskUsageTreemap(
          data: data,
          renderContext: renderContext,
        ),
      ),
    );
  }
}

class _FilledDiskUsageTreemap extends StatelessWidget {
  const _FilledDiskUsageTreemap({
    required this.data,
    required this.renderContext,
  });

  final _SyncfusionDiskUsageMapData data;
  final DiskUsageMapRenderContext renderContext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        final positionedTiles = _layoutEntries(
          entries: data.entries,
          rect: Rect.fromLTWH(0, 0, width, height),
        );
        if (positionedTiles.isEmpty) {
          return const SizedBox.expand();
        }

        final tileGap = renderContext.style.tileGap;
        final padding = EdgeInsets.all(tileGap / 2);
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final positioned in positionedTiles)
              Positioned.fromRect(
                rect: positioned.rect,
                child: SizedBox.expand(
                  key: ValueKey(
                    'syncfusion-disk-map-slot-${positioned.entry.tile.nodeId}',
                  ),
                  child: Padding(
                    padding: padding,
                    child: _SyncfusionDiskUsageMapTile(
                      tile: positioned.entry.tile,
                      selected:
                          positioned.entry.tile.nodeId ==
                          renderContext.selectedNodeId,
                      focused:
                          positioned.entry.tile.nodeId ==
                          renderContext.focusedNodeId,
                      compact:
                          positioned.rect.width < 116 ||
                          positioned.rect.height < 72,
                      style: renderContext.style,
                      onHoverChanged: renderContext.onTileHoverChanged,
                      onSelected: renderContext.onTileSelected,
                      onActivated: renderContext.onTileActivated,
                      onContextMenu: renderContext.onTileContextMenu,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _SyncfusionDiskUsageMapData {
  const _SyncfusionDiskUsageMapData({required this.entries});

  factory _SyncfusionDiskUsageMapData.fromProjection(
    DiskUsageMapProjection projection,
  ) {
    final tiles = [
      for (final tile in projection.visualTiles)
        if (_tileSizeBytes(tile) > BigInt.zero) tile,
    ];
    final entries = <_SyncfusionDiskUsageMapEntry>[];
    for (final tile in tiles) {
      entries.add(
        _SyncfusionDiskUsageMapEntry(tile: tile, weight: _tileWeight(tile)),
      );
    }

    return _SyncfusionDiskUsageMapData(entries: entries);
  }

  final List<_SyncfusionDiskUsageMapEntry> entries;
}

final class _SyncfusionDiskUsageMapEntry {
  const _SyncfusionDiskUsageMapEntry({
    required this.tile,
    required this.weight,
  });

  final DiskUsageMapTile tile;
  final double weight;
}

final class _PositionedDiskUsageMapEntry {
  const _PositionedDiskUsageMapEntry({required this.entry, required this.rect});

  final _SyncfusionDiskUsageMapEntry entry;
  final Rect rect;
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

List<_PositionedDiskUsageMapEntry> _layoutEntries({
  required List<_SyncfusionDiskUsageMapEntry> entries,
  required Rect rect,
}) {
  if (entries.isEmpty || rect.width <= 0 || rect.height <= 0) {
    return const [];
  }

  final sorted = entries.toList(growable: false)
    ..sort((a, b) => b.weight.compareTo(a.weight));
  return _splitEntries(sorted, rect);
}

List<_PositionedDiskUsageMapEntry> _splitEntries(
  List<_SyncfusionDiskUsageMapEntry> entries,
  Rect rect,
) {
  if (entries.isEmpty) {
    return const [];
  }
  if (entries.length == 1) {
    return [
      for (final entry in entries)
        _PositionedDiskUsageMapEntry(entry: entry, rect: rect),
    ];
  }

  final totalWeight = _entryWeight(entries);
  if (totalWeight <= 0) {
    return [
      for (final entry in entries)
        _PositionedDiskUsageMapEntry(entry: entry, rect: rect),
    ];
  }

  var splitIndex = 1;
  var leadingWeight = entries.first.weight;
  var bestDistance = (totalWeight / 2 - leadingWeight).abs();
  var runningWeight = leadingWeight;
  for (var index = 1; index < entries.length - 1; index++) {
    runningWeight += entries[index].weight;
    final distance = (totalWeight / 2 - runningWeight).abs();
    if (distance < bestDistance) {
      splitIndex = index + 1;
      leadingWeight = runningWeight;
      bestDistance = distance;
    }
  }

  final leading = entries.sublist(0, splitIndex);
  final trailing = entries.sublist(splitIndex);
  if (trailing.isEmpty) {
    return [
      for (final entry in entries)
        _PositionedDiskUsageMapEntry(entry: entry, rect: rect),
    ];
  }

  final leadingFraction = (leadingWeight / totalWeight).clamp(0.0, 1.0);
  final splitVertical = rect.width >= rect.height;
  final firstRect = splitVertical
      ? Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width * leadingFraction,
          rect.height,
        )
      : Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width,
          rect.height * leadingFraction,
        );
  final secondRect = splitVertical
      ? Rect.fromLTWH(
          firstRect.right,
          rect.top,
          rect.right - firstRect.right,
          rect.height,
        )
      : Rect.fromLTWH(
          rect.left,
          firstRect.bottom,
          rect.width,
          rect.bottom - firstRect.bottom,
        );

  return [
    ..._splitEntries(leading, firstRect),
    ..._splitEntries(trailing, secondRect),
  ];
}

double _entryWeight(List<_SyncfusionDiskUsageMapEntry> entries) {
  var total = 0.0;
  for (final entry in entries) {
    total += entry.weight;
  }
  return total;
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
              height: double.infinity,
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
                  : const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: style.colorForTile(tile),
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

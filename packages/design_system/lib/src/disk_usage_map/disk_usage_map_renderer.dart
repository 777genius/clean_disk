import 'package:flutter/material.dart';

import 'disk_usage_map_models.dart';

typedef DiskUsageMapTileCallback = void Function(DiskUsageMapTile tile);
typedef DiskUsageMapTileHoverCallback = void Function(DiskUsageMapTile? tile);
typedef DiskUsageMapTileContextMenuCallback =
    void Function(DiskUsageMapTile tile, Offset globalPosition);

enum DiskUsageMapRendererTrustLevel {
  official,
  verifiedCommunity,
  experimental,
  localApp,
  testOnly,
  untrusted,
}

enum DiskUsageMapRendererCapabilityLevel { unsupported, degraded, supported }

final class DiskUsageMapRendererCapabilities {
  const DiskUsageMapRendererCapabilities({
    required this.rendererName,
    required this.trustLevel,
    required this.supportedKinds,
    this.keyboardSelection = DiskUsageMapRendererCapabilityLevel.degraded,
    this.semanticSummary = DiskUsageMapRendererCapabilityLevel.supported,
    this.individualTileSemantics = DiskUsageMapRendererCapabilityLevel.degraded,
    this.reducedMotion = DiskUsageMapRendererCapabilityLevel.supported,
    this.rtl = DiskUsageMapRendererCapabilityLevel.degraded,
    this.highContrast = DiskUsageMapRendererCapabilityLevel.degraded,
    this.dataFallback = DiskUsageMapRendererCapabilityLevel.supported,
  });

  final String rendererName;
  final DiskUsageMapRendererTrustLevel trustLevel;
  final Set<DiskUsageMapKind> supportedKinds;
  final DiskUsageMapRendererCapabilityLevel keyboardSelection;
  final DiskUsageMapRendererCapabilityLevel semanticSummary;
  final DiskUsageMapRendererCapabilityLevel individualTileSemantics;
  final DiskUsageMapRendererCapabilityLevel reducedMotion;
  final DiskUsageMapRendererCapabilityLevel rtl;
  final DiskUsageMapRendererCapabilityLevel highContrast;
  final DiskUsageMapRendererCapabilityLevel dataFallback;

  bool supportsKind(DiskUsageMapKind kind) => supportedKinds.contains(kind);
}

abstract interface class DiskUsageMapRenderer {
  DiskUsageMapRendererCapabilities get capabilities;

  Widget build(BuildContext context, DiskUsageMapRenderContext renderContext);
}

final class DiskUsageMapRenderContext {
  const DiskUsageMapRenderContext({
    required this.projection,
    required this.labels,
    required this.style,
    this.selectedNodeId,
    this.focusedNodeId,
    this.onTileHoverChanged,
    this.onTileSelected,
    this.onTileActivated,
    this.onTileContextMenu,
  });

  final DiskUsageMapProjection projection;
  final DiskUsageMapViewLabels labels;
  final DiskUsageMapStyle style;
  final String? selectedNodeId;
  final String? focusedNodeId;
  final DiskUsageMapTileHoverCallback? onTileHoverChanged;
  final DiskUsageMapTileCallback? onTileSelected;
  final DiskUsageMapTileCallback? onTileActivated;
  final DiskUsageMapTileContextMenuCallback? onTileContextMenu;
}

final class DiskUsageMapViewLabels {
  const DiskUsageMapViewLabels({
    required this.title,
    required this.description,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.dataFallbackTitle,
    required this.unsupportedRendererMessage,
    required this.renderFailureMessage,
    required this.otherLabel,
    this.stalePrefix = 'Stale',
    this.warningPrefix = 'Warning',
  });

  final String title;
  final String description;
  final String emptyTitle;
  final String emptyMessage;
  final String dataFallbackTitle;
  final String unsupportedRendererMessage;
  final String renderFailureMessage;
  final String otherLabel;
  final String stalePrefix;
  final String warningPrefix;
}

final class DiskUsageMapStyle {
  const DiskUsageMapStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.tileBorderColor,
    required this.selectedTileBorderColor,
    required this.focusedTileBorderColor,
    required this.warningColor,
    required this.protectedColor,
    required this.otherColor,
    required this.palette,
    this.borderRadius = 8,
    this.tileBorderRadius = 4,
    this.tileGap = 2,
    this.disabledOpacity = 0.5,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color mutedTextColor;
  final Color tileBorderColor;
  final Color selectedTileBorderColor;
  final Color focusedTileBorderColor;
  final Color warningColor;
  final Color protectedColor;
  final Color otherColor;
  final List<Color> palette;
  final double borderRadius;
  final double tileBorderRadius;
  final double tileGap;
  final double disabledOpacity;

  Color colorForTile(DiskUsageMapTile tile) {
    return switch (tile.kind) {
      DiskUsageMapTileKind.other => otherColor,
      DiskUsageMapTileKind.hidden ||
      DiskUsageMapTileKind.protected => protectedColor,
      DiskUsageMapTileKind.warning => warningColor,
      DiskUsageMapTileKind.node => _paletteColor(tile.colorKey),
    };
  }

  Color _paletteColor(String key) {
    if (palette.isEmpty) {
      return textColor;
    }

    return palette[key.hashCode.abs() % palette.length];
  }
}

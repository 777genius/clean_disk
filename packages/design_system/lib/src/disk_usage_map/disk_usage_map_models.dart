enum DiskUsageMapKind { treemap, sunburst, icicle, barRanking, donutBreakdown }

enum DiskUsageMapSizeBasis {
  logicalBytes,
  allocatedBytes,
  exclusiveBytes,
  reclaimableBytes,
}

enum DiskUsageMapFreshness { current, stale, unknown }

enum DiskUsageMapTileKind { node, other, hidden, protected, warning }

enum DiskUsageMapRiskHint { none, low, medium, high, unknown }

final class DiskUsageMapProjection {
  const DiskUsageMapProjection({
    required this.scanSnapshotId,
    required this.rootNodeId,
    required this.projectionId,
    required this.kind,
    required this.sizeBasis,
    required this.totalSizeBytesDecimal,
    required this.freshness,
    required this.tiles,
    this.generatedAt,
    this.hiddenSummary,
    this.otherTile,
    this.warnings = const <DiskUsageMapWarning>[],
  });

  final String scanSnapshotId;
  final String rootNodeId;
  final String projectionId;
  final DiskUsageMapKind kind;
  final DiskUsageMapSizeBasis sizeBasis;
  final String totalSizeBytesDecimal;
  final DateTime? generatedAt;
  final DiskUsageMapFreshness freshness;
  final List<DiskUsageMapTile> tiles;
  final DiskUsageMapSummary? hiddenSummary;
  final DiskUsageMapTile? otherTile;
  final List<DiskUsageMapWarning> warnings;

  bool get isEmpty => tiles.isEmpty && otherTile == null;

  List<DiskUsageMapTile> get visualTiles {
    final other = otherTile;
    if (other == null) {
      return tiles;
    }

    return <DiskUsageMapTile>[...tiles, other];
  }
}

final class DiskUsageMapTile {
  const DiskUsageMapTile({
    required this.nodeId,
    required this.label,
    required this.sizeBytesDecimal,
    required this.percentOfRootBasisPoints,
    required this.colorKey,
    required this.depth,
    required this.kind,
    required this.issueCount,
    required this.childCount,
    required this.hasMoreChildren,
    this.parentNodeId,
    this.displayPathHint,
    this.riskHint = DiskUsageMapRiskHint.none,
    this.disabled = false,
  });

  final String nodeId;
  final String? parentNodeId;
  final String label;
  final String? displayPathHint;
  final String sizeBytesDecimal;
  final int percentOfRootBasisPoints;
  final String colorKey;
  final int depth;
  final DiskUsageMapTileKind kind;
  final DiskUsageMapRiskHint riskHint;
  final int issueCount;
  final int childCount;
  final bool hasMoreChildren;
  final bool disabled;

  double get visualWeight {
    if (percentOfRootBasisPoints <= 0) {
      return 0.01;
    }

    return percentOfRootBasisPoints.toDouble();
  }

  double get fractionOfRoot => percentOfRootBasisPoints / 10000;
}

final class DiskUsageMapSummary {
  const DiskUsageMapSummary({
    required this.label,
    required this.sizeBytesDecimal,
    required this.itemCount,
  });

  final String label;
  final String sizeBytesDecimal;
  final int itemCount;
}

final class DiskUsageMapWarning {
  const DiskUsageMapWarning({required this.code, required this.message});

  final String code;
  final String message;
}

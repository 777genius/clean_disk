import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders map through a replaceable renderer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 260,
            child: DiskUsageMapView(
              projection: _projection,
              renderer: const _FakeDiskUsageMapRenderer(),
              labels: _labels,
              style: _style,
            ),
          ),
        ),
      ),
    );

    expect(find.text('fake renderer: 2'), findsOneWidget);
  });

  testWidgets('falls back to equivalent list for unsupported renderers', (
    tester,
  ) async {
    String? selectedNodeId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 260,
            child: DiskUsageMapView(
              projection: _projection,
              renderer: const _UnsupportedDiskUsageMapRenderer(),
              labels: _labels,
              style: _style,
              onTileSelected: (tile) {
                selectedNodeId = tile.nodeId;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Map data'), findsOneWidget);
    expect(find.text('Caches'), findsOneWidget);
    expect(find.text('Unsupported renderer'), findsOneWidget);

    await tester.tap(find.text('Caches'));
    expect(selectedNodeId, 'node-caches');
  });

  testWidgets('renders empty state without invoking renderer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 260,
            child: DiskUsageMapView(
              projection: _emptyProjection,
              renderer: const _ThrowingDiskUsageMapRenderer(),
              labels: _labels,
              style: _style,
            ),
          ),
        ),
      ),
    );

    expect(find.text('No map'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _labels = DiskUsageMapViewLabels(
  title: 'Disk map',
  description: 'Largest folders by size',
  emptyTitle: 'No map',
  emptyMessage: 'Run a scan first.',
  dataFallbackTitle: 'Map data',
  unsupportedRendererMessage: 'Unsupported renderer',
  renderFailureMessage: 'Renderer failed',
  otherLabel: 'Other',
);

const _style = DiskUsageMapStyle(
  backgroundColor: Color(0xFF0A1020),
  borderColor: Color(0xFF263148),
  textColor: Color(0xFFDCE6FF),
  mutedTextColor: Color(0xFF93A0BF),
  tileBorderColor: Color(0xFF263148),
  selectedTileBorderColor: Color(0xFF22E7F2),
  focusedTileBorderColor: Color(0xFF58A9FF),
  warningColor: Color(0xFFFACC15),
  protectedColor: Color(0xFF64748B),
  otherColor: Color(0xFF475569),
  palette: <Color>[Color(0xFF58A9FF), Color(0xFF8B5CF6), Color(0xFF22D3EE)],
);

const _projection = DiskUsageMapProjection(
  scanSnapshotId: 'snapshot-1',
  rootNodeId: 'root',
  projectionId: 'projection-1',
  kind: DiskUsageMapKind.treemap,
  sizeBasis: DiskUsageMapSizeBasis.logicalBytes,
  totalSizeBytesDecimal: '100000',
  freshness: DiskUsageMapFreshness.current,
  tiles: <DiskUsageMapTile>[
    DiskUsageMapTile(
      nodeId: 'node-caches',
      parentNodeId: 'root',
      label: 'Caches',
      displayPathHint: '/Users/me/Library/Caches',
      sizeBytesDecimal: '70 GB',
      percentOfRootBasisPoints: 7000,
      colorKey: 'cache',
      depth: 1,
      kind: DiskUsageMapTileKind.node,
      issueCount: 0,
      childCount: 12,
      hasMoreChildren: true,
    ),
    DiskUsageMapTile(
      nodeId: 'node-xcode',
      parentNodeId: 'root',
      label: 'Xcode',
      displayPathHint: '/Users/me/Library/Developer/Xcode',
      sizeBytesDecimal: '30 GB',
      percentOfRootBasisPoints: 3000,
      colorKey: 'developer',
      depth: 1,
      kind: DiskUsageMapTileKind.node,
      issueCount: 1,
      childCount: 4,
      hasMoreChildren: true,
    ),
  ],
);

const _emptyProjection = DiskUsageMapProjection(
  scanSnapshotId: 'snapshot-1',
  rootNodeId: 'root',
  projectionId: 'projection-empty',
  kind: DiskUsageMapKind.treemap,
  sizeBasis: DiskUsageMapSizeBasis.logicalBytes,
  totalSizeBytesDecimal: '0',
  freshness: DiskUsageMapFreshness.current,
  tiles: <DiskUsageMapTile>[],
);

final class _FakeDiskUsageMapRenderer implements DiskUsageMapRenderer {
  const _FakeDiskUsageMapRenderer();

  @override
  DiskUsageMapRendererCapabilities get capabilities =>
      const DiskUsageMapRendererCapabilities(
        rendererName: 'fake',
        trustLevel: DiskUsageMapRendererTrustLevel.testOnly,
        supportedKinds: <DiskUsageMapKind>{DiskUsageMapKind.treemap},
      );

  @override
  Widget build(BuildContext context, DiskUsageMapRenderContext renderContext) {
    return Center(
      child: Text('fake renderer: ${renderContext.projection.tiles.length}'),
    );
  }
}

final class _UnsupportedDiskUsageMapRenderer implements DiskUsageMapRenderer {
  const _UnsupportedDiskUsageMapRenderer();

  @override
  DiskUsageMapRendererCapabilities get capabilities =>
      const DiskUsageMapRendererCapabilities(
        rendererName: 'unsupported',
        trustLevel: DiskUsageMapRendererTrustLevel.testOnly,
        supportedKinds: <DiskUsageMapKind>{DiskUsageMapKind.donutBreakdown},
      );

  @override
  Widget build(BuildContext context, DiskUsageMapRenderContext renderContext) {
    return const SizedBox.shrink();
  }
}

final class _ThrowingDiskUsageMapRenderer implements DiskUsageMapRenderer {
  const _ThrowingDiskUsageMapRenderer();

  @override
  DiskUsageMapRendererCapabilities get capabilities =>
      const DiskUsageMapRendererCapabilities(
        rendererName: 'throwing',
        trustLevel: DiskUsageMapRendererTrustLevel.testOnly,
        supportedKinds: <DiskUsageMapKind>{DiskUsageMapKind.treemap},
      );

  @override
  Widget build(BuildContext context, DiskUsageMapRenderContext renderContext) {
    throw StateError('Renderer should not be called for empty projections.');
  }
}

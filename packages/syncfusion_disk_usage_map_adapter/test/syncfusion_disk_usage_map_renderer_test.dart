import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_disk_usage_map_adapter/syncfusion_disk_usage_map_adapter.dart';

void main() {
  test('declares Syncfusion as an experimental treemap adapter', () {
    const renderer = SyncfusionDiskUsageMapRenderer();

    expect(
      renderer.capabilities.supportsKind(DiskUsageMapKind.treemap),
      isTrue,
    );
    expect(
      renderer.capabilities.trustLevel,
      DiskUsageMapRendererTrustLevel.experimental,
    );
  });

  testWidgets('renders Syncfusion treemap and reports tile selection', (
    tester,
  ) async {
    String? selectedNodeId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 320,
            child: DiskUsageMapView(
              projection: _projection,
              renderer: const SyncfusionDiskUsageMapRenderer(),
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
    await tester.pump();

    expect(find.text('Caches'), findsOneWidget);
    expect(find.text('Xcode'), findsOneWidget);

    await tester.tap(find.text('Caches'));
    await tester.pump();

    expect(selectedNodeId, 'node-caches');
  });

  testWidgets('renders unbalanced hierarchical treemap without layout errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 320,
            child: DiskUsageMapView(
              projection: _unbalancedProjection,
              renderer: const SyncfusionDiskUsageMapRenderer(),
              labels: _labels,
              style: _style,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Downloads'), findsWidgets);
  });

  testWidgets('keeps narrow tile label and size visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 60,
            height: 44,
            child: DiskUsageMapView(
              projection: _singleTileProjection,
              renderer: const SyncfusionDiskUsageMapRenderer(),
              labels: _labels,
              style: _style,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Caches'), findsOneWidget);
    expect(find.text('70.0 KB'), findsOneWidget);
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
      sizeBytesDecimal: '70000',
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
      sizeBytesDecimal: '30000',
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

const _unbalancedProjection = DiskUsageMapProjection(
  scanSnapshotId: 'snapshot-2',
  rootNodeId: 'root',
  projectionId: 'projection-2',
  kind: DiskUsageMapKind.treemap,
  sizeBasis: DiskUsageMapSizeBasis.logicalBytes,
  totalSizeBytesDecimal: '100000',
  freshness: DiskUsageMapFreshness.current,
  tiles: <DiskUsageMapTile>[
    DiskUsageMapTile(
      nodeId: 'node-library',
      parentNodeId: 'root',
      label: 'Library',
      sizeBytesDecimal: '70000',
      percentOfRootBasisPoints: 7000,
      colorKey: 'library',
      depth: 1,
      kind: DiskUsageMapTileKind.node,
      issueCount: 0,
      childCount: 1,
      hasMoreChildren: true,
    ),
    DiskUsageMapTile(
      nodeId: 'node-caches',
      parentNodeId: 'node-library',
      label: 'Caches',
      sizeBytesDecimal: '30000',
      percentOfRootBasisPoints: 3000,
      colorKey: 'cache',
      depth: 2,
      kind: DiskUsageMapTileKind.node,
      issueCount: 0,
      childCount: 0,
      hasMoreChildren: false,
    ),
    DiskUsageMapTile(
      nodeId: 'node-downloads',
      parentNodeId: 'root',
      label: 'Downloads',
      sizeBytesDecimal: '20000',
      percentOfRootBasisPoints: 2000,
      colorKey: 'downloads',
      depth: 1,
      kind: DiskUsageMapTileKind.node,
      issueCount: 0,
      childCount: 0,
      hasMoreChildren: false,
    ),
  ],
);

const _singleTileProjection = DiskUsageMapProjection(
  scanSnapshotId: 'snapshot-3',
  rootNodeId: 'root',
  projectionId: 'projection-3',
  kind: DiskUsageMapKind.treemap,
  sizeBasis: DiskUsageMapSizeBasis.logicalBytes,
  totalSizeBytesDecimal: '70000',
  freshness: DiskUsageMapFreshness.current,
  tiles: <DiskUsageMapTile>[
    DiskUsageMapTile(
      nodeId: 'node-caches',
      parentNodeId: 'root',
      label: 'Caches',
      displayPathHint: '/Users/me/Library/Caches',
      sizeBytesDecimal: '70000',
      percentOfRootBasisPoints: 10000,
      colorKey: 'cache',
      depth: 1,
      kind: DiskUsageMapTileKind.node,
      issueCount: 0,
      childCount: 12,
      hasMoreChildren: true,
    ),
  ],
);

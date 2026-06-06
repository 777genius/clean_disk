import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/data/fixtures/fake_scan_fixture.dart';
import 'package:clean_disk_scan/src/di/scan_feature_composition.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';
import 'package:clean_disk_scan/src/presentation/stores/scan_workspace_store.dart';
import 'package:test/test.dart';

void main() {
  test(
    'composition creates a store that runs against fake scan ports',
    () async {
      final fixture = FakeScanFeatureFixture();
      final useCases = ScanUseCaseBundle.fromPorts(
        repository: fixture.repository,
        eventClient: fixture.eventClient,
      );
      final store = useCases.createWorkspaceStore();

      await store.connectEvents();
      await store.checkDaemonCompatibility();
      expect(store.daemonAvailability, ScanDaemonAvailability.ready);

      await store.start(
        StartScanCommand(
          commandId: CommandId('1'),
          targets: [
            ScanTarget(
              path: ScanTargetPath('/Users/belief'),
              scope: TargetScope.localPath,
              boundaryPolicy: BoundaryPolicy.stayOnInitialFilesystem,
              hardlinkPolicy: HardlinkPolicy.deduplicateForDisplay,
            ),
          ],
          measurement: MeasuredQuantity.apparentBytes,
          mode: ScanMode.balanced,
        ),
      );

      expect(store.sessionId, FakeScanRepository.sessionId);
      expect(store.activeSnapshotId, FakeScanRepository.snapshotId);
      expect(store.sessionStatus?.state, SessionState.completed);

      await store.loadChildren(
        parentId: FakeScanRepository.rootNodeId,
        limit: 2,
      );

      expect(store.visibleRows, hasLength(2));
      expect(store.visibleRows.first.name, 'Users');
      expect(store.viewport.nextCursor?.value, '2');

      await store.selectNode(FakeScanRepository.cachesNodeId);
      expect(store.selectedDetails?.summary.name, 'Caches');

      await store.dispose();
      await fixture.eventClient.close();
    },
  );

  test('fake repository rejects stale snapshot ids', () async {
    final fixture = FakeScanFeatureFixture();
    await fixture.repository.startScan(
      StartScanCommand(
        commandId: CommandId('1'),
        targets: const [],
        measurement: MeasuredQuantity.apparentBytes,
        mode: ScanMode.balanced,
      ),
    );

    final result = await fixture.repository.getChildrenPage(
      ChildrenPageQuery(
        sessionId: FakeScanRepository.sessionId,
        snapshotId: SnapshotId('101'),
        parentId: FakeScanRepository.rootNodeId,
        cursor: null,
        limit: 100,
        sort: ChildSort.sizeDesc,
      ),
    );

    expect(result.isFailure, isTrue);
    await fixture.eventClient.close();
  });

  test('fake fixture keeps parent ids and issue counts consistent', () async {
    final fixture = FakeScanFeatureFixture();
    await fixture.repository.startScan(
      StartScanCommand(
        commandId: CommandId('1'),
        targets: const [],
        measurement: MeasuredQuantity.apparentBytes,
        mode: ScanMode.balanced,
      ),
    );

    final rootResult = await fixture.repository.getChildrenPage(
      ChildrenPageQuery(
        sessionId: FakeScanRepository.sessionId,
        snapshotId: FakeScanRepository.snapshotId,
        parentId: FakeScanRepository.rootNodeId,
        cursor: null,
        limit: 10,
        sort: ChildSort.sizeDesc,
      ),
    );
    final homeResult = await fixture.repository.getChildrenPage(
      ChildrenPageQuery(
        sessionId: FakeScanRepository.sessionId,
        snapshotId: FakeScanRepository.snapshotId,
        parentId: FakeScanRepository.homeNodeId,
        cursor: null,
        limit: 10,
        sort: ChildSort.nameAsc,
      ),
    );

    final rootPage = switch (rootResult) {
      ResultSuccess(:final value) => value,
      ResultFailure(:final failure) => fail(failure.message),
    };
    final homePage = switch (homeResult) {
      ResultSuccess(:final value) => value,
      ResultFailure(:final failure) => fail(failure.message),
    };

    expect(rootPage.items.map((item) => item.parentId).toSet(), {
      FakeScanRepository.rootNodeId,
    });
    expect(
      rootPage.items.map((item) => item.name),
      isNot(contains('Downloads')),
    );
    expect(homePage.items.map((item) => item.parentId).toSet(), {
      FakeScanRepository.homeNodeId,
    });
    expect(homePage.items.map((item) => item.name), contains('Downloads'));
    expect(
      [
        ...rootPage.items,
        ...homePage.items,
      ].map((item) => item.subtreeIssueCount),
      everyElement(0),
    );

    await fixture.eventClient.close();
  });
}

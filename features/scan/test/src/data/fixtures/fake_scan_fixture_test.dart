import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:clean_disk_scan/clean_disk_scan_data.dart';
import 'package:test/test.dart';

void main() {
  test(
    'deferred start with emitted events returns the stored completed status',
    () async {
      final repository = FakeScanRepository()
        ..deferStartCompletion = true
        ..emitStartScanEvents = true;

      final startResult = await repository.startScan(_scanCommand());
      final started = _successValue(startResult);
      final storedResult = await repository.getSessionStatus(started.sessionId);
      final stored = _successValue(storedResult);

      expect(started.state, SessionState.completed);
      expect(started.snapshotId, isNotNull);
      expect(stored.state, started.state);
      expect(stored.snapshotId, started.snapshotId);
    },
  );

  test(
    'deferred start without emitted events keeps the stored status running',
    () async {
      final repository = FakeScanRepository()
        ..deferStartCompletion = true
        ..emitStartScanEvents = false;

      final startResult = await repository.startScan(_scanCommand());
      final started = _successValue(startResult);
      final storedResult = await repository.getSessionStatus(started.sessionId);
      final stored = _successValue(storedResult);

      expect(started.state, SessionState.running);
      expect(started.snapshotId, isNull);
      expect(stored.state, started.state);
      expect(stored.snapshotId, started.snapshotId);
    },
  );
}

T _successValue<T>(Result<T> result) {
  expect(result, isA<ResultSuccess<T>>());
  return (result as ResultSuccess<T>).value;
}

StartScanCommand _scanCommand() {
  return StartScanCommand(
    commandId: CommandId('1'),
    targets: [
      ScanTarget(
        path: ScanTargetPath('/'),
        scope: TargetScope.volume,
        boundaryPolicy: BoundaryPolicy.stayOnInitialFilesystem,
        hardlinkPolicy: HardlinkPolicy.deduplicateForDisplay,
      ),
    ],
    measurement: MeasuredQuantity.apparentBytes,
    mode: ScanMode.balanced,
  );
}

import 'package:clean_disk_scan/src/domain/scan_models.dart';
import 'package:test/test.dart';

void main() {
  group('decimal identifiers', () {
    test('preserve large protocol ids as strings and expose BigInt', () {
      final id = SnapshotId('340282366920938463463374607431768211455');

      expect(id.value, '340282366920938463463374607431768211455');
      expect(
        id.toBigInt(),
        BigInt.parse('340282366920938463463374607431768211455'),
      );
    });

    test('reject non-decimal values', () {
      expect(() => NodeId('12x'), throwsArgumentError);
      expect(() => ScanSessionId(''), throwsArgumentError);
    });
  });

  test('opaque cursors and paths reject blank values', () {
    expect(() => OpaqueCursor('  '), throwsArgumentError);
    expect(() => ScanTargetPath(''), throwsArgumentError);
  });

  test('session status exposes terminal and snapshot invariants', () {
    final running = ScanSessionStatus(
      sessionId: ScanSessionId('1'),
      state: SessionState.running,
      snapshotId: null,
      rootNodeIds: const [],
      progress: null,
    );
    final completed = ScanSessionStatus(
      sessionId: ScanSessionId('1'),
      state: SessionState.completed,
      snapshotId: SnapshotId('2'),
      rootNodeIds: [NodeId('1')],
      progress: null,
    );

    expect(running.isTerminal, isFalse);
    expect(running.hasPublishedSnapshot, isFalse);
    expect(completed.isTerminal, isTrue);
    expect(completed.hasPublishedSnapshot, isTrue);
  });
}

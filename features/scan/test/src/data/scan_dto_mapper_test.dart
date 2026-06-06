import 'package:clean_disk_scan/src/data/dto/scan_dto_mapper.dart';
import 'package:clean_disk_scan/src/data/dto/scan_protocol_dtos.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';
import 'package:test/test.dart';

void main() {
  test('maps start scan command into protocol request without raw routes', () {
    final dto = StartScanCommand(
      commandId: CommandId('99'),
      targets: [
        ScanTarget(
          path: ScanTargetPath('/Users/belief/Downloads'),
          scope: TargetScope.localPath,
          boundaryPolicy: BoundaryPolicy.stayOnInitialFilesystem,
          hardlinkPolicy: HardlinkPolicy.deduplicateForDisplay,
        ),
      ],
      measurement: MeasuredQuantity.allocatedBytes,
      mode: ScanMode.balanced,
    ).toDto();

    expect(dto.toJson(), {
      'protocolVersion': {'major': 0, 'minor': 5},
      'commandId': '99',
      'targets': [
        {
          'path': '/Users/belief/Downloads',
          'scope': 'local_path',
          'boundaryPolicy': 'stay_on_initial_filesystem',
          'hardlinkPolicy': 'deduplicate_for_display',
        },
      ],
      'measurement': 'allocated_bytes',
      'mode': 'balanced',
    });
  });

  test('maps permission probe request to current protocol target DTO', () {
    final dto = ScanTarget(
      path: ScanTargetPath('/tmp/clean-disk-fixture'),
      scope: TargetScope.localPath,
      boundaryPolicy: BoundaryPolicy.crossFilesystems,
      hardlinkPolicy: HardlinkPolicy.ignore,
    ).toPermissionProbeRequestDto();

    expect(dto.toJson(), {
      'protocolVersion': {'major': 0, 'minor': 5},
      'target': {
        'path': '/tmp/clean-disk-fixture',
        'scope': 'local_path',
        'boundaryPolicy': 'cross_filesystems',
        'hardlinkPolicy': 'ignore',
      },
    });
  });

  test('maps permission probe remediation action into domain', () {
    final dto = PermissionProbeDto.fromJson({
      'status': 'denied',
      'checkedAtUnixMs': '1700000000000',
      'requiredAction': 'open_macos_full_disk_access',
    });

    final domain = dto.toDomain();

    expect(domain.status, PermissionProbeStatus.denied);
    expect(domain.checkedAtUnixMs, BigInt.from(1700000000000));
    expect(
      domain.requiredAction,
      PermissionRequiredAction.openMacosFullDiskAccess,
    );
  });

  test('maps capability runtime proof without trusting unknown access', () {
    final dto = CapabilityResponseDto.fromJson({
      'protocolVersion': {'major': 0, 'minor': 5},
      'scanner': {
        'backendName': 'pdu',
        'capabilities': {
          'hardlinks': 'unsupported',
          'filesystemBoundary': 'supported',
          'cooperativeCancellation': 'unsupported',
          'metadataEnrichment': 'unsupported',
        },
      },
      'limits': {'maxPageSize': '500', 'maxEventQueueItems': '1024'},
      'runtimeProof': {
        'scannerIdentity': {
          'platform': 'macos',
          'processKind': 'current_process',
          'verification': 'unverified',
          'executablePath':
              '/Applications/Clean Disk.app/Contents/MacOS/Clean Disk',
          'bundleIdentifier': null,
        },
        'permissionProbe': {
          'status': 'not_probed',
          'checkedAtUnixMs': null,
          'requiredAction': 'none',
        },
        'packaging': {
          'distributionChannel': 'development',
          'packageMode': 'development_shell',
          'sandboxed': false,
          'signedBuild': false,
          'debugBuild': true,
          'scannerProcess': 'current_process',
          'limitations': ['unsigned_build', 'development_shell'],
          'updateSafety': {
            'quiesceRequiredBeforeUpdate': true,
            'rollbackSupported': 'unknown',
            'receiptPreservation': 'supported',
          },
        },
      },
    });

    final domain = dto.toDomain();

    expect(domain.protocolVersion, ProtocolVersion.current);
    expect(
      domain.runtimeProof.scannerIdentity.verification,
      ScannerIdentityVerification.unverified,
    );
    expect(
      domain.runtimeProof.permissionProbe.status,
      PermissionProbeStatus.notProbed,
    );
    expect(
      domain.runtimeProof.packaging.packageMode,
      PackageMode.developmentShell,
    );
    expect(domain.runtimeProof.packaging.signedBuild, isFalse);
    expect(
      domain.runtimeProof.packaging.updateSafety.quiesceRequiredBeforeUpdate,
      isTrue,
    );
  });

  test(
    'maps node page response into domain without losing decimal strings',
    () {
      final dto = NodePageResponseDto.fromJson({
        'snapshotId': '340282366920938463463374607431768211455',
        'items': [
          {
            'nodeId': '18446744073709551615',
            'parentId': '1',
            'name': 'Caches',
            'kind': 'directory',
            'size': {
              'rawValue': '38654705664',
              'quantity': 'allocated_bytes',
              'byteEquivalent': '38654705664',
              'confidence': 'high',
            },
            'flags': {
              'hidden': false,
              'system': false,
              'package': false,
              'symlink': false,
            },
            'childCompleteness': 'complete',
            'childCount': '24',
            'issueCount': '1',
            'subtreeIssueCount': '3',
          },
        ],
        'nextCursor': 'cursor-1',
      });

      final domain = dto.toDomain();

      expect(
        domain.snapshotId.value,
        '340282366920938463463374607431768211455',
      );
      expect(domain.items.single.nodeId.value, '18446744073709551615');
      expect(domain.items.single.kind, NodeKind.directory);
      expect(domain.items.single.size.rawBigInt, BigInt.parse('38654705664'));
      expect(domain.items.single.childCount, 24);
      expect(domain.nextCursor?.value, 'cursor-1');
    },
  );

  test('maps node details timestamps into domain metadata', () {
    final dto = NodeDetailsResponseDto.fromJson({
      'snapshotId': '7',
      'summary': {
        'nodeId': '2',
        'parentId': '1',
        'name': 'Library',
        'kind': 'directory',
        'size': {
          'rawValue': '1024',
          'quantity': 'apparent_bytes',
          'byteEquivalent': '1024',
          'confidence': 'exact',
        },
        'flags': {
          'hidden': false,
          'system': false,
          'package': false,
          'symlink': false,
        },
        'childCompleteness': 'complete',
        'childCount': '3',
        'issueCount': '0',
        'subtreeIssueCount': '0',
      },
      'timestamps': {
        'createdAtUnixMs': '1704103200000',
        'modifiedAtUnixMs': '1704195900000',
      },
      'childIds': ['3', '4', '5'],
      'issues': [],
    });

    final domain = dto.toDomain();

    expect(domain.timestamps?.createdAtUnixMs, BigInt.from(1704103200000));
    expect(domain.timestamps?.modifiedAtUnixMs, BigInt.from(1704195900000));
    expect(domain.childIds.map((id) => id.value), ['3', '4', '5']);
  });

  test('maps event envelopes into typed scan events', () {
    final dto = ScanEventEnvelopeDto.fromJson({
      'protocolVersion': {'major': 0, 'minor': 1},
      'sequence': '7',
      'emittedAtUnixMs': '1710000000000',
      'event': {
        'type': 'snapshot_published',
        'sessionId': '11',
        'snapshotId': '22',
      },
    });

    final envelope = dto.toDomain();

    expect(envelope.sequence.value, '7');
    expect(envelope.event, isA<ScanSnapshotPublished>());
    final event = envelope.event as ScanSnapshotPublished;
    expect(event.sessionId?.value, '11');
    expect(event.snapshotId.value, '22');
  });

  test('maps session status root ids as opaque node ids', () {
    final dto = ScanSessionStatusDto.fromJson({
      'sessionId': '42',
      'state': 'completed',
      'snapshotId': '340282366920938463463374607431768211455',
      'rootNodeIds': ['1', '18446744073709551615'],
      'progress': null,
    });

    final domain = dto.toDomain();

    expect(domain.rootNodeIds.map((id) => id.value), [
      '1',
      '18446744073709551615',
    ]);
  });
}

import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:clean_disk_scan/src/data/dto/scan_protocol_dtos.dart';
import 'package:clean_disk_scan/src/data/sources/clean_disk_api_client.dart';
import 'package:test/test.dart';

void main() {
  test(
    'sends bearer token and command body through abstract http client',
    () async {
      final httpClient = _RecordingHttpClient((request) {
        expect(request.path, '/v1/scans');
        expect(request.headers?['authorization'], 'Bearer local-token');
        final body = request.body as JsonBody?;
        expect(body?.data['commandId'], '77');
        return {
          'sessionId': '1',
          'state': 'running',
          'snapshotId': null,
          'rootNodeIds': <Object?>[],
          'progress': null,
        };
      });
      final client = CleanDiskApiClient(
        httpClient: httpClient,
        localAuthToken: 'local-token',
      );

      final status = await client.startScan(
        StartScanRequestDto(
          protocolVersion: ProtocolVersionDto.current,
          commandId: '77',
          targets: const [],
          measurement: 'apparent_bytes',
          mode: 'balanced',
        ),
      );

      expect(status.sessionId, '1');
      expect(httpClient.requests.single.method, HttpMethod.post);
    },
  );

  test('uses paginated query route only inside data source', () async {
    final httpClient = _RecordingHttpClient((request) {
      expect(request.path, '/v1/scans/1/children');
      final body = request.body as JsonBody?;
      expect(body?.data['snapshotId'], '2');
      expect(body?.data['limit'], '50');
      return {'snapshotId': '2', 'items': <Object?>[], 'nextCursor': null};
    });
    final client = CleanDiskApiClient(httpClient: httpClient);

    final page = await client.getChildrenPage(
      '1',
      const ChildrenPageRequestDto(
        snapshotId: '2',
        parentId: '3',
        cursor: null,
        limit: '50',
        sort: 'size_desc',
      ),
    );

    expect(page.snapshotId, '2');
    expect(page.items, isEmpty);
  });

  test('posts permission probe under current protocol version', () async {
    final httpClient = _RecordingHttpClient((request) {
      expect(request.path, '/v1/permission-probe');
      expect(request.method, HttpMethod.post);
      final body = request.body as JsonBody?;
      expect(body?.data['protocolVersion'], {'major': 0, 'minor': 4});
      expect(body?.data['target'], {
        'path': '/tmp/clean-disk-fixture',
        'scope': 'local_path',
        'boundaryPolicy': 'cross_filesystems',
        'hardlinkPolicy': 'ignore',
      });
      return {
        'status': 'verified',
        'checkedAtUnixMs': '1700000000000',
        'requiredAction': 'none',
      };
    });
    final client = CleanDiskApiClient(httpClient: httpClient);

    final probe = await client.probePermission(
      const PermissionProbeRequestDto(
        protocolVersion: ProtocolVersionDto.current,
        target: ScanTargetDto(
          path: '/tmp/clean-disk-fixture',
          scope: 'local_path',
          boundaryPolicy: 'cross_filesystems',
          hardlinkPolicy: 'ignore',
        ),
      ),
    );

    expect(probe.status, 'verified');
    expect(probe.checkedAtUnixMs, '1700000000000');
  });

  test('creates cleanup plan and executes it by plan id', () async {
    var step = 0;
    final httpClient = _RecordingHttpClient((request) {
      step += 1;
      final body = request.body as JsonBody?;
      if (step == 1) {
        expect(request.path, '/v1/cleanup/plans');
        expect(body?.data['commandId'], '9');
        expect(body?.data['items'], hasLength(1));
        return {
          'protocolVersion': {'major': 0, 'minor': 4},
          'planId': '55',
          'commandId': '9',
          'state': 'ready',
          'createdAtUnixMs': '1700000000000',
          'items': <Object?>[],
        };
      }

      expect(request.path, '/v1/cleanup/plans/55/execute');
      expect(body?.data['commandId'], '10');
      expect(body?.data['planId'], '55');
      return {
        'operationId': '10',
        'commandId': '10',
        'state': 'completed',
        'startedAtUnixMs': '1700000000000',
        'updatedAtUnixMs': '1700000000001',
        'lowDiskReserveReady': true,
        'items': <Object?>[],
      };
    });
    final client = CleanDiskApiClient(httpClient: httpClient);

    final plan = await client.createCleanupPlan(
      const CreateCleanupPlanRequestDto(
        protocolVersion: ProtocolVersionDto.current,
        commandId: '9',
        items: [
          CleanupPlanItemRefDto(sessionId: '1', snapshotId: '2', nodeId: '3'),
        ],
      ),
    );
    final receipt = await client.executeCleanupPlan(
      ExecuteCleanupPlanRequestDto(
        protocolVersion: ProtocolVersionDto.current,
        commandId: '10',
        planId: plan.planId,
      ),
    );

    expect(plan.planId, '55');
    expect(receipt.state, 'completed');
    expect(httpClient.requests, hasLength(2));
  });
}

final class _RecordingHttpClient extends HttpClient {
  _RecordingHttpClient(this._handler);

  final Object? Function(HttpRequest request) _handler;
  final List<HttpRequest> requests = [];

  @override
  HttpClientConfig get config => const HttpClientConfig();

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<HttpResponse<T>> send<T>(
    HttpRequest request, {
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
  }) async {
    requests.add(request);
    final rawData = _handler(request);
    final data = decoder == null ? rawData as T? : decoder(rawData);
    return HttpResponse<T>(statusCode: 200, request: request, data: data);
  }
}

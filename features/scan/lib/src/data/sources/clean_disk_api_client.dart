import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:clean_disk_scan/src/data/dto/scan_protocol_dtos.dart';

final class CleanDiskApiClient {
  const CleanDiskApiClient({
    required HttpClient httpClient,
    String? localAuthToken,
  }) : _httpClient = httpClient,
       _localAuthToken = localAuthToken;

  final HttpClient _httpClient;
  final String? _localAuthToken;

  Future<CapabilityResponseDto> getCapabilities() {
    return _getDto('/v1/capabilities', CapabilityResponseDto.fromJson);
  }

  Future<DaemonDiagnosticsDto> getDiagnostics() {
    return _getDto('/v1/diagnostics', DaemonDiagnosticsDto.fromJson);
  }

  Future<PermissionProbeDto> probePermission(
    PermissionProbeRequestDto request,
  ) {
    return _postDto(
      '/v1/permission-probe',
      request.toJson(),
      PermissionProbeDto.fromJson,
    );
  }

  Future<ScanSessionStatusDto> startScan(StartScanRequestDto request) {
    return _postDto(
      '/v1/scans',
      request.toJson(),
      ScanSessionStatusDto.fromJson,
    );
  }

  Future<ScanSessionStatusDto> getScanStatus(String sessionId) {
    return _getDto(
      '/v1/scans/${Uri.encodeComponent(sessionId)}',
      ScanSessionStatusDto.fromJson,
    );
  }

  Future<ScanSessionStatusDto> cancelScan(SessionCommandRequestDto request) {
    return _postDto(
      '/v1/scans/${Uri.encodeComponent(request.sessionId)}/cancel',
      request.toJson(),
      ScanSessionStatusDto.fromJson,
    );
  }

  Future<void> disposeScan(SessionCommandRequestDto request) async {
    await _httpClient.post<void>(
      '/v1/scans/${Uri.encodeComponent(request.sessionId)}/dispose',
      body: HttpBody.json(request.toJson()),
      headers: _headers,
    );
  }

  Future<NodePageResponseDto> getChildrenPage(
    String sessionId,
    ChildrenPageRequestDto request,
  ) {
    return _postDto(
      '/v1/scans/${Uri.encodeComponent(sessionId)}/children',
      request.toJson(),
      NodePageResponseDto.fromJson,
    );
  }

  Future<NodePageResponseDto> search(
    String sessionId,
    SearchPageRequestDto request,
  ) {
    return _postDto(
      '/v1/scans/${Uri.encodeComponent(sessionId)}/search',
      request.toJson(),
      NodePageResponseDto.fromJson,
    );
  }

  Future<NodePageResponseDto> getTopItems(
    String sessionId,
    TopItemsRequestDto request,
  ) {
    return _postDto(
      '/v1/scans/${Uri.encodeComponent(sessionId)}/top',
      request.toJson(),
      NodePageResponseDto.fromJson,
    );
  }

  Future<NodeDetailsResponseDto> getNodeDetails(
    String sessionId,
    NodeDetailsRequestDto request,
  ) {
    return _postDto(
      '/v1/scans/${Uri.encodeComponent(sessionId)}/details',
      request.toJson(),
      NodeDetailsResponseDto.fromJson,
    );
  }

  Future<CleanupPlanDto> createCleanupPlan(
    CreateCleanupPlanRequestDto request,
  ) {
    return _postDto(
      '/v1/cleanup/plans',
      request.toJson(),
      CleanupPlanDto.fromJson,
    );
  }

  Future<CleanupReceiptDto> executeCleanupPlan(
    ExecuteCleanupPlanRequestDto request,
  ) {
    return _postDto(
      '/v1/cleanup/plans/${Uri.encodeComponent(request.planId)}/execute',
      request.toJson(),
      CleanupReceiptDto.fromJson,
    );
  }

  Future<CleanupRecoveryInboxDto> getCleanupRecoveryInbox() {
    return _getDto(
      '/v1/cleanup/recovery-inbox',
      CleanupRecoveryInboxDto.fromJson,
    );
  }

  Future<T> _getDto<T extends Object>(
    String path,
    T Function(Map<String, Object?> json) fromJson,
  ) async {
    final response = await _httpClient.get<T>(
      path,
      headers: _headers,
      decoder: (data) => fromJson(parseJsonObject(data)),
    );
    return _requireData(response);
  }

  Future<T> _postDto<T extends Object>(
    String path,
    Map<String, Object?> body,
    T Function(Map<String, Object?> json) fromJson,
  ) async {
    final response = await _httpClient.post<T>(
      path,
      body: HttpBody.json(body),
      headers: _headers,
      decoder: (data) => fromJson(parseJsonObject(data)),
    );
    return _requireData(response);
  }

  T _requireData<T extends Object>(HttpResponse<T> response) {
    final data = response.data;
    if (data == null) {
      throw const FormatException('Expected response body');
    }
    return data;
  }

  Map<String, String>? get _headers {
    final token = _localAuthToken;
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return {'authorization': 'Bearer $token'};
  }
}

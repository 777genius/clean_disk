import 'dart:async';
import 'dart:io';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:clean_disk_network/clean_disk_network.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:clean_disk_scan/clean_disk_scan_data.dart';

import 'deferred_http_client.dart';
import 'path_revealer.dart';
import 'permission_repair_launcher.dart';
import 'scan_target_catalog.dart';
import 'scan_target_picker.dart';
import 'scan_target_preferences.dart';

const _daemonBaseUrl = String.fromEnvironment(
  'CLEAN_DISK_DAEMON_BASE_URL',
  defaultValue: 'http://127.0.0.1:17631',
);
const _localAuthToken = String.fromEnvironment(
  'CLEAN_DISK_LOCAL_AUTH_TOKEN',
  defaultValue: '',
);

ScanModule createDaemonScanModule(
  ScanWorkspaceConfig config, {
  DiskUsageMapRenderer? diskUsageMapRenderer,
}) {
  final environment = AppEnvironment.fromValues(
    flavor: 'development',
    apiBaseUrl: _daemonBaseUrl,
  );
  final factory = AppHttpClientFactory(
    environment: environment,
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 5),
  );
  final httpClient = DeferredHttpClient(
    config: factory.createConfig(),
    client: factory.createInitialized(),
  );
  final authToken = _normalizedAuthToken();
  final repository = DaemonScanRepository(
    apiClient: CleanDiskApiClient(
      httpClient: httpClient,
      localAuthToken: authToken,
    ),
  );
  final eventClient = ScanEventStreamClient(
    connect: () => _watchDaemonEvents(
      baseUri: environment.apiBaseUri,
      localAuthToken: authToken,
    ),
    reconnectDelays: const [
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  );

  return ScanModule(
    config: config,
    diskUsageMapRenderer: diskUsageMapRenderer,
    useCases: ScanUseCaseBundle.fromPorts(
      repository: repository,
      eventClient: eventClient,
      permissionRepairLauncher: createPermissionRepairLauncher(),
      targetPicker: createScanTargetPicker(),
      targetCatalog: createScanTargetCatalog(),
      targetPreferenceStore: createScanTargetPreferenceStore(),
      pathRevealer: createPathRevealer(),
    ),
  );
}

Stream<Object?> _watchDaemonEvents({
  required Uri baseUri,
  required String? localAuthToken,
}) async* {
  final socket = await WebSocket.connect(
    _eventsUri(baseUri).toString(),
    headers: _eventHeaders(localAuthToken),
    protocols: const ['clean-disk-events-v1'],
  );
  try {
    await for (final event in socket) {
      yield event;
    }
  } finally {
    await socket.close();
  }
}

Uri _eventsUri(Uri baseUri) {
  return baseUri.replace(
    scheme: switch (baseUri.scheme) {
      'https' => 'wss',
      _ => 'ws',
    },
    path: '/v1/events',
    query: '',
    fragment: '',
  );
}

Map<String, String>? _eventHeaders(String? localAuthToken) {
  if (localAuthToken == null) {
    return null;
  }
  return {'authorization': 'Bearer $localAuthToken'};
}

String? _normalizedAuthToken() {
  final token =
      (_localAuthToken.trim().isNotEmpty
              ? _localAuthToken
              : Platform.environment['CLEAN_DISK_LOCAL_AUTH_TOKEN'] ?? '')
          .trim();
  return token.isEmpty ? null : token;
}

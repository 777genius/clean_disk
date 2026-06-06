import 'dart:async';
import 'dart:js_interop';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_network/clean_disk_network.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:clean_disk_scan/clean_disk_scan_data.dart';
import 'package:web/web.dart' as web;

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
const _eventsWebSocketSubprotocol = 'clean-disk-events-v1';
const _eventsWebSocketTokenPrefix = 'clean-disk-token.';

ScanModule createDaemonScanModule(ScanWorkspaceConfig config) {
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
}) {
  late StreamController<Object?> controller;
  web.WebSocket? socket;

  controller = StreamController<Object?>(
    onListen: () {
      socket = web.WebSocket(
        _eventsUri(baseUri).toString(),
        _eventProtocols(localAuthToken).jsify()!,
      );
      socket!.onmessage = ((web.Event event) {
        final message = event as web.MessageEvent;
        controller.add(message.data.dartify());
      }).toJS;
      socket!.onerror = ((web.Event _) {
        controller.addError(StateError('Scan event stream disconnected'));
      }).toJS;
      socket!.onclose = ((web.Event _) {
        controller.addError(StateError('Scan event stream disconnected'));
        unawaited(controller.close());
      }).toJS;
    },
    onCancel: () {
      final activeSocket = socket;
      if (activeSocket != null) {
        activeSocket.onmessage = null;
        activeSocket.onerror = null;
        activeSocket.onclose = null;
        activeSocket.close();
      }
      socket = null;
    },
  );

  return controller.stream;
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

List<String> _eventProtocols(String? localAuthToken) {
  final token = localAuthToken?.trim();
  if (token == null || token.isEmpty) {
    return const [_eventsWebSocketSubprotocol];
  }
  return [_eventsWebSocketSubprotocol, '$_eventsWebSocketTokenPrefix$token'];
}

String? _normalizedAuthToken() {
  final token = _localAuthToken.trim();
  return token.isEmpty ? null : token;
}

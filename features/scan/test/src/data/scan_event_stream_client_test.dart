import 'dart:async';
import 'dart:convert';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/data/sources/scan_event_stream_client.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';
import 'package:test/test.dart';

void main() {
  test('maps raw websocket JSON events into application results', () async {
    final client = ScanEventStreamClient(
      rawEvents: Stream<Object?>.fromIterable([
        jsonEncode({
          'protocolVersion': {'major': 0, 'minor': 1},
          'sequence': '1',
          'emittedAtUnixMs': '1710000000000',
          'event': {
            'type': 'progress',
            'sessionId': '42',
            'progress': {
              'scannedItems': '123',
              'elapsedMs': '500',
              'throughputBytesPerSec': '1000',
            },
          },
        }),
      ]),
    );

    final events = await client.watchEvents().toList();

    expect(events, hasLength(1));
    final success = events.single as ResultSuccess<ScanEventEnvelope>;
    expect(success.value.event, isA<ScanProgressed>());
    final event = success.value.event as ScanProgressed;
    expect(event.sessionId?.value, '42');
    expect(event.progress.scannedItems, BigInt.from(123));
  });

  test('turns invalid event payloads into failures', () async {
    final controller = StreamController<Object?>();
    final client = ScanEventStreamClient(rawEvents: controller.stream);
    final eventsFuture = client.watchEvents().toList();

    controller
      ..add({'bad': 'payload'})
      ..addError(StateError('socket closed'));
    await controller.close();

    final events = await eventsFuture;

    expect(events, hasLength(2));
    expect(events.first, isA<ResultFailure<ScanEventEnvelope>>());
    expect(events.last, isA<ResultFailure<ScanEventEnvelope>>());
  });
}

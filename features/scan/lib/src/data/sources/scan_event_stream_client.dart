import 'dart:convert';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_event_client.dart';
import 'package:clean_disk_scan/src/data/dto/scan_dto_mapper.dart';
import 'package:clean_disk_scan/src/data/dto/scan_protocol_dtos.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class ScanEventStreamClient implements ScanEventClient {
  const ScanEventStreamClient({
    Stream<Object?>? rawEvents,
    Stream<Object?> Function()? connect,
    List<Duration> reconnectDelays = const [],
  }) : assert(
         rawEvents != null || connect != null,
         'rawEvents or connect must be provided',
       ),
       _rawEvents = rawEvents,
       _connect = connect,
       _reconnectDelays = reconnectDelays;

  final Stream<Object?>? _rawEvents;
  final Stream<Object?> Function()? _connect;
  final List<Duration> _reconnectDelays;

  @override
  Stream<Result<ScanEventEnvelope>> watchEvents() async* {
    var reconnectAttempt = 0;
    while (true) {
      try {
        await for (final rawEvent in _openEvents()) {
          reconnectAttempt = 0;
          final result = _decodeEvent(rawEvent);
          yield result;
        }
        if (!_canReconnect(reconnectAttempt)) {
          return;
        }
      } on Object catch (_) {
        if (!_canReconnect(reconnectAttempt)) {
          yield Result.failure(
            AppFailure.network(message: 'Scan event stream disconnected'),
          );
          return;
        }
      }

      final delay = _reconnectDelays[reconnectAttempt];
      reconnectAttempt += 1;
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
  }

  Stream<Object?> _openEvents() {
    final connect = _connect;
    if (connect != null) {
      return connect();
    }
    return _rawEvents!;
  }

  bool _canReconnect(int reconnectAttempt) {
    return reconnectAttempt < _reconnectDelays.length;
  }

  Result<ScanEventEnvelope> _decodeEvent(Object? rawEvent) {
    try {
      final json = _decodeEventObject(rawEvent);
      final dto = ScanEventEnvelopeDto.fromJson(json);
      return Result.success(dto.toDomain());
    } on Object catch (error) {
      return Result.failure(
        AppFailure.unexpected(
          message: 'Invalid scan event payload',
          cause: error,
        ),
      );
    }
  }

  Map<String, Object?> _decodeEventObject(Object? rawEvent) {
    if (rawEvent is String) {
      return parseJsonObject(jsonDecode(rawEvent));
    }
    return parseJsonObject(rawEvent);
  }
}

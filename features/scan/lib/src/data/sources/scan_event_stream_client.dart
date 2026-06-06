import 'dart:convert';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_event_client.dart';
import 'package:clean_disk_scan/src/data/dto/scan_dto_mapper.dart';
import 'package:clean_disk_scan/src/data/dto/scan_protocol_dtos.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class ScanEventStreamClient implements ScanEventClient {
  const ScanEventStreamClient({required Stream<Object?> rawEvents})
    : _rawEvents = rawEvents;

  final Stream<Object?> _rawEvents;

  @override
  Stream<Result<ScanEventEnvelope>> watchEvents() async* {
    try {
      await for (final rawEvent in _rawEvents) {
        try {
          final json = _decodeEventObject(rawEvent);
          final dto = ScanEventEnvelopeDto.fromJson(json);
          yield Result.success(dto.toDomain());
        } on Object catch (error) {
          yield Result.failure(
            AppFailure.unexpected(
              message: 'Invalid scan event payload',
              cause: error,
            ),
          );
        }
      }
    } on Object catch (_) {
      yield Result.failure(
        AppFailure.network(message: 'Scan event stream disconnected'),
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

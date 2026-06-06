import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_event_client.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class WatchScanEventsUseCase {
  const WatchScanEventsUseCase(this._client);

  final ScanEventClient _client;

  Stream<Result<ScanEventEnvelope>> call() {
    return _client.watchEvents();
  }
}

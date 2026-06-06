import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

enum ScanTargetChoiceKind { home, downloads, root, volume }

final class ScanTargetChoice {
  const ScanTargetChoice({
    required this.id,
    required this.kind,
    required this.target,
    required this.displayName,
  });

  final String id;
  final ScanTargetChoiceKind kind;
  final ScanTarget target;
  final String displayName;
}

abstract interface class ScanTargetCatalog {
  Future<Result<List<ScanTargetChoice>>> listChoices();
}

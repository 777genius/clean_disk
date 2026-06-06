import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_picker.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class PickScanTargetRequest {
  const PickScanTargetRequest({required this.currentTarget});

  final ScanTarget currentTarget;
}

final class PickScanTargetUseCase
    implements UseCase<Result<ScanTarget?>, PickScanTargetRequest> {
  const PickScanTargetUseCase(this._picker);

  final ScanTargetPicker _picker;

  @override
  Future<Result<ScanTarget?>> call(PickScanTargetRequest input) async {
    final result = await _picker.pickDirectory(
      initialPath: input.currentTarget.path,
    );
    return switch (result) {
      ResultSuccess(:final value) => Result.success(
        value == null
            ? null
            : ScanTarget(
                path: value,
                scope: TargetScope.localPath,
                boundaryPolicy: input.currentTarget.boundaryPolicy,
                hardlinkPolicy: input.currentTarget.hardlinkPolicy,
              ),
      ),
      ResultFailure(:final failure) => Result.failure(failure),
    };
  }
}

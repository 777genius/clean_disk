import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/data/dto/scan_dto_mapper.dart';
import 'package:clean_disk_scan/src/data/sources/clean_disk_api_client.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class DaemonScanRepository implements ScanRepository {
  const DaemonScanRepository({required CleanDiskApiClient apiClient})
    : _apiClient = apiClient;

  final CleanDiskApiClient _apiClient;

  @override
  Future<Result<DaemonCapabilities>> getCapabilities() {
    return _guard(() async {
      final dto = await _apiClient.getCapabilities();
      return dto.toDomain();
    });
  }

  @override
  Future<Result<DaemonDiagnostics>> getDiagnostics() {
    return _guard(() async {
      final dto = await _apiClient.getDiagnostics();
      return dto.toDomain();
    });
  }

  @override
  Future<Result<PermissionProbe>> probePermission(ScanTarget target) {
    return _guard(() async {
      final dto = await _apiClient.probePermission(
        target.toPermissionProbeRequestDto(),
      );
      return dto.toDomain();
    });
  }

  @override
  Future<Result<ScanSessionStatus>> startScan(StartScanCommand command) {
    return _guard(() async {
      final dto = await _apiClient.startScan(command.toDto());
      return dto.toDomain();
    });
  }

  @override
  Future<Result<ScanSessionStatus>> getSessionStatus(ScanSessionId sessionId) {
    return _guard(() async {
      final dto = await _apiClient.getScanStatus(sessionId.value);
      return dto.toDomain();
    });
  }

  @override
  Future<Result<ScanSessionStatus>> cancelScan(SessionCommand command) {
    return _guard(() async {
      final dto = await _apiClient.cancelScan(command.toDto());
      return dto.toDomain();
    });
  }

  @override
  Future<Result<Unit>> disposeScan(SessionCommand command) {
    return _guard(() async {
      await _apiClient.disposeScan(command.toDto());
      return Unit.value;
    });
  }

  @override
  Future<Result<NodePage>> getChildrenPage(ChildrenPageQuery query) {
    return _guard(() async {
      final dto = await _apiClient.getChildrenPage(
        query.sessionId.value,
        query.toDto(),
      );
      return dto.toDomain();
    });
  }

  @override
  Future<Result<NodePage>> search(SearchPageQuery query) {
    return _guard(() async {
      final dto = await _apiClient.search(query.sessionId.value, query.toDto());
      return dto.toDomain();
    });
  }

  @override
  Future<Result<NodePage>> getTopItems(TopItemsQuery query) {
    return _guard(() async {
      final dto = await _apiClient.getTopItems(
        query.sessionId.value,
        query.toDto(),
      );
      return dto.toDomain();
    });
  }

  @override
  Future<Result<NodeDetails>> getNodeDetails(NodeDetailsQuery query) {
    return _guard(() async {
      final dto = await _apiClient.getNodeDetails(
        query.sessionId.value,
        query.toDto(),
      );
      return dto.toDomain();
    });
  }

  @override
  Future<Result<ValidatedCleanupPlan>> createCleanupPlan(
    CreateCleanupPlanCommand command,
  ) {
    return _guard(() async {
      final dto = await _apiClient.createCleanupPlan(command.toDto());
      return dto.toDomain();
    });
  }

  @override
  Future<Result<CleanupReceipt>> executeCleanupPlan(
    ExecuteCleanupPlanCommand command,
  ) {
    return _guard(() async {
      final dto = await _apiClient.executeCleanupPlan(command.toDto());
      return dto.toDomain();
    });
  }

  @override
  Future<Result<CleanupReceipt>> executeCleanup(ExecuteCleanupCommand command) {
    return _guard(() async {
      final plan = await _apiClient.createCleanupPlan(
        command.toCreateCleanupPlanDto(),
      );
      final dto = await _apiClient.executeCleanupPlan(
        command.toExecuteCleanupPlanDto(plan.planId),
      );
      return dto.toDomain();
    });
  }

  @override
  Future<Result<CleanupRecoveryInbox>> getCleanupRecoveryInbox() {
    return _guard(() async {
      final dto = await _apiClient.getCleanupRecoveryInbox();
      return dto.toDomain();
    });
  }

  Future<Result<T>> _guard<T extends Object>(
    Future<T> Function() action,
  ) async {
    try {
      return Result.success(await action());
    } on HttpError catch (error) {
      return Result.failure(_mapHttpError(error));
    } on FormatException catch (error) {
      return Result.failure(
        AppFailure.unexpected(message: 'Invalid daemon response', cause: error),
      );
    } on ArgumentError catch (error) {
      return Result.failure(
        AppFailure.unexpected(message: 'Invalid daemon response', cause: error),
      );
    } on Object catch (error) {
      return Result.failure(
        AppFailure.unexpected(
          message: 'Scan daemon request failed',
          cause: error,
        ),
      );
    }
  }

  AppFailure _mapHttpError(HttpError error) {
    if (error.type == HttpErrorType.unauthorized ||
        error.type == HttpErrorType.forbidden) {
      return AppFailure.unauthorized(message: 'Scan daemon auth failed');
    }

    return AppFailure.network(
      message: error.message ?? 'Scan daemon request failed',
      statusCode: error.statusCode,
    );
  }
}

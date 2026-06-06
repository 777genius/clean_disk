import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

abstract interface class ScanRepository {
  Future<Result<DaemonCapabilities>> getCapabilities();

  Future<Result<DaemonDiagnostics>> getDiagnostics();

  Future<Result<PermissionProbe>> probePermission(ScanTarget target);

  Future<Result<ScanSessionStatus>> startScan(StartScanCommand command);

  Future<Result<ScanSessionStatus>> getSessionStatus(ScanSessionId sessionId);

  Future<Result<ScanSessionStatus>> cancelScan(SessionCommand command);

  Future<Result<Unit>> disposeScan(SessionCommand command);

  Future<Result<NodePage>> getChildrenPage(ChildrenPageQuery query);

  Future<Result<NodePage>> search(SearchPageQuery query);

  Future<Result<NodePage>> getTopItems(TopItemsQuery query);

  Future<Result<NodeDetails>> getNodeDetails(NodeDetailsQuery query);

  Future<Result<ValidatedCleanupPlan>> createCleanupPlan(
    CreateCleanupPlanCommand command,
  );

  Future<Result<CleanupReceipt>> executeCleanupPlan(
    ExecuteCleanupPlanCommand command,
  );

  Future<Result<CleanupRecoveryInbox>> getCleanupRecoveryInbox();
}

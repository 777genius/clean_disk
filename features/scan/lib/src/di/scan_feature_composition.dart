import 'package:clean_disk_scan/src/application/ports/path_revealer.dart';
import 'package:clean_disk_scan/src/application/ports/permission_repair_launcher.dart';
import 'package:clean_disk_scan/src/application/ports/scan_event_client.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_catalog.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_picker.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_preference_store.dart';
import 'package:clean_disk_scan/src/application/use_cases/cancel_scan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/dispose_scan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/execute_cleanup_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_capabilities_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_children_page_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_cleanup_recovery_inbox_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_diagnostics_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_node_details_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_scan_status_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/get_top_items_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/launch_permission_repair_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/list_scan_target_choices_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/load_last_scan_target_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/pick_scan_target_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/probe_permission_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/reveal_path_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/save_last_scan_target_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/search_nodes_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/start_scan_use_case.dart';
import 'package:clean_disk_scan/src/application/use_cases/watch_scan_events_use_case.dart';
import 'package:clean_disk_scan/src/presentation/stores/scan_workspace_store.dart';

final class ScanUseCaseBundle {
  const ScanUseCaseBundle({
    required this.getCapabilities,
    required this.getDiagnostics,
    required this.probePermission,
    this.launchPermissionRepair,
    this.pickScanTarget,
    this.listScanTargetChoices,
    this.loadLastScanTarget,
    this.saveLastScanTarget,
    this.revealPath,
    required this.startScan,
    required this.getScanStatus,
    required this.cancelScan,
    required this.disposeScan,
    required this.getChildrenPage,
    required this.searchNodes,
    required this.getTopItems,
    required this.getNodeDetails,
    required this.executeCleanup,
    required this.getCleanupRecoveryInbox,
    required this.watchScanEvents,
  });

  factory ScanUseCaseBundle.fromPorts({
    required ScanRepository repository,
    required ScanEventClient eventClient,
    PermissionRepairLauncher? permissionRepairLauncher,
    ScanTargetPicker? targetPicker,
    ScanTargetCatalog? targetCatalog,
    ScanTargetPreferenceStore? targetPreferenceStore,
    PathRevealer? pathRevealer,
  }) {
    return ScanUseCaseBundle(
      getCapabilities: GetCapabilitiesUseCase(repository),
      getDiagnostics: GetDiagnosticsUseCase(repository),
      probePermission: ProbePermissionUseCase(repository),
      launchPermissionRepair: permissionRepairLauncher == null
          ? null
          : LaunchPermissionRepairUseCase(permissionRepairLauncher),
      pickScanTarget: targetPicker == null
          ? null
          : PickScanTargetUseCase(targetPicker),
      listScanTargetChoices: targetCatalog == null
          ? null
          : ListScanTargetChoicesUseCase(targetCatalog),
      loadLastScanTarget: targetPreferenceStore == null
          ? null
          : LoadLastScanTargetUseCase(targetPreferenceStore),
      saveLastScanTarget: targetPreferenceStore == null
          ? null
          : SaveLastScanTargetUseCase(targetPreferenceStore),
      revealPath: pathRevealer == null ? null : RevealPathUseCase(pathRevealer),
      startScan: StartScanUseCase(repository),
      getScanStatus: GetScanStatusUseCase(repository),
      cancelScan: CancelScanUseCase(repository),
      disposeScan: DisposeScanUseCase(repository),
      getChildrenPage: GetChildrenPageUseCase(repository),
      searchNodes: SearchNodesUseCase(repository),
      getTopItems: GetTopItemsUseCase(repository),
      getNodeDetails: GetNodeDetailsUseCase(repository),
      executeCleanup: ExecuteCleanupUseCase(repository),
      getCleanupRecoveryInbox: GetCleanupRecoveryInboxUseCase(repository),
      watchScanEvents: WatchScanEventsUseCase(eventClient),
    );
  }

  final GetCapabilitiesUseCase getCapabilities;
  final GetDiagnosticsUseCase getDiagnostics;
  final ProbePermissionUseCase probePermission;
  final LaunchPermissionRepairUseCase? launchPermissionRepair;
  final PickScanTargetUseCase? pickScanTarget;
  final ListScanTargetChoicesUseCase? listScanTargetChoices;
  final LoadLastScanTargetUseCase? loadLastScanTarget;
  final SaveLastScanTargetUseCase? saveLastScanTarget;
  final RevealPathUseCase? revealPath;
  final StartScanUseCase startScan;
  final GetScanStatusUseCase getScanStatus;
  final CancelScanUseCase cancelScan;
  final DisposeScanUseCase disposeScan;
  final GetChildrenPageUseCase getChildrenPage;
  final SearchNodesUseCase searchNodes;
  final GetTopItemsUseCase getTopItems;
  final GetNodeDetailsUseCase getNodeDetails;
  final ExecuteCleanupUseCase executeCleanup;
  final GetCleanupRecoveryInboxUseCase getCleanupRecoveryInbox;
  final WatchScanEventsUseCase watchScanEvents;

  ScanWorkspaceStore createWorkspaceStore() {
    return ScanWorkspaceStore(
      getCapabilities: getCapabilities,
      probePermission: probePermission,
      launchPermissionRepair: launchPermissionRepair,
      pickScanTarget: pickScanTarget,
      listScanTargetChoices: listScanTargetChoices,
      loadLastScanTarget: loadLastScanTarget,
      saveLastScanTarget: saveLastScanTarget,
      revealPath: revealPath,
      startScan: startScan,
      cancelScan: cancelScan,
      getScanStatus: getScanStatus,
      getChildrenPage: getChildrenPage,
      searchNodes: searchNodes,
      getTopItems: getTopItems,
      getNodeDetails: getNodeDetails,
      executeCleanup: executeCleanup,
      getCleanupRecoveryInbox: getCleanupRecoveryInbox,
      watchScanEvents: watchScanEvents,
    );
  }
}

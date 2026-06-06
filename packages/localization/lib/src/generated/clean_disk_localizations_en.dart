// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'clean_disk_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CleanDiskLocalizationsEn extends CleanDiskLocalizations {
  CleanDiskLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Clean Disk';

  @override
  String get scanHomeShellTitle => 'Workspace shell';

  @override
  String get scanHomeShellDescription =>
      'Native scan integration is intentionally not wired yet.';

  @override
  String get scanAction => 'Scan';

  @override
  String get scanAgainAction => 'Scan again';

  @override
  String get pauseAction => 'Pause';

  @override
  String get cancelScanAction => 'Cancel scan';

  @override
  String get searchPlaceholder => 'Search files and folders...';

  @override
  String get searchUnavailablePlaceholder => 'Search after scan';

  @override
  String get sortFilterAction => 'Sort / Filter';

  @override
  String get sortSizeDescLabel => 'Size';

  @override
  String get sortSizeAscLabel => 'Small';

  @override
  String get sortLargestFirstLabel => 'Largest first';

  @override
  String get sortSmallestFirstLabel => 'Smallest first';

  @override
  String get sortNameAscLabel => 'Name A-Z';

  @override
  String get sortNameDescLabel => 'Name Z-A';

  @override
  String get searchResultsTitle => 'Search results';

  @override
  String searchResultsText({required String query}) {
    return 'Search results for \"$query\"';
  }

  @override
  String get searchBackToTreeAction => 'Back to tree';

  @override
  String get topItemsResultsTitle => 'Top items';

  @override
  String get topItemsResultsText => 'Showing a flat top-items view';

  @override
  String get settingsAction => 'Settings';

  @override
  String get targetHome => 'Home';

  @override
  String get targetDownloads => 'Downloads';

  @override
  String get targetLibrary => 'Library';

  @override
  String get targetApplications => 'Applications';

  @override
  String get targetCustom => 'Folder';

  @override
  String get targetPickAction => 'Choose folder';

  @override
  String get targetChangeAction => 'Change folder';

  @override
  String get targetRoot => 'System root';

  @override
  String get targetVolume => 'Volume';

  @override
  String get firstRunTargetTitle => 'Choose what to scan';

  @override
  String get firstRunTargetText =>
      'Pick a folder or disk before scanning so results are tied to an explicit target.';

  @override
  String get totalScannedLabel => 'Total Scanned';

  @override
  String get largestFolderLabel => 'Largest Folder';

  @override
  String get cleanupCandidatesLabel => 'Review List';

  @override
  String get skippedLabel => 'Skipped';

  @override
  String get nameColumn => 'Name';

  @override
  String get sizeColumn => 'Size';

  @override
  String get percentColumn => '%';

  @override
  String get itemsColumn => 'Items';

  @override
  String get detailsTitle => 'Details';

  @override
  String get noSelectionTitle => 'Select a row';

  @override
  String get noSelectionText => 'Details appear after selecting a row.';

  @override
  String get noRowsTitle => 'No scan data yet';

  @override
  String get noRowsText => 'Results will appear here after the scan.';

  @override
  String get loadingRowsTitle => 'Loading scan data';

  @override
  String get loadingRowsText =>
      'Keeping current rows visible while the next page loads.';

  @override
  String get errorRowsTitle => 'Scan data unavailable';

  @override
  String get staleRowsTitle => 'Data is out of date';

  @override
  String get staleRowsText => 'Run the scan again to refresh the tree.';

  @override
  String get partialRowsTitle => 'Partial scan data';

  @override
  String get partialRowsText =>
      'Some paths were skipped or degraded. Review details before acting.';

  @override
  String get revealAction => 'Reveal';

  @override
  String get revealBusyAction => 'Opening...';

  @override
  String get revealUnavailableDisplayPath =>
      'Full path is not available for this row. Expand from the tree root to reveal it.';

  @override
  String get addToQueueAction => 'Add to review';

  @override
  String get reviewAddedAction => 'In review';

  @override
  String get movedToTrashRowLabel => 'In Trash';

  @override
  String get movedToTrashDetailsHint =>
      'This item was already moved to Trash. Run a new scan to refresh the tree before acting on it again.';

  @override
  String get detailsPathLabel => 'Path';

  @override
  String get detailsCreatedLabel => 'Created';

  @override
  String get detailsModifiedLabel => 'Modified';

  @override
  String get detailsChildrenLabel => 'Files / Folders';

  @override
  String get detailsWarningsLabel => 'Warnings';

  @override
  String get detailsItemsSuffix => 'items';

  @override
  String detailsItemsCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: '0 items',
    );
    return '$_temp0';
  }

  @override
  String get detailsTypeLabel => 'Type';

  @override
  String get detailsAccountingLabel => 'Accounting';

  @override
  String get detailsConfidenceLabel => 'Confidence';

  @override
  String get detailsFlagsLabel => 'Flags';

  @override
  String get nodeTypeFile => 'File';

  @override
  String get nodeTypeDirectory => 'Folder';

  @override
  String get nodeTypeSymlink => 'Link';

  @override
  String get nodeTypeOther => 'Other';

  @override
  String get nodeTypeUnknown => 'Unknown';

  @override
  String get sizeQuantityApparent => 'Apparent size';

  @override
  String get sizeQuantityAllocated => 'Size on disk';

  @override
  String get sizeQuantityBlocks => 'Block count';

  @override
  String get sizeQuantityUnknown => 'Unknown';

  @override
  String get sizeConfidenceExact => 'Exact';

  @override
  String get sizeConfidenceHigh => 'High';

  @override
  String get sizeConfidenceMedium => 'Medium';

  @override
  String get sizeConfidenceLow => 'Low';

  @override
  String get sizeConfidenceUnknown => 'Unknown';

  @override
  String get nodeFlagsNone => 'None';

  @override
  String get nodeFlagHidden => 'Hidden';

  @override
  String get nodeFlagSystem => 'System';

  @override
  String get nodeFlagPackage => 'Package';

  @override
  String get nodeFlagSymlink => 'Symlink';

  @override
  String get loadMoreRowsAction => 'Load more';

  @override
  String get loadMoreRowsBusy => 'Loading...';

  @override
  String get deleteQueueTitle => 'Review List';

  @override
  String get deleteQueueEmpty =>
      'Mark a row to review before moving it to Trash.';

  @override
  String deleteQueueMoreCount({required int count}) {
    return '+$count more';
  }

  @override
  String deleteQueueTotalIntent({required String size}) {
    return 'Estimated size: $size';
  }

  @override
  String get deleteQueueRemoveAction => 'Remove from review list';

  @override
  String get cleanupPreviewRefreshAction => 'Validate list';

  @override
  String get cleanupPreviewBlocked =>
      'Review blockers before taking any action.';

  @override
  String get cleanupPreviewReady => 'Review complete. Ready to move to Trash.';

  @override
  String get cleanupPreviewBlockedShort => 'Review';

  @override
  String get cleanupPreviewReadyShort => 'Ready';

  @override
  String get cleanupPreviewTrashAction => 'Move to Trash';

  @override
  String get cleanupPreviewTrashNoticeTitle => 'System Trash only';

  @override
  String get cleanupPreviewTrashNoticeText =>
      'Clean Disk revalidates the current snapshot before moving items. Nothing is permanently deleted here.';

  @override
  String get cleanupConfirmTitle => 'Move selected items to Trash?';

  @override
  String get cleanupConfirmText =>
      'The selected files or folders will be moved to the system Trash. Restore them manually from Trash if needed.';

  @override
  String cleanupConfirmSummary({required int count, required String size}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items, $size',
      one: '1 item, $size',
    );
    return '$_temp0';
  }

  @override
  String get cleanupConfirmCancel => 'Cancel';

  @override
  String get cleanupConfirmMove => 'Move to Trash';

  @override
  String get nodeContextRefreshFolderAction => 'Refresh folder';

  @override
  String get cleanupStateStaleSnapshot => 'Outdated data';

  @override
  String get cleanupStateChangedMetadata => 'Changed metadata';

  @override
  String get cleanupStateMissingPermission => 'No permission';

  @override
  String get cleanupStatePolicyConflict => 'Needs review';

  @override
  String get cleanupStateUnknownReclaim => 'Unknown size';

  @override
  String get cleanupReceiptReady => 'Receipt recorded.';

  @override
  String get cleanupReceiptNeedsReview => 'Receipt needs review.';

  @override
  String get cleanupReceiptItemMoved => 'Moved to Trash';

  @override
  String get cleanupReceiptItemBlocked => 'Blocked';

  @override
  String get cleanupReceiptItemFailed => 'Failed';

  @override
  String get cleanupReceiptItemUnknown => 'Unknown outcome';

  @override
  String get cleanupReceiptItemPending => 'Pending';

  @override
  String get reclaimConfidenceHigh => 'High confidence';

  @override
  String get reclaimConfidenceMedium => 'Medium confidence';

  @override
  String get reclaimConfidenceLow => 'Low confidence';

  @override
  String get reclaimConfidenceUnknown => 'Unknown reclaim';

  @override
  String get progressFilesScannedLabel => 'Files Scanned';

  @override
  String get progressElapsedLabel => 'Elapsed';

  @override
  String get progressThroughputLabel => 'Throughput';

  @override
  String get metricNoDataValue => 'No data';

  @override
  String get metricRunScanSubtitle => 'Run a scan';

  @override
  String get filesCountSuffix => 'files';

  @override
  String get metricCleanupReviewSubtitle => 'Marked items';

  @override
  String get metricSkippedProtectedSubtitle => 'System protected';

  @override
  String get driveFreeSpaceText => '108.0 GB free';

  @override
  String get permissionProofTitle => 'Permission Proof';

  @override
  String get permissionWarningTitle => 'Access not verified';

  @override
  String get permissionWarningDevTitle => 'Development build';

  @override
  String get permissionWarningDeniedText =>
      'Access is denied. Protected folders may be skipped.';

  @override
  String get permissionWarningUnverifiedText =>
      'Access is not verified yet. Run the probe or scan.';

  @override
  String get permissionNeutralProbeText => 'Access checks before scanning.';

  @override
  String get permissionWarningDevIdentityText =>
      'Access is verified. Full Disk Access may differ in a signed build.';

  @override
  String get permissionIdentityLabel => 'Identity';

  @override
  String get permissionProbeLabel => 'Access';

  @override
  String get permissionScannerLabel => 'Scanner';

  @override
  String get permissionActionLabel => 'Action';

  @override
  String get permissionPackageLabel => 'Package';

  @override
  String get permissionUpdateLabel => 'Update';

  @override
  String get permissionCheckedLabel => 'Checked';

  @override
  String get permissionProbeAction => 'Re-check';

  @override
  String get permissionRepairTitle => 'Repair access';

  @override
  String get permissionRepairTrustCopy =>
      'Clean Disk reads file names, sizes, timestamps, and folder structure for the selected target. It does not read file contents.';

  @override
  String get permissionRepairMacosStepOne =>
      'Open Privacy & Security > Full Disk Access.';

  @override
  String get permissionRepairMacosStepTwo =>
      'Enable Clean Disk, or clean-disk-server if macOS lists the bundled helper.';

  @override
  String get permissionRepairMacosStepThree =>
      'Return here and re-check. The scanner confirms access before this screen marks it verified.';

  @override
  String get permissionRepairWindowsStepOne =>
      'Use the normal user scan first.';

  @override
  String get permissionRepairWindowsStepTwo =>
      'If this target is still denied, use an elevated scan profile only for system folders.';

  @override
  String get permissionRepairWindowsStepThree =>
      'Re-check before scanning again.';

  @override
  String get permissionRepairLinuxStepOne =>
      'Check folder permissions for the selected target.';

  @override
  String get permissionRepairLinuxStepTwo =>
      'If the app is sandboxed, grant access through the package or portal settings.';

  @override
  String get permissionRepairLinuxStepThree =>
      'Re-check before scanning again.';

  @override
  String get permissionRepairManualStep =>
      'Review platform access for this target, then re-check.';

  @override
  String get permissionRepairOpenSettings => 'Open Settings';

  @override
  String get permissionRepairCancel => 'Cancel';

  @override
  String get permissionIdentityVerified => 'Verified';

  @override
  String get permissionIdentityUnverified => 'Unverified';

  @override
  String get permissionIdentityUnknown => 'Unknown';

  @override
  String get permissionProbeVerified => 'Verified';

  @override
  String get permissionProbeDenied => 'Denied';

  @override
  String get permissionProbeNotDetermined => 'Not determined';

  @override
  String get permissionProbePending => 'Probe pending';

  @override
  String get permissionProbeDegraded => 'Degraded';

  @override
  String get permissionProbeUnsupported => 'Unsupported';

  @override
  String get permissionProbeUnknown => 'Unknown';

  @override
  String get permissionScannerAppBundle => 'App bundle';

  @override
  String get permissionScannerBundledHelper => 'Bundled helper';

  @override
  String get permissionScannerCurrentProcess => 'Current process';

  @override
  String get permissionScannerExternalProcess => 'External process';

  @override
  String get permissionScannerUnknown => 'Unknown scanner';

  @override
  String get permissionActionNone => 'No action needed';

  @override
  String get permissionActionMacosFullDiskAccess =>
      'Guide Full Disk Access, then re-check';

  @override
  String get permissionActionWindowsAdministrator =>
      'Use admin scan only if needed';

  @override
  String get permissionActionLinuxPermissions =>
      'Review Linux permissions, then re-check';

  @override
  String get permissionActionUnknown => 'Manual review needed';

  @override
  String get permissionActionReducedPackage =>
      'Reduced dev package - verify signed build';

  @override
  String get permissionPackageDevelopment => 'Dev shell';

  @override
  String get permissionPackageAppBundle => 'App bundle';

  @override
  String get permissionPackageBundledDaemon => 'Bundled daemon';

  @override
  String get permissionPackageSystemService => 'System service';

  @override
  String get permissionPackagePortable => 'Portable';

  @override
  String get permissionPackageUnknown => 'Unknown package';

  @override
  String get permissionSignedBuild => 'Signed';

  @override
  String get permissionUnsignedBuild => 'Unsigned';

  @override
  String get permissionUpdateQuiesceRequired => 'Quiesce required';

  @override
  String get permissionUpdateNoQuiesce => 'No quiesce required';

  @override
  String get permissionUpdateUnknown => 'Update safety unknown';

  @override
  String get permissionCheckedNever => 'Not checked';

  @override
  String get permissionCheckedUnknown => 'Unknown time';

  @override
  String get scanReadyStatus => 'Ready';

  @override
  String get scanRunningStatus => 'Scanning...';

  @override
  String get scanCompletedStatus => 'Scan complete';

  @override
  String get scanOfflineStatus => 'Daemon offline';

  @override
  String get scanIncompatibleStatus => 'Protocol incompatible';
}

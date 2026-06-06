import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'clean_disk_localizations_en.dart';
import 'clean_disk_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CleanDiskLocalizations
/// returned by `CleanDiskLocalizations.of(context)`.
///
/// Applications need to include `CleanDiskLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/clean_disk_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CleanDiskLocalizations.localizationsDelegates,
///   supportedLocales: CleanDiskLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the CleanDiskLocalizations.supportedLocales
/// property.
abstract class CleanDiskLocalizations {
  CleanDiskLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CleanDiskLocalizations of(BuildContext context) {
    return Localizations.of<CleanDiskLocalizations>(
      context,
      CleanDiskLocalizations,
    )!;
  }

  static const LocalizationsDelegate<CleanDiskLocalizations> delegate =
      _CleanDiskLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// Application title shown in the window title, app bar, and scan shell.
  ///
  /// In en, this message translates to:
  /// **'Clean Disk'**
  String get appTitle;

  /// Temporary title on the scan home page before native scan integration is wired.
  ///
  /// In en, this message translates to:
  /// **'Workspace shell'**
  String get scanHomeShellTitle;

  /// Temporary explanatory text on the scan home page before native scan integration is wired.
  ///
  /// In en, this message translates to:
  /// **'Native scan integration is intentionally not wired yet.'**
  String get scanHomeShellDescription;

  /// Localized string for scanAction.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanAction;

  /// Primary scan action after a completed scan.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgainAction;

  /// Localized string for pauseAction.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseAction;

  /// Tooltip label for stopping an active scan when cancellation is supported.
  ///
  /// In en, this message translates to:
  /// **'Cancel scan'**
  String get cancelScanAction;

  /// Localized string for searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search files and folders...'**
  String get searchPlaceholder;

  /// Placeholder shown when search is disabled because no readable scan snapshot exists yet.
  ///
  /// In en, this message translates to:
  /// **'Search after scan'**
  String get searchUnavailablePlaceholder;

  /// Localized string for sortFilterAction.
  ///
  /// In en, this message translates to:
  /// **'Sort / Filter'**
  String get sortFilterAction;

  /// Sort option label for largest items first.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortSizeDescLabel;

  /// Sort option label for smallest items first.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get sortSizeAscLabel;

  /// Full sort menu label for largest items first.
  ///
  /// In en, this message translates to:
  /// **'Largest first'**
  String get sortLargestFirstLabel;

  /// Full sort menu label for smallest items first.
  ///
  /// In en, this message translates to:
  /// **'Smallest first'**
  String get sortSmallestFirstLabel;

  /// Sort option label for names in ascending order.
  ///
  /// In en, this message translates to:
  /// **'Name A-Z'**
  String get sortNameAscLabel;

  /// Sort option label for names in descending order.
  ///
  /// In en, this message translates to:
  /// **'Name Z-A'**
  String get sortNameDescLabel;

  /// Title for the active search results table mode.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get searchResultsTitle;

  /// Banner text shown when the table is showing flat search results.
  ///
  /// In en, this message translates to:
  /// **'Search results for \"{query}\"'**
  String searchResultsText({required String query});

  /// Action that clears search mode and returns to the folder tree.
  ///
  /// In en, this message translates to:
  /// **'Back to tree'**
  String get searchBackToTreeAction;

  /// Title for the top-items table mode.
  ///
  /// In en, this message translates to:
  /// **'Top items'**
  String get topItemsResultsTitle;

  /// Banner text shown when the table is showing flat top-items results.
  ///
  /// In en, this message translates to:
  /// **'Showing a flat top-items view'**
  String get topItemsResultsText;

  /// Tooltip label for settings controls.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsAction;

  /// Localized string for targetHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get targetHome;

  /// Localized string for targetDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get targetDownloads;

  /// Localized string for targetLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get targetLibrary;

  /// Localized string for targetApplications.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get targetApplications;

  /// Localized string for targetCustom.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get targetCustom;

  /// Action that opens a platform directory picker for the scan target.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get targetPickAction;

  /// Tooltip for changing an already selected folder scan target.
  ///
  /// In en, this message translates to:
  /// **'Change folder'**
  String get targetChangeAction;

  /// Label for the system root scan target preset.
  ///
  /// In en, this message translates to:
  /// **'System root'**
  String get targetRoot;

  /// Fallback label for a mounted volume scan target preset.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get targetVolume;

  /// Title for the first-run scan target chooser.
  ///
  /// In en, this message translates to:
  /// **'Choose what to scan'**
  String get firstRunTargetTitle;

  /// Short explanation in the first-run scan target chooser.
  ///
  /// In en, this message translates to:
  /// **'Pick a folder or disk before scanning so results are tied to an explicit target.'**
  String get firstRunTargetText;

  /// Localized string for totalScannedLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Scanned'**
  String get totalScannedLabel;

  /// Localized string for largestFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Largest Folder'**
  String get largestFolderLabel;

  /// Localized string for cleanupCandidatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Review List'**
  String get cleanupCandidatesLabel;

  /// Localized string for skippedLabel.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skippedLabel;

  /// Localized string for nameColumn.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameColumn;

  /// Localized string for sizeColumn.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sizeColumn;

  /// Localized string for percentColumn.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get percentColumn;

  /// Localized string for itemsColumn.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsColumn;

  /// Localized string for detailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsTitle;

  /// Localized string for noSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a row'**
  String get noSelectionTitle;

  /// Localized string for noSelectionText.
  ///
  /// In en, this message translates to:
  /// **'Details appear after selecting a row.'**
  String get noSelectionText;

  /// Localized string for noRowsTitle.
  ///
  /// In en, this message translates to:
  /// **'No scan data yet'**
  String get noRowsTitle;

  /// Localized string for noRowsText.
  ///
  /// In en, this message translates to:
  /// **'Results will appear here after the scan.'**
  String get noRowsText;

  /// Localized string for loadingRowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading scan data'**
  String get loadingRowsTitle;

  /// Localized string for loadingRowsText.
  ///
  /// In en, this message translates to:
  /// **'Keeping current rows visible while the next page loads.'**
  String get loadingRowsText;

  /// Localized string for errorRowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan data unavailable'**
  String get errorRowsTitle;

  /// Localized string for staleRowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Data is out of date'**
  String get staleRowsTitle;

  /// Localized string for staleRowsText.
  ///
  /// In en, this message translates to:
  /// **'Run the scan again to refresh the tree.'**
  String get staleRowsText;

  /// Localized string for partialRowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Partial scan data'**
  String get partialRowsTitle;

  /// Localized string for partialRowsText.
  ///
  /// In en, this message translates to:
  /// **'Some paths were skipped or degraded. Review details before acting.'**
  String get partialRowsText;

  /// Localized string for revealAction.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get revealAction;

  /// Details action label shown while the selected file or folder is being revealed in the platform file manager.
  ///
  /// In en, this message translates to:
  /// **'Opening...'**
  String get revealBusyAction;

  /// Details hint shown when the UI only has a shortened display path and cannot safely reveal it in the file manager.
  ///
  /// In en, this message translates to:
  /// **'Full path is not available for this row. Expand from the tree root to reveal it.'**
  String get revealUnavailableDisplayPath;

  /// Localized string for addToQueueAction.
  ///
  /// In en, this message translates to:
  /// **'Add to review'**
  String get addToQueueAction;

  /// Disabled action label for a selected item that is already in the review list.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get reviewAddedAction;

  /// Short row/details status for a scan item already moved to Trash from the current stale snapshot.
  ///
  /// In en, this message translates to:
  /// **'In Trash'**
  String get movedToTrashRowLabel;

  /// Details pane warning shown for an item moved to Trash after cleanup while the old scan snapshot is still visible.
  ///
  /// In en, this message translates to:
  /// **'This item was already moved to Trash. Run a new scan to refresh the tree before acting on it again.'**
  String get movedToTrashDetailsHint;

  /// Label for the selected file or folder display path in the details pane.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get detailsPathLabel;

  /// Label for the selected file or folder creation date in the details pane.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get detailsCreatedLabel;

  /// Label for the selected file or folder modification date in the details pane.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get detailsModifiedLabel;

  /// Label for child item count in the details pane.
  ///
  /// In en, this message translates to:
  /// **'Files / Folders'**
  String get detailsChildrenLabel;

  /// Label for scan warning count in the details pane.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get detailsWarningsLabel;

  /// Short suffix used after a selected node child count in the details pane summary.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get detailsItemsSuffix;

  /// Selected node child item count shown in the details pane summary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 items} =1{1 item} other{{count} items}}'**
  String detailsItemsCount({required int count});

  /// Label for node kind in the details pane.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get detailsTypeLabel;

  /// Label for size accounting mode in the details pane.
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get detailsAccountingLabel;

  /// Label for size confidence in the details pane.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get detailsConfidenceLabel;

  /// Label for node flags in the details pane.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get detailsFlagsLabel;

  /// Display value for a file node.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get nodeTypeFile;

  /// Display value for a directory node.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get nodeTypeDirectory;

  /// Display value for a symbolic link node.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get nodeTypeSymlink;

  /// Display value for another node kind.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get nodeTypeOther;

  /// Display value for an unknown node kind.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get nodeTypeUnknown;

  /// Display value for apparent byte accounting.
  ///
  /// In en, this message translates to:
  /// **'Apparent size'**
  String get sizeQuantityApparent;

  /// Display value for allocated byte accounting.
  ///
  /// In en, this message translates to:
  /// **'Size on disk'**
  String get sizeQuantityAllocated;

  /// Display value for block count accounting.
  ///
  /// In en, this message translates to:
  /// **'Block count'**
  String get sizeQuantityBlocks;

  /// Display value for unknown size accounting.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get sizeQuantityUnknown;

  /// Display value for exact size confidence.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get sizeConfidenceExact;

  /// Display value for high size confidence.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get sizeConfidenceHigh;

  /// Display value for medium size confidence.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sizeConfidenceMedium;

  /// Display value for low size confidence.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get sizeConfidenceLow;

  /// Display value for unknown size confidence.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get sizeConfidenceUnknown;

  /// Display value when a node has no notable flags.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get nodeFlagsNone;

  /// Display value for a hidden node flag.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get nodeFlagHidden;

  /// Display value for a system node flag.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get nodeFlagSystem;

  /// Display value for a package node flag.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get nodeFlagPackage;

  /// Display value for a symlink node flag.
  ///
  /// In en, this message translates to:
  /// **'Symlink'**
  String get nodeFlagSymlink;

  /// Button label for loading the next page of tree rows.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMoreRowsAction;

  /// Button label while loading the next page of tree rows.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadMoreRowsBusy;

  /// Localized string for deleteQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Review List'**
  String get deleteQueueTitle;

  /// Text shown when the cleanup preview queue is empty.
  ///
  /// In en, this message translates to:
  /// **'Mark a row to review before moving it to Trash.'**
  String get deleteQueueEmpty;

  /// Compact count for queued cleanup preview items not shown individually.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String deleteQueueMoreCount({required int count});

  /// Known reclaim estimate total for cleanup preview.
  ///
  /// In en, this message translates to:
  /// **'Estimated size: {size}'**
  String deleteQueueTotalIntent({required String size});

  /// Tooltip for removing an item from cleanup preview queue.
  ///
  /// In en, this message translates to:
  /// **'Remove from review list'**
  String get deleteQueueRemoveAction;

  /// Action that revalidates permission identity before showing cleanup preview state.
  ///
  /// In en, this message translates to:
  /// **'Validate list'**
  String get cleanupPreviewRefreshAction;

  /// Cleanup preview state when one or more items have blocking states.
  ///
  /// In en, this message translates to:
  /// **'Review blockers before taking any action.'**
  String get cleanupPreviewBlocked;

  /// Cleanup preview state when queued items have no blockers and can be moved to Trash.
  ///
  /// In en, this message translates to:
  /// **'Review complete. Ready to move to Trash.'**
  String get cleanupPreviewReady;

  /// Short cleanup preview blocked label.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get cleanupPreviewBlockedShort;

  /// Short cleanup preview ready label.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get cleanupPreviewReadyShort;

  /// Action that executes a validated cleanup plan by moving items to the system Trash.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get cleanupPreviewTrashAction;

  /// Safety notice title for cleanup execution.
  ///
  /// In en, this message translates to:
  /// **'System Trash only'**
  String get cleanupPreviewTrashNoticeTitle;

  /// Safety notice explaining cleanup execution behavior.
  ///
  /// In en, this message translates to:
  /// **'Clean Disk revalidates the current snapshot before moving items. Nothing is permanently deleted here.'**
  String get cleanupPreviewTrashNoticeText;

  /// Cleanup confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Move selected items to Trash?'**
  String get cleanupConfirmTitle;

  /// Cleanup confirmation dialog body.
  ///
  /// In en, this message translates to:
  /// **'The selected files or folders will be moved to the system Trash. Restore them manually from Trash if needed.'**
  String get cleanupConfirmText;

  /// Cleanup confirmation item count and estimated size.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item, {size}} other{{count} items, {size}}}'**
  String cleanupConfirmSummary({required int count, required String size});

  /// Cleanup confirmation cancel action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cleanupConfirmCancel;

  /// Cleanup confirmation destructive action.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get cleanupConfirmMove;

  /// Context menu action that scans the selected folder again as the current target.
  ///
  /// In en, this message translates to:
  /// **'Refresh folder'**
  String get nodeContextRefreshFolderAction;

  /// DeletePlan item state for stale snapshot data.
  ///
  /// In en, this message translates to:
  /// **'Outdated data'**
  String get cleanupStateStaleSnapshot;

  /// DeletePlan item state for metadata changed since item was queued.
  ///
  /// In en, this message translates to:
  /// **'Changed metadata'**
  String get cleanupStateChangedMetadata;

  /// DeletePlan item state for missing current scanner permission.
  ///
  /// In en, this message translates to:
  /// **'No permission'**
  String get cleanupStateMissingPermission;

  /// DeletePlan item state for policy conflicts.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get cleanupStatePolicyConflict;

  /// DeletePlan item state for unknown reclaim estimate.
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get cleanupStateUnknownReclaim;

  /// Cleanup receipt summary when all outcomes are terminal without review.
  ///
  /// In en, this message translates to:
  /// **'Receipt recorded.'**
  String get cleanupReceiptReady;

  /// Cleanup receipt summary when one or more item outcomes need review.
  ///
  /// In en, this message translates to:
  /// **'Receipt needs review.'**
  String get cleanupReceiptNeedsReview;

  /// Cleanup receipt item state for a successful Trash move.
  ///
  /// In en, this message translates to:
  /// **'Moved to Trash'**
  String get cleanupReceiptItemMoved;

  /// Cleanup receipt item state for a blocked item.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get cleanupReceiptItemBlocked;

  /// Cleanup receipt item state for adapter failure.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get cleanupReceiptItemFailed;

  /// Cleanup receipt item state for unknown outcome requiring review.
  ///
  /// In en, this message translates to:
  /// **'Unknown outcome'**
  String get cleanupReceiptItemUnknown;

  /// Cleanup receipt item state for pending or dispatch-recorded item.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get cleanupReceiptItemPending;

  /// High reclaim estimate confidence label.
  ///
  /// In en, this message translates to:
  /// **'High confidence'**
  String get reclaimConfidenceHigh;

  /// Medium reclaim estimate confidence label.
  ///
  /// In en, this message translates to:
  /// **'Medium confidence'**
  String get reclaimConfidenceMedium;

  /// Low reclaim estimate confidence label.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get reclaimConfidenceLow;

  /// Unknown reclaim estimate confidence label.
  ///
  /// In en, this message translates to:
  /// **'Unknown reclaim'**
  String get reclaimConfidenceUnknown;

  /// Localized string for progressFilesScannedLabel.
  ///
  /// In en, this message translates to:
  /// **'Files Scanned'**
  String get progressFilesScannedLabel;

  /// Localized string for progressElapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Elapsed'**
  String get progressElapsedLabel;

  /// Label for scan throughput in the progress footer.
  ///
  /// In en, this message translates to:
  /// **'Throughput'**
  String get progressThroughputLabel;

  /// Readable value shown when a scan metric is not available yet.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get metricNoDataValue;

  /// Metric subtitle shown before scan results are available.
  ///
  /// In en, this message translates to:
  /// **'Run a scan'**
  String get metricRunScanSubtitle;

  /// Short suffix used after a simple file count.
  ///
  /// In en, this message translates to:
  /// **'files'**
  String get filesCountSuffix;

  /// Subtitle for cleanup candidate metric.
  ///
  /// In en, this message translates to:
  /// **'Marked items'**
  String get metricCleanupReviewSubtitle;

  /// Subtitle for skipped protected path metric.
  ///
  /// In en, this message translates to:
  /// **'System protected'**
  String get metricSkippedProtectedSubtitle;

  /// Static MVP free-space label shown in the drive summary fixture.
  ///
  /// In en, this message translates to:
  /// **'108.0 GB free'**
  String get driveFreeSpaceText;

  /// Localized string for permissionProofTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Proof'**
  String get permissionProofTitle;

  /// Title for permission warnings that do not block scanning.
  ///
  /// In en, this message translates to:
  /// **'Access not verified'**
  String get permissionWarningTitle;

  /// Title for non-blocking warnings caused only by development packaging or unsigned scanner identity.
  ///
  /// In en, this message translates to:
  /// **'Development build'**
  String get permissionWarningDevTitle;

  /// Permission warning shown when access probe is denied.
  ///
  /// In en, this message translates to:
  /// **'Access is denied. Protected folders may be skipped.'**
  String get permissionWarningDeniedText;

  /// Permission warning shown when access probe is unknown, pending, degraded, or not determined.
  ///
  /// In en, this message translates to:
  /// **'Access is not verified yet. Run the probe or scan.'**
  String get permissionWarningUnverifiedText;

  /// Short neutral permission status shown before the access probe has run.
  ///
  /// In en, this message translates to:
  /// **'Access checks before scanning.'**
  String get permissionNeutralProbeText;

  /// Permission warning shown when scanner identity or packaging is not production-grade.
  ///
  /// In en, this message translates to:
  /// **'Access is verified. Full Disk Access may differ in a signed build.'**
  String get permissionWarningDevIdentityText;

  /// Localized string for permissionIdentityLabel.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get permissionIdentityLabel;

  /// Localized string for permissionProbeLabel.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get permissionProbeLabel;

  /// Localized string for permissionScannerLabel.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get permissionScannerLabel;

  /// Localized string for permissionActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get permissionActionLabel;

  /// Localized string for permissionPackageLabel.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get permissionPackageLabel;

  /// Localized string for permissionUpdateLabel.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get permissionUpdateLabel;

  /// Localized string for permissionCheckedLabel.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get permissionCheckedLabel;

  /// Localized string for permissionProbeAction.
  ///
  /// In en, this message translates to:
  /// **'Re-check'**
  String get permissionProbeAction;

  /// Title for the permission repair guidance dialog.
  ///
  /// In en, this message translates to:
  /// **'Repair access'**
  String get permissionRepairTitle;

  /// Trust copy shown before asking the user to repair scan permissions.
  ///
  /// In en, this message translates to:
  /// **'Clean Disk reads file names, sizes, timestamps, and folder structure for the selected target. It does not read file contents.'**
  String get permissionRepairTrustCopy;

  /// First macOS Full Disk Access repair step.
  ///
  /// In en, this message translates to:
  /// **'Open Privacy & Security > Full Disk Access.'**
  String get permissionRepairMacosStepOne;

  /// Second macOS Full Disk Access repair step with exact app and helper names.
  ///
  /// In en, this message translates to:
  /// **'Enable Clean Disk, or clean-disk-server if macOS lists the bundled helper.'**
  String get permissionRepairMacosStepTwo;

  /// Third macOS Full Disk Access repair step.
  ///
  /// In en, this message translates to:
  /// **'Return here and re-check. The scanner confirms access before this screen marks it verified.'**
  String get permissionRepairMacosStepThree;

  /// First Windows permission repair step.
  ///
  /// In en, this message translates to:
  /// **'Use the normal user scan first.'**
  String get permissionRepairWindowsStepOne;

  /// Second Windows permission repair step.
  ///
  /// In en, this message translates to:
  /// **'If this target is still denied, use an elevated scan profile only for system folders.'**
  String get permissionRepairWindowsStepTwo;

  /// Third Windows permission repair step.
  ///
  /// In en, this message translates to:
  /// **'Re-check before scanning again.'**
  String get permissionRepairWindowsStepThree;

  /// First Linux permission repair step.
  ///
  /// In en, this message translates to:
  /// **'Check folder permissions for the selected target.'**
  String get permissionRepairLinuxStepOne;

  /// Second Linux permission repair step.
  ///
  /// In en, this message translates to:
  /// **'If the app is sandboxed, grant access through the package or portal settings.'**
  String get permissionRepairLinuxStepTwo;

  /// Third Linux permission repair step.
  ///
  /// In en, this message translates to:
  /// **'Re-check before scanning again.'**
  String get permissionRepairLinuxStepThree;

  /// Fallback permission repair step.
  ///
  /// In en, this message translates to:
  /// **'Review platform access for this target, then re-check.'**
  String get permissionRepairManualStep;

  /// Button label for opening platform permission settings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permissionRepairOpenSettings;

  /// Button label for closing permission repair guidance.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get permissionRepairCancel;

  /// Localized string for permissionIdentityVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get permissionIdentityVerified;

  /// Localized string for permissionIdentityUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get permissionIdentityUnverified;

  /// Localized string for permissionIdentityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get permissionIdentityUnknown;

  /// Localized string for permissionProbeVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get permissionProbeVerified;

  /// Localized string for permissionProbeDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get permissionProbeDenied;

  /// Localized string for permissionProbeNotDetermined.
  ///
  /// In en, this message translates to:
  /// **'Not determined'**
  String get permissionProbeNotDetermined;

  /// Localized string for permissionProbePending.
  ///
  /// In en, this message translates to:
  /// **'Probe pending'**
  String get permissionProbePending;

  /// Localized string for permissionProbeDegraded.
  ///
  /// In en, this message translates to:
  /// **'Degraded'**
  String get permissionProbeDegraded;

  /// Localized string for permissionProbeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get permissionProbeUnsupported;

  /// Localized string for permissionProbeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get permissionProbeUnknown;

  /// Localized string for permissionScannerAppBundle.
  ///
  /// In en, this message translates to:
  /// **'App bundle'**
  String get permissionScannerAppBundle;

  /// Localized string for permissionScannerBundledHelper.
  ///
  /// In en, this message translates to:
  /// **'Bundled helper'**
  String get permissionScannerBundledHelper;

  /// Localized string for permissionScannerCurrentProcess.
  ///
  /// In en, this message translates to:
  /// **'Current process'**
  String get permissionScannerCurrentProcess;

  /// Localized string for permissionScannerExternalProcess.
  ///
  /// In en, this message translates to:
  /// **'External process'**
  String get permissionScannerExternalProcess;

  /// Localized string for permissionScannerUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown scanner'**
  String get permissionScannerUnknown;

  /// Localized string for permissionActionNone.
  ///
  /// In en, this message translates to:
  /// **'No action needed'**
  String get permissionActionNone;

  /// Localized string for permissionActionMacosFullDiskAccess.
  ///
  /// In en, this message translates to:
  /// **'Guide Full Disk Access, then re-check'**
  String get permissionActionMacosFullDiskAccess;

  /// Localized string for permissionActionWindowsAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Use admin scan only if needed'**
  String get permissionActionWindowsAdministrator;

  /// Localized string for permissionActionLinuxPermissions.
  ///
  /// In en, this message translates to:
  /// **'Review Linux permissions, then re-check'**
  String get permissionActionLinuxPermissions;

  /// Localized string for permissionActionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Manual review needed'**
  String get permissionActionUnknown;

  /// Localized string for permissionActionReducedPackage.
  ///
  /// In en, this message translates to:
  /// **'Reduced dev package - verify signed build'**
  String get permissionActionReducedPackage;

  /// Localized string for permissionPackageDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Dev shell'**
  String get permissionPackageDevelopment;

  /// Localized string for permissionPackageAppBundle.
  ///
  /// In en, this message translates to:
  /// **'App bundle'**
  String get permissionPackageAppBundle;

  /// Localized string for permissionPackageBundledDaemon.
  ///
  /// In en, this message translates to:
  /// **'Bundled daemon'**
  String get permissionPackageBundledDaemon;

  /// Localized string for permissionPackageSystemService.
  ///
  /// In en, this message translates to:
  /// **'System service'**
  String get permissionPackageSystemService;

  /// Localized string for permissionPackagePortable.
  ///
  /// In en, this message translates to:
  /// **'Portable'**
  String get permissionPackagePortable;

  /// Localized string for permissionPackageUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown package'**
  String get permissionPackageUnknown;

  /// Localized string for permissionSignedBuild.
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get permissionSignedBuild;

  /// Localized string for permissionUnsignedBuild.
  ///
  /// In en, this message translates to:
  /// **'Unsigned'**
  String get permissionUnsignedBuild;

  /// Localized string for permissionUpdateQuiesceRequired.
  ///
  /// In en, this message translates to:
  /// **'Quiesce required'**
  String get permissionUpdateQuiesceRequired;

  /// Localized string for permissionUpdateNoQuiesce.
  ///
  /// In en, this message translates to:
  /// **'No quiesce required'**
  String get permissionUpdateNoQuiesce;

  /// Localized string for permissionUpdateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Update safety unknown'**
  String get permissionUpdateUnknown;

  /// Localized string for permissionCheckedNever.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get permissionCheckedNever;

  /// Localized string for permissionCheckedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown time'**
  String get permissionCheckedUnknown;

  /// Localized string for scanReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get scanReadyStatus;

  /// Localized string for scanRunningStatus.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanRunningStatus;

  /// Localized string for scanCompletedStatus.
  ///
  /// In en, this message translates to:
  /// **'Scan complete'**
  String get scanCompletedStatus;

  /// Localized string for scanOfflineStatus.
  ///
  /// In en, this message translates to:
  /// **'Daemon offline'**
  String get scanOfflineStatus;

  /// Localized string for scanIncompatibleStatus.
  ///
  /// In en, this message translates to:
  /// **'Protocol incompatible'**
  String get scanIncompatibleStatus;
}

class _CleanDiskLocalizationsDelegate
    extends LocalizationsDelegate<CleanDiskLocalizations> {
  const _CleanDiskLocalizationsDelegate();

  @override
  Future<CleanDiskLocalizations> load(Locale locale) {
    return SynchronousFuture<CleanDiskLocalizations>(
      lookupCleanDiskLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_CleanDiskLocalizationsDelegate old) => false;
}

CleanDiskLocalizations lookupCleanDiskLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return CleanDiskLocalizationsEn();
    case 'ru':
      return CleanDiskLocalizationsRu();
  }

  throw FlutterError(
    'CleanDiskLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

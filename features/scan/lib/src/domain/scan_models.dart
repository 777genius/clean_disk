final class ProtocolVersion {
  const ProtocolVersion({required this.major, required this.minor});

  static const current = ProtocolVersion(major: 0, minor: 4);

  final int major;
  final int minor;

  bool isCompatibleWith(ProtocolVersion minimum) {
    return major == minimum.major && minor >= minimum.minor;
  }

  @override
  bool operator ==(Object other) {
    return other is ProtocolVersion &&
        other.major == major &&
        other.minor == minor;
  }

  @override
  int get hashCode => Object.hash(major, minor);
}

sealed class DecimalIdentifier {
  DecimalIdentifier(String value) : value = _validatedDecimal(value);

  final String value;

  BigInt toBigInt() => BigInt.parse(value);

  @override
  bool operator ==(Object other) {
    return other is DecimalIdentifier &&
        other.runtimeType == runtimeType &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

final class CommandId extends DecimalIdentifier {
  CommandId(super.value);
}

final class ScanSessionId extends DecimalIdentifier {
  ScanSessionId(super.value);
}

final class SnapshotId extends DecimalIdentifier {
  SnapshotId(super.value);
}

final class CleanupPlanId extends DecimalIdentifier {
  CleanupPlanId(super.value);
}

final class NodeId extends DecimalIdentifier {
  NodeId(super.value);
}

final class EventSequence extends DecimalIdentifier {
  EventSequence(super.value);
}

final class OpaqueCursor {
  OpaqueCursor(String value) : value = _validatedNonEmpty(value);

  final String value;

  @override
  bool operator ==(Object other) {
    return other is OpaqueCursor && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class ScanTargetPath {
  ScanTargetPath(String value) : value = _validatedNonEmpty(value);

  final String value;

  @override
  bool operator ==(Object other) {
    return other is ScanTargetPath && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

enum TargetScope { localPath, volume, custom, unknown }

enum BoundaryPolicy { crossFilesystems, stayOnInitialFilesystem, unknown }

enum HardlinkPolicy { ignore, detect, deduplicateForDisplay, unknown }

enum MeasuredQuantity { apparentBytes, allocatedBytes, blockCount, unknown }

enum ScanMode { background, balanced, fast, unknown }

final class ScanTarget {
  const ScanTarget({
    required this.path,
    required this.scope,
    required this.boundaryPolicy,
    required this.hardlinkPolicy,
  });

  final ScanTargetPath path;
  final TargetScope scope;
  final BoundaryPolicy boundaryPolicy;
  final HardlinkPolicy hardlinkPolicy;
}

final class StartScanCommand {
  const StartScanCommand({
    required this.commandId,
    required this.targets,
    required this.measurement,
    required this.mode,
  });

  final CommandId commandId;
  final List<ScanTarget> targets;
  final MeasuredQuantity measurement;
  final ScanMode mode;
}

final class SessionCommand {
  const SessionCommand({required this.commandId, required this.sessionId});

  final CommandId commandId;
  final ScanSessionId sessionId;
}

enum SessionState { created, running, canceled, completed, failed, unknown }

final class ScanProgress {
  const ScanProgress({
    required this.scannedItems,
    this.elapsedMs,
    this.throughputBytesPerSec,
  });

  final BigInt scannedItems;
  final BigInt? elapsedMs;
  final BigInt? throughputBytesPerSec;
}

final class ScanSessionStatus {
  const ScanSessionStatus({
    required this.sessionId,
    required this.state,
    required this.snapshotId,
    required this.rootNodeIds,
    required this.progress,
  });

  final ScanSessionId sessionId;
  final SessionState state;
  final SnapshotId? snapshotId;
  final List<NodeId> rootNodeIds;
  final ScanProgress? progress;

  bool get hasPublishedSnapshot => snapshotId != null;

  bool get isTerminal {
    return switch (state) {
      SessionState.canceled ||
      SessionState.completed ||
      SessionState.failed => true,
      _ => false,
    };
  }
}

enum NodeKind { file, directory, symlink, other, unknown }

enum ChildCompleteness {
  complete,
  collapsedByDepth,
  collapsedByProjection,
  skippedByBoundary,
  incompleteDueToIssue,
  unknown,
}

enum ChildSort { insertion, nameAsc, nameDesc, sizeAsc, sizeDesc }

enum TopItemsKind { files, directories, filesAndDirectories }

enum SizeConfidence { exact, high, medium, low, unknown }

final class SizeFact {
  SizeFact({
    required String rawValue,
    required this.quantity,
    required String? byteEquivalent,
    required this.confidence,
  }) : rawValue = _validatedDecimal(rawValue),
       byteEquivalent = byteEquivalent == null
           ? null
           : _validatedDecimal(byteEquivalent);

  final String rawValue;
  final MeasuredQuantity quantity;
  final String? byteEquivalent;
  final SizeConfidence confidence;

  BigInt get rawBigInt => BigInt.parse(rawValue);

  BigInt? get byteEquivalentBigInt {
    final value = byteEquivalent;
    return value == null ? null : BigInt.parse(value);
  }
}

final class NodeFlags {
  const NodeFlags({
    required this.hidden,
    required this.system,
    required this.package,
    required this.symlink,
  });

  final bool hidden;
  final bool system;
  final bool package;
  final bool symlink;
}

final class NodePageItem {
  const NodePageItem({
    required this.nodeId,
    required this.parentId,
    required this.name,
    required this.kind,
    required this.size,
    required this.flags,
    required this.childCompleteness,
    required this.childCount,
    required this.issueCount,
    required this.subtreeIssueCount,
  });

  final NodeId nodeId;
  final NodeId? parentId;
  final String name;
  final NodeKind kind;
  final SizeFact size;
  final NodeFlags flags;
  final ChildCompleteness childCompleteness;
  final int childCount;
  final int issueCount;
  final int subtreeIssueCount;
}

final class NodePage {
  const NodePage({
    required this.snapshotId,
    required this.items,
    required this.nextCursor,
  });

  final SnapshotId snapshotId;
  final List<NodePageItem> items;
  final OpaqueCursor? nextCursor;
}

final class ChildrenPageQuery {
  const ChildrenPageQuery({
    required this.sessionId,
    required this.snapshotId,
    required this.parentId,
    required this.cursor,
    required this.limit,
    required this.sort,
  });

  final ScanSessionId sessionId;
  final SnapshotId snapshotId;
  final NodeId parentId;
  final OpaqueCursor? cursor;
  final int limit;
  final ChildSort sort;
}

final class SearchPageQuery {
  const SearchPageQuery({
    required this.sessionId,
    required this.snapshotId,
    required this.searchText,
    required this.cursor,
    required this.limit,
  });

  final ScanSessionId sessionId;
  final SnapshotId snapshotId;
  final String searchText;
  final OpaqueCursor? cursor;
  final int limit;
}

final class TopItemsQuery {
  const TopItemsQuery({
    required this.sessionId,
    required this.snapshotId,
    required this.kind,
    required this.cursor,
    required this.limit,
  });

  final ScanSessionId sessionId;
  final SnapshotId snapshotId;
  final TopItemsKind kind;
  final OpaqueCursor? cursor;
  final int limit;
}

final class NodeDetailsQuery {
  const NodeDetailsQuery({
    required this.sessionId,
    required this.snapshotId,
    required this.nodeId,
  });

  final ScanSessionId sessionId;
  final SnapshotId snapshotId;
  final NodeId nodeId;
}

enum PathPrivacy { raw, redacted, unavailable, unknown }

final class DisplayPath {
  const DisplayPath({required this.text, required this.privacy});

  final String text;
  final PathPrivacy privacy;
}

enum IssueCode {
  permissionDenied,
  metadataUnavailable,
  readDirectoryFailed,
  accessEntryFailed,
  boundarySkipped,
  nonUtf8Path,
  backendLimitation,
  unknown,
}

enum IssueSeverity { info, warning, error, unknown }

final class IssueEvidence {
  const IssueEvidence({
    required this.path,
    required this.operation,
    required this.message,
  });

  final DisplayPath? path;
  final String? operation;
  final String? message;
}

final class ScanIssue {
  const ScanIssue({
    required this.code,
    required this.severity,
    required this.evidence,
  });

  final IssueCode code;
  final IssueSeverity severity;
  final IssueEvidence evidence;
}

final class NodeDetails {
  const NodeDetails({
    required this.snapshotId,
    required this.summary,
    required this.timestamps,
    required this.childIds,
    required this.issues,
  });

  final SnapshotId snapshotId;
  final NodePageItem summary;
  final NodeTimestamps? timestamps;
  final List<NodeId> childIds;
  final List<ScanIssue> issues;
}

final class NodeTimestamps {
  const NodeTimestamps({
    required this.createdAtUnixMs,
    required this.modifiedAtUnixMs,
  });

  final BigInt? createdAtUnixMs;
  final BigInt? modifiedAtUnixMs;
}

enum ReclaimEstimateConfidence { high, medium, low, unknown }

final class ReclaimEstimate {
  const ReclaimEstimate({
    required this.bytes,
    required this.confidence,
    required this.evidenceCodes,
  });

  static const unknown = ReclaimEstimate(
    bytes: null,
    confidence: ReclaimEstimateConfidence.unknown,
    evidenceCodes: ['missing_size_evidence'],
  );

  factory ReclaimEstimate.fromMeasuredSize(SizeFact size) {
    final bytes = size.byteEquivalentBigInt;
    if (bytes == null) {
      return ReclaimEstimate.unknown;
    }

    final confidence = switch (size.confidence) {
      SizeConfidence.exact ||
      SizeConfidence.high => ReclaimEstimateConfidence.low,
      SizeConfidence.medium => ReclaimEstimateConfidence.low,
      SizeConfidence.low ||
      SizeConfidence.unknown => ReclaimEstimateConfidence.unknown,
    };

    return ReclaimEstimate(
      bytes: bytes,
      confidence: confidence,
      evidenceCodes: const ['scan_size_only'],
    );
  }

  final BigInt? bytes;
  final ReclaimEstimateConfidence confidence;
  final List<String> evidenceCodes;

  bool get hasKnownBytes => bytes != null;
}

enum DeletePlanItemState {
  staleSnapshot,
  changedMetadata,
  missingPermission,
  policyConflict,
  unknownReclaim,
}

final class CleanupQueueIntent {
  const CleanupQueueIntent({
    required this.sessionId,
    required this.snapshotId,
    required this.nodeId,
    required this.parentId,
    required this.displayName,
    required this.kind,
    required this.measuredSize,
    required this.flags,
    required this.childCompleteness,
    required this.childCount,
    required this.issueCount,
    required this.subtreeIssueCount,
  });

  factory CleanupQueueIntent.fromNode({
    required ScanSessionId sessionId,
    required SnapshotId snapshotId,
    required NodePageItem item,
  }) {
    return CleanupQueueIntent(
      sessionId: sessionId,
      snapshotId: snapshotId,
      nodeId: item.nodeId,
      parentId: item.parentId,
      displayName: item.name,
      kind: item.kind,
      measuredSize: item.size,
      flags: item.flags,
      childCompleteness: item.childCompleteness,
      childCount: item.childCount,
      issueCount: item.issueCount,
      subtreeIssueCount: item.subtreeIssueCount,
    );
  }

  final ScanSessionId sessionId;
  final SnapshotId snapshotId;
  final NodeId nodeId;
  final NodeId? parentId;
  final String displayName;
  final NodeKind kind;
  final SizeFact measuredSize;
  final NodeFlags flags;
  final ChildCompleteness childCompleteness;
  final int childCount;
  final int issueCount;
  final int subtreeIssueCount;

  bool hasMetadataChangedFrom(NodePageItem current) {
    return displayName != current.name ||
        kind != current.kind ||
        !_sameSizeFact(measuredSize, current.size) ||
        childCompleteness != current.childCompleteness ||
        childCount != current.childCount ||
        issueCount != current.issueCount ||
        subtreeIssueCount != current.subtreeIssueCount;
  }

  bool get hasPolicyConflict {
    final cleanupKindAllowed =
        kind == NodeKind.file ||
        kind == NodeKind.directory ||
        kind == NodeKind.unknown;
    return !cleanupKindAllowed ||
        flags.system ||
        flags.package ||
        flags.symlink ||
        childCompleteness != ChildCompleteness.complete ||
        issueCount > 0 ||
        subtreeIssueCount > 0;
  }
}

final class DeletePlanItem {
  const DeletePlanItem({
    required this.intent,
    required this.reclaimEstimate,
    required this.states,
  });

  final CleanupQueueIntent intent;
  final ReclaimEstimate reclaimEstimate;
  final Set<DeletePlanItemState> states;

  bool get isBlocked => states.isNotEmpty;
}

final class DeletePlan {
  const DeletePlan({
    required this.items,
    required this.runtimeProof,
    required this.activeSnapshotId,
  });

  factory DeletePlan.preview({
    required Iterable<CleanupQueueIntent> intents,
    required RuntimeProof runtimeProof,
    required SnapshotId? activeSnapshotId,
    required Iterable<NodePageItem> currentRows,
    required bool visibleRowsStale,
  }) {
    final currentByNode = <NodeId, NodePageItem>{
      for (final row in currentRows) row.nodeId: row,
    };
    final items = intents
        .map((intent) {
          final states = <DeletePlanItemState>{};
          final current = currentByNode[intent.nodeId];
          final reclaimEstimate = ReclaimEstimate.fromMeasuredSize(
            intent.measuredSize,
          );

          if (activeSnapshotId == null ||
              intent.snapshotId != activeSnapshotId ||
              visibleRowsStale) {
            states.add(DeletePlanItemState.staleSnapshot);
          }
          if (current != null && intent.hasMetadataChangedFrom(current)) {
            states.add(DeletePlanItemState.changedMetadata);
          }
          if (runtimeProof.permissionProbe.status !=
              PermissionProbeStatus.verified) {
            states.add(DeletePlanItemState.missingPermission);
          }
          if (intent.hasPolicyConflict) {
            states.add(DeletePlanItemState.policyConflict);
          }
          if (!reclaimEstimate.hasKnownBytes ||
              reclaimEstimate.confidence == ReclaimEstimateConfidence.unknown) {
            states.add(DeletePlanItemState.unknownReclaim);
          }

          return DeletePlanItem(
            intent: intent,
            reclaimEstimate: reclaimEstimate,
            states: states,
          );
        })
        .toList(growable: false);

    return DeletePlan(
      items: items,
      runtimeProof: runtimeProof,
      activeSnapshotId: activeSnapshotId,
    );
  }

  final List<DeletePlanItem> items;
  final RuntimeProof runtimeProof;
  final SnapshotId? activeSnapshotId;

  bool get hasItems => items.isNotEmpty;

  bool get hasBlockingStates {
    return items.any((item) => item.isBlocked);
  }

  bool get canAuthorizeCleanup => hasItems && !hasBlockingStates;

  BigInt get knownReclaimBytes {
    return items.fold<BigInt>(BigInt.zero, (sum, item) {
      return sum + (item.reclaimEstimate.bytes ?? BigInt.zero);
    });
  }
}

final class CleanupPlanItemRef {
  const CleanupPlanItemRef({
    required this.sessionId,
    required this.snapshotId,
    required this.nodeId,
  });

  factory CleanupPlanItemRef.fromIntent(CleanupQueueIntent intent) {
    return CleanupPlanItemRef(
      sessionId: intent.sessionId,
      snapshotId: intent.snapshotId,
      nodeId: intent.nodeId,
    );
  }

  final ScanSessionId sessionId;
  final SnapshotId snapshotId;
  final NodeId nodeId;
}

final class ExecuteCleanupCommand {
  const ExecuteCleanupCommand({required this.commandId, required this.items});

  final CommandId commandId;
  final List<CleanupPlanItemRef> items;
}

final class CreateCleanupPlanCommand {
  const CreateCleanupPlanCommand({
    required this.commandId,
    required this.items,
  });

  final CommandId commandId;
  final List<CleanupPlanItemRef> items;
}

final class ExecuteCleanupPlanCommand {
  const ExecuteCleanupPlanCommand({
    required this.commandId,
    required this.planId,
  });

  final CommandId commandId;
  final CleanupPlanId planId;
}

enum ValidatedCleanupPlanState { ready, blocked, unknown }

enum ValidatedCleanupPlanItemState { ready, blocked, unknown }

final class ValidatedCleanupPlanItem {
  const ValidatedCleanupPlanItem({
    required this.itemRef,
    required this.displayName,
    required this.state,
    required this.reason,
  });

  final CleanupPlanItemRef itemRef;
  final String displayName;
  final ValidatedCleanupPlanItemState state;
  final String? reason;

  bool get isBlocked => state != ValidatedCleanupPlanItemState.ready;
}

final class ValidatedCleanupPlan {
  const ValidatedCleanupPlan({
    required this.planId,
    required this.commandId,
    required this.state,
    required this.items,
  });

  final CleanupPlanId planId;
  final CommandId commandId;
  final ValidatedCleanupPlanState state;
  final List<ValidatedCleanupPlanItem> items;

  bool get canExecute {
    return state == ValidatedCleanupPlanState.ready &&
        items.isNotEmpty &&
        !items.any((item) => item.isBlocked);
  }
}

enum CleanupReceiptState {
  intentRecorded,
  receiptSkeletonRecorded,
  running,
  completed,
  completedWithFailures,
  interruptedRequiresReview,
  completedWithUnknowns,
  failedBeforeDispatch,
  unknown,
}

enum CleanupItemOutcomeState {
  pending,
  dispatchRecorded,
  movedToTrash,
  blocked,
  failed,
  unknownRequiresReview,
  unknown,
}

enum RestoreExpectationLevel {
  platformTrashManual,
  unknown,
  notRestorable,
  unsupported,
}

final class CleanupReceiptItem {
  const CleanupReceiptItem({
    required this.nodeId,
    required this.displayName,
    required this.state,
    required this.restoreExpectation,
    required this.reason,
  });

  final NodeId nodeId;
  final String displayName;
  final CleanupItemOutcomeState state;
  final RestoreExpectationLevel restoreExpectation;
  final String? reason;

  bool get needsReview {
    return state == CleanupItemOutcomeState.unknownRequiresReview ||
        state == CleanupItemOutcomeState.failed ||
        state == CleanupItemOutcomeState.blocked;
  }
}

final class CleanupReceipt {
  const CleanupReceipt({
    required this.operationId,
    required this.commandId,
    required this.state,
    required this.lowDiskReserveReady,
    required this.items,
  });

  final CommandId operationId;
  final CommandId commandId;
  final CleanupReceiptState state;
  final bool lowDiskReserveReady;
  final List<CleanupReceiptItem> items;

  bool get hasReviewItems => items.any((item) => item.needsReview);
}

final class CleanupRecoveryInbox {
  const CleanupRecoveryInbox({required this.interruptedReceipts});

  final List<CleanupReceipt> interruptedReceipts;
}

sealed class ScanEvent {
  const ScanEvent({required this.sessionId});

  final ScanSessionId? sessionId;
}

final class ScanStarted extends ScanEvent {
  const ScanStarted({required ScanSessionId sessionId})
    : super(sessionId: sessionId);
}

final class ScanProgressed extends ScanEvent {
  const ScanProgressed({
    required ScanSessionId sessionId,
    required this.progress,
  }) : super(sessionId: sessionId);

  final ScanProgress progress;
}

final class ScanSnapshotPublished extends ScanEvent {
  const ScanSnapshotPublished({
    required ScanSessionId sessionId,
    required this.snapshotId,
  }) : super(sessionId: sessionId);

  final SnapshotId snapshotId;
}

final class ScanCanceled extends ScanEvent {
  const ScanCanceled({required ScanSessionId sessionId})
    : super(sessionId: sessionId);
}

final class ScanFailed extends ScanEvent {
  const ScanFailed({required ScanSessionId sessionId, required this.message})
    : super(sessionId: sessionId);

  final String message;
}

final class UnknownScanEvent extends ScanEvent {
  const UnknownScanEvent() : super(sessionId: null);
}

final class ScanEventEnvelope {
  const ScanEventEnvelope({
    required this.protocolVersion,
    required this.sequence,
    required this.emittedAtUnixMs,
    required this.event,
  });

  final ProtocolVersion protocolVersion;
  final EventSequence sequence;
  final BigInt emittedAtUnixMs;
  final ScanEvent event;
}

enum SupportLevel { supported, unsupported, unknown }

enum RuntimePlatform { macos, windows, linux, unknown }

enum ScannerProcessKind {
  appBundle,
  bundledHelper,
  currentProcess,
  externalProcess,
  unknown,
}

enum ScannerIdentityVerification { verified, unverified, unknown }

enum PermissionProbeStatus {
  verified,
  denied,
  notDetermined,
  notProbed,
  degraded,
  unsupported,
  unknown,
}

enum PermissionRequiredAction {
  none,
  openMacosFullDiskAccess,
  runAsAdministrator,
  reviewLinuxPermissions,
  unknown,
}

enum DistributionChannel {
  development,
  direct,
  macAppStore,
  windowsStore,
  packageManager,
  unknown,
}

enum PackageMode {
  developmentShell,
  appBundle,
  bundledDaemon,
  systemService,
  portable,
  unknown,
}

final class CapabilitySet {
  const CapabilitySet({
    required this.hardlinks,
    required this.filesystemBoundary,
    required this.cooperativeCancellation,
    required this.metadataEnrichment,
  });

  final SupportLevel hardlinks;
  final SupportLevel filesystemBoundary;
  final SupportLevel cooperativeCancellation;
  final SupportLevel metadataEnrichment;
}

final class ScannerCapability {
  const ScannerCapability({
    required this.backendName,
    required this.capabilities,
  });

  final String backendName;
  final CapabilitySet capabilities;
}

final class ScannerIdentityProof {
  const ScannerIdentityProof({
    required this.platform,
    required this.processKind,
    required this.verification,
    required this.executablePath,
    required this.bundleIdentifier,
  });

  final RuntimePlatform platform;
  final ScannerProcessKind processKind;
  final ScannerIdentityVerification verification;
  final ScanTargetPath? executablePath;
  final String? bundleIdentifier;
}

final class PermissionProbe {
  const PermissionProbe({
    required this.status,
    required this.checkedAtUnixMs,
    required this.requiredAction,
  });

  final PermissionProbeStatus status;
  final BigInt? checkedAtUnixMs;
  final PermissionRequiredAction requiredAction;
}

final class UpdateSafety {
  const UpdateSafety({
    required this.quiesceRequiredBeforeUpdate,
    required this.rollbackSupported,
    required this.receiptPreservation,
  });

  final bool quiesceRequiredBeforeUpdate;
  final SupportLevel rollbackSupported;
  final SupportLevel receiptPreservation;
}

final class PackagingProof {
  const PackagingProof({
    required this.distributionChannel,
    required this.packageMode,
    required this.sandboxed,
    required this.signedBuild,
    required this.debugBuild,
    required this.scannerProcess,
    required this.limitations,
    required this.updateSafety,
  });

  static const unknown = PackagingProof(
    distributionChannel: DistributionChannel.unknown,
    packageMode: PackageMode.unknown,
    sandboxed: false,
    signedBuild: false,
    debugBuild: false,
    scannerProcess: ScannerProcessKind.unknown,
    limitations: [],
    updateSafety: UpdateSafety(
      quiesceRequiredBeforeUpdate: true,
      rollbackSupported: SupportLevel.unknown,
      receiptPreservation: SupportLevel.unknown,
    ),
  );

  final DistributionChannel distributionChannel;
  final PackageMode packageMode;
  final bool sandboxed;
  final bool signedBuild;
  final bool debugBuild;
  final ScannerProcessKind scannerProcess;
  final List<String> limitations;
  final UpdateSafety updateSafety;
}

final class RuntimeProof {
  const RuntimeProof({
    required this.scannerIdentity,
    required this.permissionProbe,
    required this.packaging,
  });

  static const unknown = RuntimeProof(
    scannerIdentity: ScannerIdentityProof(
      platform: RuntimePlatform.unknown,
      processKind: ScannerProcessKind.unknown,
      verification: ScannerIdentityVerification.unknown,
      executablePath: null,
      bundleIdentifier: null,
    ),
    permissionProbe: PermissionProbe(
      status: PermissionProbeStatus.unknown,
      checkedAtUnixMs: null,
      requiredAction: PermissionRequiredAction.unknown,
    ),
    packaging: PackagingProof.unknown,
  );

  final ScannerIdentityProof scannerIdentity;
  final PermissionProbe permissionProbe;
  final PackagingProof packaging;

  RuntimeProof copyWith({
    ScannerIdentityProof? scannerIdentity,
    PermissionProbe? permissionProbe,
    PackagingProof? packaging,
  }) {
    return RuntimeProof(
      scannerIdentity: scannerIdentity ?? this.scannerIdentity,
      permissionProbe: permissionProbe ?? this.permissionProbe,
      packaging: packaging ?? this.packaging,
    );
  }
}

final class ProtocolLimits {
  const ProtocolLimits({
    required this.maxPageSize,
    required this.maxEventQueueItems,
  });

  final int maxPageSize;
  final int maxEventQueueItems;
}

final class DaemonCapabilities {
  const DaemonCapabilities({
    required this.protocolVersion,
    required this.scanner,
    required this.limits,
    required this.runtimeProof,
  });

  final ProtocolVersion protocolVersion;
  final ScannerCapability scanner;
  final ProtocolLimits limits;
  final RuntimeProof runtimeProof;

  DaemonCapabilities copyWith({RuntimeProof? runtimeProof}) {
    return DaemonCapabilities(
      protocolVersion: protocolVersion,
      scanner: scanner,
      limits: limits,
      runtimeProof: runtimeProof ?? this.runtimeProof,
    );
  }
}

final class DaemonDiagnostics {
  const DaemonDiagnostics({
    required this.protocolVersion,
    required this.activeSessions,
    required this.runningSessions,
    required this.completedSessions,
    required this.cancelRequestedSessions,
    required this.bufferedEvents,
    required this.storedCursors,
    required this.authRequired,
  });

  final ProtocolVersion protocolVersion;
  final int activeSessions;
  final int runningSessions;
  final int completedSessions;
  final int cancelRequestedSessions;
  final int bufferedEvents;
  final int storedCursors;
  final bool authRequired;
}

String _validatedDecimal(String value) {
  if (value.isEmpty || value.codeUnits.any((unit) => unit < 48 || unit > 57)) {
    throw ArgumentError.value(value, 'value', 'Expected decimal string');
  }
  return value;
}

String _validatedNonEmpty(String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, 'value', 'Expected non-empty value');
  }
  return value;
}

bool _sameSizeFact(SizeFact left, SizeFact right) {
  return left.rawValue == right.rawValue &&
      left.quantity == right.quantity &&
      left.byteEquivalent == right.byteEquivalent &&
      left.confidence == right.confidence;
}

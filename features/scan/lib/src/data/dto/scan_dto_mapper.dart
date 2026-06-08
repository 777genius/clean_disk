import 'package:clean_disk_scan/src/data/dto/scan_protocol_dtos.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

extension StartScanCommandDtoMapper on StartScanCommand {
  StartScanRequestDto toDto() {
    return StartScanRequestDto(
      protocolVersion: ProtocolVersionDto.current,
      commandId: commandId.value,
      targets: targets.map((target) => target.toDto()).toList(),
      measurement: measurement.toWire(),
      mode: mode.toWire(),
    );
  }
}

extension SessionCommandDtoMapper on SessionCommand {
  SessionCommandRequestDto toDto() {
    return SessionCommandRequestDto(
      protocolVersion: ProtocolVersionDto.current,
      commandId: commandId.value,
      sessionId: sessionId.value,
    );
  }
}

extension CreateCleanupPlanCommandDtoMapper on CreateCleanupPlanCommand {
  CreateCleanupPlanRequestDto toDto() {
    return CreateCleanupPlanRequestDto(
      protocolVersion: ProtocolVersionDto.current,
      commandId: commandId.value,
      items: items.map((item) => item.toDto()).toList(),
    );
  }
}

extension ExecuteCleanupPlanCommandDtoMapper on ExecuteCleanupPlanCommand {
  ExecuteCleanupPlanRequestDto toDto() {
    return ExecuteCleanupPlanRequestDto(
      protocolVersion: ProtocolVersionDto.current,
      commandId: commandId.value,
      planId: planId.value,
    );
  }
}

extension CleanupPlanItemRefDtoMapper on CleanupPlanItemRef {
  CleanupPlanItemRefDto toDto() {
    return CleanupPlanItemRefDto(
      sessionId: sessionId.value,
      snapshotId: snapshotId.value,
      nodeId: nodeId.value,
    );
  }
}

extension CleanupPlanDtoMapper on CleanupPlanDto {
  ValidatedCleanupPlan toDomain() {
    return ValidatedCleanupPlan(
      planId: CleanupPlanId(planId),
      commandId: CommandId(commandId),
      state: state.toValidatedCleanupPlanState(),
      items: items.map((item) => item.toDomain()).toList(growable: false),
    );
  }
}

extension CleanupPlanItemDtoMapper on CleanupPlanItemDto {
  ValidatedCleanupPlanItem toDomain() {
    return ValidatedCleanupPlanItem(
      itemRef: itemRef.toDomain(),
      displayName: displayName,
      state: state.toValidatedCleanupPlanItemState(),
      reason: reason,
    );
  }
}

extension CleanupPlanItemRefDomainMapper on CleanupPlanItemRefDto {
  CleanupPlanItemRef toDomain() {
    return CleanupPlanItemRef(
      sessionId: ScanSessionId(sessionId),
      snapshotId: SnapshotId(snapshotId),
      nodeId: NodeId(nodeId),
    );
  }
}

extension ScanTargetDtoMapper on ScanTarget {
  ScanTargetDto toDto() {
    return ScanTargetDto(
      path: path.value,
      scope: scope.toWire(),
      boundaryPolicy: boundaryPolicy.toWire(),
      hardlinkPolicy: hardlinkPolicy.toWire(),
    );
  }
}

extension PermissionProbeRequestDtoMapper on ScanTarget {
  PermissionProbeRequestDto toPermissionProbeRequestDto() {
    return PermissionProbeRequestDto(
      protocolVersion: ProtocolVersionDto.current,
      target: toDto(),
    );
  }
}

extension ChildrenPageQueryDtoMapper on ChildrenPageQuery {
  ChildrenPageRequestDto toDto() {
    return ChildrenPageRequestDto(
      snapshotId: snapshotId.value,
      parentId: parentId.value,
      cursor: cursor?.value,
      limit: limit.toString(),
      sort: sort.toWire(),
    );
  }
}

extension SearchPageQueryDtoMapper on SearchPageQuery {
  SearchPageRequestDto toDto() {
    return SearchPageRequestDto(
      snapshotId: snapshotId.value,
      searchText: searchText,
      cursor: cursor?.value,
      limit: limit.toString(),
    );
  }
}

extension TopItemsQueryDtoMapper on TopItemsQuery {
  TopItemsRequestDto toDto() {
    return TopItemsRequestDto(
      snapshotId: snapshotId.value,
      kind: kind.toWire(),
      cursor: cursor?.value,
      limit: limit.toString(),
    );
  }
}

extension NodeDetailsQueryDtoMapper on NodeDetailsQuery {
  NodeDetailsRequestDto toDto() {
    return NodeDetailsRequestDto(
      snapshotId: snapshotId.value,
      nodeId: nodeId.value,
    );
  }
}

extension ProtocolVersionDtoMapper on ProtocolVersionDto {
  ProtocolVersion toDomain() => ProtocolVersion(major: major, minor: minor);
}

extension ScanSessionStatusDtoMapper on ScanSessionStatusDto {
  ScanSessionStatus toDomain() {
    return ScanSessionStatus(
      sessionId: ScanSessionId(sessionId),
      state: state.toSessionState(),
      snapshotId: snapshotId == null ? null : SnapshotId(snapshotId!),
      rootNodeIds: rootNodeIds.map(NodeId.new).toList(),
      progress: progress?.toDomain(),
    );
  }
}

extension ScanProgressDtoMapper on ScanProgressDto {
  ScanProgress toDomain() {
    return ScanProgress(
      scannedItems: BigInt.parse(scannedItems),
      elapsedMs: elapsedMs == null ? null : BigInt.parse(elapsedMs!),
      throughputBytesPerSec: throughputBytesPerSec == null
          ? null
          : BigInt.parse(throughputBytesPerSec!),
    );
  }
}

extension NodePageResponseDtoMapper on NodePageResponseDto {
  NodePage toDomain() {
    return NodePage(
      snapshotId: SnapshotId(snapshotId),
      items: items.map((item) => item.toDomain()).toList(),
      nextCursor: nextCursor == null ? null : OpaqueCursor(nextCursor!),
    );
  }
}

extension NodePageItemDtoMapper on NodePageItemDto {
  NodePageItem toDomain() {
    return NodePageItem(
      nodeId: NodeId(nodeId),
      parentId: parentId == null ? null : NodeId(parentId!),
      name: name,
      kind: kind.toNodeKind(),
      size: size.toDomain(),
      flags: flags.toDomain(),
      childCompleteness: childCompleteness.toChildCompleteness(),
      childCount: _decimalToInt(childCount),
      issueCount: _decimalToInt(issueCount),
      subtreeIssueCount: _decimalToInt(subtreeIssueCount),
    );
  }
}

extension SizeFactDtoMapper on SizeFactDto {
  SizeFact toDomain() {
    return SizeFact(
      rawValue: rawValue,
      quantity: quantity.toMeasuredQuantity(),
      byteEquivalent: byteEquivalent,
      confidence: confidence.toSizeConfidence(),
    );
  }
}

extension NodeFlagsDtoMapper on NodeFlagsDto {
  NodeFlags toDomain() {
    return NodeFlags(
      hidden: hidden,
      system: system,
      package: package,
      symlink: symlink,
    );
  }
}

extension NodeDetailsResponseDtoMapper on NodeDetailsResponseDto {
  NodeDetails toDomain() {
    return NodeDetails(
      snapshotId: SnapshotId(snapshotId),
      summary: summary.toDomain(),
      timestamps: timestamps?.toDomain(),
      childIds: childIds.map(NodeId.new).toList(),
      issues: issues.map((issue) => issue.toDomain()).toList(),
    );
  }
}

extension NodeTimestampsDtoMapper on NodeTimestampsDto {
  NodeTimestamps toDomain() {
    return NodeTimestamps(
      createdAtUnixMs: createdAtUnixMs == null
          ? null
          : BigInt.parse(createdAtUnixMs!),
      modifiedAtUnixMs: modifiedAtUnixMs == null
          ? null
          : BigInt.parse(modifiedAtUnixMs!),
    );
  }
}

extension ScanIssueDtoMapper on ScanIssueDto {
  ScanIssue toDomain() {
    return ScanIssue(
      code: code.toIssueCode(),
      severity: severity.toIssueSeverity(),
      evidence: evidence.toDomain(),
    );
  }
}

extension IssueEvidenceDtoMapper on IssueEvidenceDto {
  IssueEvidence toDomain() {
    return IssueEvidence(
      path: path?.toDomain(),
      operation: operation,
      message: message,
    );
  }
}

extension DisplayPathDtoMapper on DisplayPathDto {
  DisplayPath toDomain() {
    return DisplayPath(text: text, privacy: privacy.toPathPrivacy());
  }
}

extension ScanEventEnvelopeDtoMapper on ScanEventEnvelopeDto {
  ScanEventEnvelope toDomain() {
    return ScanEventEnvelope(
      protocolVersion: protocolVersion.toDomain(),
      sequence: EventSequence(sequence),
      emittedAtUnixMs: BigInt.parse(emittedAtUnixMs),
      event: event.toDomain(),
    );
  }
}

extension ScanEventDtoMapper on ScanEventDto {
  ScanEvent toDomain() {
    return switch (type) {
      'started' => ScanStarted(sessionId: _requiredSessionId()),
      'progress' => ScanProgressed(
        sessionId: _requiredSessionId(),
        progress: _requiredProgress(),
      ),
      'snapshot_published' => ScanSnapshotPublished(
        sessionId: _requiredSessionId(),
        snapshotId: SnapshotId(_requiredValue(snapshotId, 'snapshotId')),
      ),
      'canceled' => ScanCanceled(sessionId: _requiredSessionId()),
      'failed' => ScanFailed(
        sessionId: _requiredSessionId(),
        message: _requiredValue(message, 'message'),
      ),
      _ => const UnknownScanEvent(),
    };
  }

  ScanSessionId _requiredSessionId() {
    return ScanSessionId(_requiredValue(sessionId, 'sessionId'));
  }

  ScanProgress _requiredProgress() {
    final value = progress;
    if (value == null) {
      throw const FormatException('Missing progress');
    }
    return value.toDomain();
  }
}

extension CapabilityResponseDtoMapper on CapabilityResponseDto {
  DaemonCapabilities toDomain() {
    return DaemonCapabilities(
      protocolVersion: protocolVersion.toDomain(),
      scanner: scanner.toDomain(),
      limits: limits.toDomain(),
      runtimeProof: runtimeProof?.toDomain() ?? RuntimeProof.unknown,
    );
  }
}

extension ScannerCapabilityDtoMapper on ScannerCapabilityDto {
  ScannerCapability toDomain() {
    return ScannerCapability(
      backendName: backendName,
      capabilities: capabilities.toDomain(),
    );
  }
}

extension CapabilitySetDtoMapper on CapabilitySetDto {
  CapabilitySet toDomain() {
    return CapabilitySet(
      hardlinks: hardlinks.toSupportLevel(),
      filesystemBoundary: filesystemBoundary.toSupportLevel(),
      cooperativeCancellation: cooperativeCancellation.toSupportLevel(),
      metadataEnrichment: metadataEnrichment.toSupportLevel(),
      growingTreeStreaming: growingTreeStreaming.toSupportLevel(),
    );
  }
}

extension RuntimeProofDtoMapper on RuntimeProofDto {
  RuntimeProof toDomain() {
    return RuntimeProof(
      scannerIdentity: scannerIdentity.toDomain(),
      permissionProbe: permissionProbe.toDomain(),
      packaging: packaging.toDomain(),
    );
  }
}

extension ScannerIdentityProofDtoMapper on ScannerIdentityProofDto {
  ScannerIdentityProof toDomain() {
    return ScannerIdentityProof(
      platform: platform.toRuntimePlatform(),
      processKind: processKind.toScannerProcessKind(),
      verification: verification.toScannerIdentityVerification(),
      executablePath: executablePath == null
          ? null
          : ScanTargetPath(executablePath!),
      bundleIdentifier: bundleIdentifier,
    );
  }
}

extension PermissionProbeDtoMapper on PermissionProbeDto {
  PermissionProbe toDomain() {
    return PermissionProbe(
      status: status.toPermissionProbeStatus(),
      checkedAtUnixMs: checkedAtUnixMs == null
          ? null
          : BigInt.parse(checkedAtUnixMs!),
      requiredAction: requiredAction.toPermissionRequiredAction(),
    );
  }
}

extension UpdateSafetyDtoMapper on UpdateSafetyDto {
  UpdateSafety toDomain() {
    return UpdateSafety(
      quiesceRequiredBeforeUpdate: quiesceRequiredBeforeUpdate,
      rollbackSupported: rollbackSupported.toSupportLevel(),
      receiptPreservation: receiptPreservation.toSupportLevel(),
    );
  }
}

extension PackagingProofDtoMapper on PackagingProofDto {
  PackagingProof toDomain() {
    return PackagingProof(
      distributionChannel: distributionChannel.toDistributionChannel(),
      packageMode: packageMode.toPackageMode(),
      sandboxed: sandboxed,
      signedBuild: signedBuild,
      debugBuild: debugBuild,
      scannerProcess: scannerProcess.toScannerProcessKind(),
      limitations: List.unmodifiable(limitations),
      updateSafety: updateSafety.toDomain(),
    );
  }
}

extension ProtocolLimitDtoMapper on ProtocolLimitDto {
  ProtocolLimits toDomain() {
    return ProtocolLimits(
      maxPageSize: _decimalToInt(maxPageSize),
      maxEventQueueItems: _decimalToInt(maxEventQueueItems),
    );
  }
}

extension DaemonDiagnosticsDtoMapper on DaemonDiagnosticsDto {
  DaemonDiagnostics toDomain() {
    return DaemonDiagnostics(
      protocolVersion: protocolVersion.toDomain(),
      activeSessions: _decimalToInt(activeSessions),
      runningSessions: _decimalToInt(runningSessions),
      completedSessions: _decimalToInt(completedSessions),
      cancelRequestedSessions: _decimalToInt(cancelRequestedSessions),
      bufferedEvents: _decimalToInt(bufferedEvents),
      storedCursors: _decimalToInt(storedCursors),
      authRequired: authRequired,
    );
  }
}

extension CleanupReceiptDtoMapper on CleanupReceiptDto {
  CleanupReceipt toDomain() {
    return CleanupReceipt(
      operationId: CommandId(operationId),
      commandId: CommandId(commandId),
      state: state.toCleanupReceiptState(),
      lowDiskReserveReady: lowDiskReserveReady,
      items: items.map((item) => item.toDomain()).toList(),
    );
  }
}

extension CleanupReceiptItemDtoMapper on CleanupReceiptItemDto {
  CleanupReceiptItem toDomain() {
    return CleanupReceiptItem(
      nodeId: NodeId(nodeId),
      displayName: displayName,
      state: state.toCleanupItemOutcomeState(),
      restoreExpectation: restoreExpectation.toRestoreExpectationLevel(),
      reason: reason,
    );
  }
}

extension CleanupRecoveryInboxDtoMapper on CleanupRecoveryInboxDto {
  CleanupRecoveryInbox toDomain() {
    return CleanupRecoveryInbox(
      interruptedReceipts: interruptedReceipts
          .map((receipt) => receipt.toDomain())
          .toList(),
    );
  }
}

extension TargetScopeWireMapper on TargetScope {
  String toWire() {
    return switch (this) {
      TargetScope.localPath => 'local_path',
      TargetScope.volume => 'volume',
      TargetScope.custom => 'custom',
      TargetScope.unknown => 'custom',
    };
  }
}

extension BoundaryPolicyWireMapper on BoundaryPolicy {
  String toWire() {
    return switch (this) {
      BoundaryPolicy.crossFilesystems => 'cross_filesystems',
      BoundaryPolicy.stayOnInitialFilesystem => 'stay_on_initial_filesystem',
      BoundaryPolicy.unknown => 'cross_filesystems',
    };
  }
}

extension HardlinkPolicyWireMapper on HardlinkPolicy {
  String toWire() {
    return switch (this) {
      HardlinkPolicy.ignore => 'ignore',
      HardlinkPolicy.detect => 'detect',
      HardlinkPolicy.deduplicateForDisplay => 'deduplicate_for_display',
      HardlinkPolicy.unknown => 'ignore',
    };
  }
}

extension MeasuredQuantityWireMapper on MeasuredQuantity {
  String toWire() {
    return switch (this) {
      MeasuredQuantity.apparentBytes => 'apparent_bytes',
      MeasuredQuantity.allocatedBytes => 'allocated_bytes',
      MeasuredQuantity.blockCount => 'block_count',
      MeasuredQuantity.unknown => 'apparent_bytes',
    };
  }
}

extension ScanModeWireMapper on ScanMode {
  String toWire() {
    return switch (this) {
      ScanMode.background => 'background',
      ScanMode.balanced => 'balanced',
      ScanMode.fast => 'fast',
      ScanMode.unknown => 'balanced',
    };
  }
}

extension ChildSortWireMapper on ChildSort {
  String toWire() {
    return switch (this) {
      ChildSort.insertion => 'insertion',
      ChildSort.nameAsc => 'name_asc',
      ChildSort.nameDesc => 'name_desc',
      ChildSort.sizeAsc => 'size_asc',
      ChildSort.sizeDesc => 'size_desc',
    };
  }
}

extension TopItemsKindWireMapper on TopItemsKind {
  String toWire() {
    return switch (this) {
      TopItemsKind.files => 'files',
      TopItemsKind.directories => 'directories',
      TopItemsKind.filesAndDirectories => 'files_and_directories',
    };
  }
}

extension StringDomainMapper on String {
  SessionState toSessionState() {
    return switch (this) {
      'created' => SessionState.created,
      'running' => SessionState.running,
      'canceled' => SessionState.canceled,
      'completed' => SessionState.completed,
      'failed' => SessionState.failed,
      _ => SessionState.unknown,
    };
  }

  NodeKind toNodeKind() {
    return switch (this) {
      'file' => NodeKind.file,
      'directory' => NodeKind.directory,
      'symlink' => NodeKind.symlink,
      'other' => NodeKind.other,
      _ => NodeKind.unknown,
    };
  }

  ChildCompleteness toChildCompleteness() {
    return switch (this) {
      'complete' => ChildCompleteness.complete,
      'collapsed_by_depth' => ChildCompleteness.collapsedByDepth,
      'collapsed_by_projection' => ChildCompleteness.collapsedByProjection,
      'skipped_by_boundary' => ChildCompleteness.skippedByBoundary,
      'incomplete_due_to_issue' => ChildCompleteness.incompleteDueToIssue,
      _ => ChildCompleteness.unknown,
    };
  }

  MeasuredQuantity toMeasuredQuantity() {
    return switch (this) {
      'apparent_bytes' => MeasuredQuantity.apparentBytes,
      'allocated_bytes' => MeasuredQuantity.allocatedBytes,
      'block_count' => MeasuredQuantity.blockCount,
      _ => MeasuredQuantity.unknown,
    };
  }

  SizeConfidence toSizeConfidence() {
    return switch (this) {
      'exact' => SizeConfidence.exact,
      'high' => SizeConfidence.high,
      'medium' => SizeConfidence.medium,
      'low' => SizeConfidence.low,
      _ => SizeConfidence.unknown,
    };
  }

  PathPrivacy toPathPrivacy() {
    return switch (this) {
      'raw' => PathPrivacy.raw,
      'redacted' => PathPrivacy.redacted,
      'unavailable' => PathPrivacy.unavailable,
      _ => PathPrivacy.unknown,
    };
  }

  IssueCode toIssueCode() {
    return switch (this) {
      'permission_denied' => IssueCode.permissionDenied,
      'metadata_unavailable' => IssueCode.metadataUnavailable,
      'read_directory_failed' => IssueCode.readDirectoryFailed,
      'access_entry_failed' => IssueCode.accessEntryFailed,
      'boundary_skipped' => IssueCode.boundarySkipped,
      'non_utf8_path' => IssueCode.nonUtf8Path,
      'backend_limitation' => IssueCode.backendLimitation,
      _ => IssueCode.unknown,
    };
  }

  IssueSeverity toIssueSeverity() {
    return switch (this) {
      'info' => IssueSeverity.info,
      'warning' => IssueSeverity.warning,
      'error' => IssueSeverity.error,
      _ => IssueSeverity.unknown,
    };
  }

  SupportLevel toSupportLevel() {
    return switch (this) {
      'supported' => SupportLevel.supported,
      'unsupported' => SupportLevel.unsupported,
      _ => SupportLevel.unknown,
    };
  }

  RuntimePlatform toRuntimePlatform() {
    return switch (this) {
      'macos' => RuntimePlatform.macos,
      'windows' => RuntimePlatform.windows,
      'linux' => RuntimePlatform.linux,
      _ => RuntimePlatform.unknown,
    };
  }

  ScannerProcessKind toScannerProcessKind() {
    return switch (this) {
      'app_bundle' => ScannerProcessKind.appBundle,
      'bundled_helper' => ScannerProcessKind.bundledHelper,
      'current_process' => ScannerProcessKind.currentProcess,
      'external_process' => ScannerProcessKind.externalProcess,
      _ => ScannerProcessKind.unknown,
    };
  }

  ScannerIdentityVerification toScannerIdentityVerification() {
    return switch (this) {
      'verified' => ScannerIdentityVerification.verified,
      'unverified' => ScannerIdentityVerification.unverified,
      _ => ScannerIdentityVerification.unknown,
    };
  }

  PermissionProbeStatus toPermissionProbeStatus() {
    return switch (this) {
      'verified' => PermissionProbeStatus.verified,
      'denied' => PermissionProbeStatus.denied,
      'not_determined' => PermissionProbeStatus.notDetermined,
      'not_probed' => PermissionProbeStatus.notProbed,
      'degraded' => PermissionProbeStatus.degraded,
      'unsupported' => PermissionProbeStatus.unsupported,
      _ => PermissionProbeStatus.unknown,
    };
  }

  PermissionRequiredAction toPermissionRequiredAction() {
    return switch (this) {
      'none' => PermissionRequiredAction.none,
      'open_macos_full_disk_access' =>
        PermissionRequiredAction.openMacosFullDiskAccess,
      'run_as_administrator' => PermissionRequiredAction.runAsAdministrator,
      'review_linux_permissions' =>
        PermissionRequiredAction.reviewLinuxPermissions,
      _ => PermissionRequiredAction.unknown,
    };
  }

  DistributionChannel toDistributionChannel() {
    return switch (this) {
      'development' => DistributionChannel.development,
      'direct' => DistributionChannel.direct,
      'mac_app_store' => DistributionChannel.macAppStore,
      'windows_store' => DistributionChannel.windowsStore,
      'package_manager' => DistributionChannel.packageManager,
      _ => DistributionChannel.unknown,
    };
  }

  PackageMode toPackageMode() {
    return switch (this) {
      'development_shell' => PackageMode.developmentShell,
      'app_bundle' => PackageMode.appBundle,
      'bundled_daemon' => PackageMode.bundledDaemon,
      'system_service' => PackageMode.systemService,
      'portable' => PackageMode.portable,
      _ => PackageMode.unknown,
    };
  }

  CleanupReceiptState toCleanupReceiptState() {
    return switch (this) {
      'intent_recorded' => CleanupReceiptState.intentRecorded,
      'receipt_skeleton_recorded' =>
        CleanupReceiptState.receiptSkeletonRecorded,
      'running' => CleanupReceiptState.running,
      'completed' => CleanupReceiptState.completed,
      'completed_with_failures' => CleanupReceiptState.completedWithFailures,
      'interrupted_requires_review' =>
        CleanupReceiptState.interruptedRequiresReview,
      'completed_with_unknowns' => CleanupReceiptState.completedWithUnknowns,
      'failed_before_dispatch' => CleanupReceiptState.failedBeforeDispatch,
      _ => CleanupReceiptState.unknown,
    };
  }

  CleanupItemOutcomeState toCleanupItemOutcomeState() {
    return switch (this) {
      'pending' => CleanupItemOutcomeState.pending,
      'dispatch_recorded' => CleanupItemOutcomeState.dispatchRecorded,
      'moved_to_trash' => CleanupItemOutcomeState.movedToTrash,
      'blocked' => CleanupItemOutcomeState.blocked,
      'failed' => CleanupItemOutcomeState.failed,
      'unknown_requires_review' =>
        CleanupItemOutcomeState.unknownRequiresReview,
      _ => CleanupItemOutcomeState.unknown,
    };
  }

  ValidatedCleanupPlanState toValidatedCleanupPlanState() {
    return switch (this) {
      'ready' => ValidatedCleanupPlanState.ready,
      'blocked' => ValidatedCleanupPlanState.blocked,
      _ => ValidatedCleanupPlanState.unknown,
    };
  }

  ValidatedCleanupPlanItemState toValidatedCleanupPlanItemState() {
    return switch (this) {
      'ready' => ValidatedCleanupPlanItemState.ready,
      'blocked' => ValidatedCleanupPlanItemState.blocked,
      _ => ValidatedCleanupPlanItemState.unknown,
    };
  }

  RestoreExpectationLevel toRestoreExpectationLevel() {
    return switch (this) {
      'platform_trash_manual' => RestoreExpectationLevel.platformTrashManual,
      'not_restorable' => RestoreExpectationLevel.notRestorable,
      'unsupported' => RestoreExpectationLevel.unsupported,
      _ => RestoreExpectationLevel.unknown,
    };
  }
}

String _requiredValue(String? value, String field) {
  if (value == null) {
    throw FormatException('Missing $field');
  }
  return value;
}

int _decimalToInt(String value) {
  return int.parse(value);
}

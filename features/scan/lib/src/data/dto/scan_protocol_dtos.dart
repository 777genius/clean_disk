final class ProtocolVersionDto {
  const ProtocolVersionDto({required this.major, required this.minor});

  static const current = ProtocolVersionDto(major: 0, minor: 5);

  final int major;
  final int minor;

  factory ProtocolVersionDto.fromJson(Map<String, Object?> json) {
    return ProtocolVersionDto(
      major: _intField(json, 'major'),
      minor: _intField(json, 'minor'),
    );
  }

  Map<String, Object?> toJson() => {'major': major, 'minor': minor};
}

final class ScanTargetDto {
  const ScanTargetDto({
    required this.path,
    required this.scope,
    required this.boundaryPolicy,
    required this.hardlinkPolicy,
  });

  final String path;
  final String scope;
  final String boundaryPolicy;
  final String hardlinkPolicy;

  Map<String, Object?> toJson() {
    return {
      'path': path,
      'scope': scope,
      'boundaryPolicy': boundaryPolicy,
      'hardlinkPolicy': hardlinkPolicy,
    };
  }
}

final class StartScanRequestDto {
  const StartScanRequestDto({
    required this.protocolVersion,
    required this.commandId,
    required this.targets,
    required this.measurement,
    required this.mode,
  });

  final ProtocolVersionDto protocolVersion;
  final String commandId;
  final List<ScanTargetDto> targets;
  final String measurement;
  final String mode;

  Map<String, Object?> toJson() {
    return {
      'protocolVersion': protocolVersion.toJson(),
      'commandId': commandId,
      'targets': targets.map((target) => target.toJson()).toList(),
      'measurement': measurement,
      'mode': mode,
    };
  }
}

final class PermissionProbeRequestDto {
  const PermissionProbeRequestDto({
    required this.protocolVersion,
    required this.target,
  });

  final ProtocolVersionDto protocolVersion;
  final ScanTargetDto target;

  Map<String, Object?> toJson() {
    return {
      'protocolVersion': protocolVersion.toJson(),
      'target': target.toJson(),
    };
  }
}

final class SessionCommandRequestDto {
  const SessionCommandRequestDto({
    required this.protocolVersion,
    required this.commandId,
    required this.sessionId,
  });

  final ProtocolVersionDto protocolVersion;
  final String commandId;
  final String sessionId;

  Map<String, Object?> toJson() {
    return {
      'protocolVersion': protocolVersion.toJson(),
      'commandId': commandId,
      'sessionId': sessionId,
    };
  }
}

final class CleanupPlanItemRefDto {
  const CleanupPlanItemRefDto({
    required this.sessionId,
    required this.snapshotId,
    required this.nodeId,
  });

  final String sessionId;
  final String snapshotId;
  final String nodeId;

  Map<String, Object?> toJson() {
    return {'sessionId': sessionId, 'snapshotId': snapshotId, 'nodeId': nodeId};
  }

  factory CleanupPlanItemRefDto.fromJson(Map<String, Object?> json) {
    return CleanupPlanItemRefDto(
      sessionId: _decimalField(json, 'sessionId'),
      snapshotId: _decimalField(json, 'snapshotId'),
      nodeId: _decimalField(json, 'nodeId'),
    );
  }
}

final class CreateCleanupPlanRequestDto {
  const CreateCleanupPlanRequestDto({
    required this.protocolVersion,
    required this.commandId,
    required this.items,
  });

  final ProtocolVersionDto protocolVersion;
  final String commandId;
  final List<CleanupPlanItemRefDto> items;

  Map<String, Object?> toJson() {
    return {
      'protocolVersion': protocolVersion.toJson(),
      'commandId': commandId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

final class CleanupPlanItemDto {
  const CleanupPlanItemDto({
    required this.itemRef,
    required this.displayName,
    required this.state,
    required this.reason,
  });

  final CleanupPlanItemRefDto itemRef;
  final String displayName;
  final String state;
  final String? reason;

  factory CleanupPlanItemDto.fromJson(Map<String, Object?> json) {
    return CleanupPlanItemDto(
      itemRef: CleanupPlanItemRefDto.fromJson(_objectField(json, 'itemRef')),
      displayName: _stringField(json, 'displayName'),
      state: _stringField(json, 'state'),
      reason: _optionalStringField(json, 'reason'),
    );
  }
}

final class CleanupPlanDto {
  const CleanupPlanDto({
    required this.planId,
    required this.commandId,
    required this.state,
    required this.items,
  });

  final String planId;
  final String commandId;
  final String state;
  final List<CleanupPlanItemDto> items;

  factory CleanupPlanDto.fromJson(Map<String, Object?> json) {
    return CleanupPlanDto(
      planId: _decimalField(json, 'planId'),
      commandId: _decimalField(json, 'commandId'),
      state: _stringField(json, 'state'),
      items: _objectListField(json, 'items', CleanupPlanItemDto.fromJson),
    );
  }
}

final class ExecuteCleanupPlanRequestDto {
  const ExecuteCleanupPlanRequestDto({
    required this.protocolVersion,
    required this.commandId,
    required this.planId,
  });

  final ProtocolVersionDto protocolVersion;
  final String commandId;
  final String planId;

  Map<String, Object?> toJson() {
    return {
      'protocolVersion': protocolVersion.toJson(),
      'commandId': commandId,
      'planId': planId,
    };
  }
}

final class CleanupReceiptItemDto {
  const CleanupReceiptItemDto({
    required this.nodeId,
    required this.displayName,
    required this.state,
    required this.restoreExpectation,
    required this.reason,
  });

  final String nodeId;
  final String displayName;
  final String state;
  final String restoreExpectation;
  final String? reason;

  factory CleanupReceiptItemDto.fromJson(Map<String, Object?> json) {
    return CleanupReceiptItemDto(
      nodeId: _decimalField(json, 'nodeId'),
      displayName: _stringField(json, 'displayName'),
      state: _stringField(json, 'state'),
      restoreExpectation: _stringField(json, 'restoreExpectation'),
      reason: _optionalStringField(json, 'reason'),
    );
  }
}

final class CleanupReceiptDto {
  const CleanupReceiptDto({
    required this.operationId,
    required this.commandId,
    required this.state,
    required this.lowDiskReserveReady,
    required this.items,
  });

  final String operationId;
  final String commandId;
  final String state;
  final bool lowDiskReserveReady;
  final List<CleanupReceiptItemDto> items;

  factory CleanupReceiptDto.fromJson(Map<String, Object?> json) {
    return CleanupReceiptDto(
      operationId: _decimalField(json, 'operationId'),
      commandId: _decimalField(json, 'commandId'),
      state: _stringField(json, 'state'),
      lowDiskReserveReady: _boolField(json, 'lowDiskReserveReady'),
      items: _objectListField(json, 'items', CleanupReceiptItemDto.fromJson),
    );
  }
}

final class CleanupRecoveryInboxDto {
  const CleanupRecoveryInboxDto({required this.interruptedReceipts});

  final List<CleanupReceiptDto> interruptedReceipts;

  factory CleanupRecoveryInboxDto.fromJson(Map<String, Object?> json) {
    return CleanupRecoveryInboxDto(
      interruptedReceipts: _objectListField(
        json,
        'interruptedReceipts',
        CleanupReceiptDto.fromJson,
      ),
    );
  }
}

final class ChildrenPageRequestDto {
  const ChildrenPageRequestDto({
    required this.snapshotId,
    required this.parentId,
    required this.cursor,
    required this.limit,
    required this.sort,
  });

  final String snapshotId;
  final String parentId;
  final String? cursor;
  final String limit;
  final String sort;

  Map<String, Object?> toJson() {
    return {
      'snapshotId': snapshotId,
      'parentId': parentId,
      'cursor': cursor,
      'limit': limit,
      'sort': sort,
    };
  }
}

final class SearchPageRequestDto {
  const SearchPageRequestDto({
    required this.snapshotId,
    required this.searchText,
    required this.cursor,
    required this.limit,
  });

  final String snapshotId;
  final String searchText;
  final String? cursor;
  final String limit;

  Map<String, Object?> toJson() {
    return {
      'snapshotId': snapshotId,
      'searchText': searchText,
      'cursor': cursor,
      'limit': limit,
    };
  }
}

final class TopItemsRequestDto {
  const TopItemsRequestDto({
    required this.snapshotId,
    required this.kind,
    required this.cursor,
    required this.limit,
  });

  final String snapshotId;
  final String kind;
  final String? cursor;
  final String limit;

  Map<String, Object?> toJson() {
    return {
      'snapshotId': snapshotId,
      'kind': kind,
      'cursor': cursor,
      'limit': limit,
    };
  }
}

final class NodeDetailsRequestDto {
  const NodeDetailsRequestDto({required this.snapshotId, required this.nodeId});

  final String snapshotId;
  final String nodeId;

  Map<String, Object?> toJson() {
    return {'snapshotId': snapshotId, 'nodeId': nodeId};
  }
}

final class ScanProgressDto {
  const ScanProgressDto({
    required this.scannedItems,
    required this.elapsedMs,
    required this.throughputBytesPerSec,
  });

  final String scannedItems;
  final String? elapsedMs;
  final String? throughputBytesPerSec;

  factory ScanProgressDto.fromJson(Map<String, Object?> json) {
    return ScanProgressDto(
      scannedItems: _decimalField(json, 'scannedItems'),
      elapsedMs: _optionalDecimalField(json, 'elapsedMs'),
      throughputBytesPerSec: _optionalDecimalField(
        json,
        'throughputBytesPerSec',
      ),
    );
  }
}

final class ScanSessionStatusDto {
  const ScanSessionStatusDto({
    required this.sessionId,
    required this.state,
    required this.snapshotId,
    required this.rootNodeIds,
    required this.progress,
  });

  final String sessionId;
  final String state;
  final String? snapshotId;
  final List<String> rootNodeIds;
  final ScanProgressDto? progress;

  factory ScanSessionStatusDto.fromJson(Map<String, Object?> json) {
    return ScanSessionStatusDto(
      sessionId: _decimalField(json, 'sessionId'),
      state: _stringField(json, 'state'),
      snapshotId: _optionalDecimalField(json, 'snapshotId'),
      rootNodeIds: _decimalListField(json, 'rootNodeIds'),
      progress: _optionalObject(json, 'progress', ScanProgressDto.fromJson),
    );
  }
}

final class SizeFactDto {
  const SizeFactDto({
    required this.rawValue,
    required this.quantity,
    required this.byteEquivalent,
    required this.confidence,
  });

  final String rawValue;
  final String quantity;
  final String? byteEquivalent;
  final String confidence;

  factory SizeFactDto.fromJson(Map<String, Object?> json) {
    return SizeFactDto(
      rawValue: _decimalField(json, 'rawValue'),
      quantity: _stringField(json, 'quantity'),
      byteEquivalent: _optionalDecimalField(json, 'byteEquivalent'),
      confidence: _stringField(json, 'confidence'),
    );
  }
}

final class NodeFlagsDto {
  const NodeFlagsDto({
    required this.hidden,
    required this.system,
    required this.package,
    required this.symlink,
  });

  final bool hidden;
  final bool system;
  final bool package;
  final bool symlink;

  factory NodeFlagsDto.fromJson(Map<String, Object?> json) {
    return NodeFlagsDto(
      hidden: _boolField(json, 'hidden'),
      system: _boolField(json, 'system'),
      package: _boolField(json, 'package'),
      symlink: _boolField(json, 'symlink'),
    );
  }
}

final class NodePageItemDto {
  const NodePageItemDto({
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

  final String nodeId;
  final String? parentId;
  final String name;
  final String kind;
  final SizeFactDto size;
  final NodeFlagsDto flags;
  final String childCompleteness;
  final String childCount;
  final String issueCount;
  final String subtreeIssueCount;

  factory NodePageItemDto.fromJson(Map<String, Object?> json) {
    return NodePageItemDto(
      nodeId: _decimalField(json, 'nodeId'),
      parentId: _optionalDecimalField(json, 'parentId'),
      name: _stringField(json, 'name'),
      kind: _stringField(json, 'kind'),
      size: SizeFactDto.fromJson(_objectField(json, 'size')),
      flags: NodeFlagsDto.fromJson(_objectField(json, 'flags')),
      childCompleteness: _stringField(json, 'childCompleteness'),
      childCount: _decimalField(json, 'childCount'),
      issueCount: _decimalField(json, 'issueCount'),
      subtreeIssueCount: _decimalField(json, 'subtreeIssueCount'),
    );
  }
}

final class NodePageResponseDto {
  const NodePageResponseDto({
    required this.snapshotId,
    required this.items,
    required this.nextCursor,
  });

  final String snapshotId;
  final List<NodePageItemDto> items;
  final String? nextCursor;

  factory NodePageResponseDto.fromJson(Map<String, Object?> json) {
    return NodePageResponseDto(
      snapshotId: _decimalField(json, 'snapshotId'),
      items: _objectListField(json, 'items', NodePageItemDto.fromJson),
      nextCursor: _optionalStringField(json, 'nextCursor'),
    );
  }
}

final class DisplayPathDto {
  const DisplayPathDto({required this.text, required this.privacy});

  final String text;
  final String privacy;

  factory DisplayPathDto.fromJson(Map<String, Object?> json) {
    return DisplayPathDto(
      text: _stringField(json, 'text'),
      privacy: _stringField(json, 'privacy'),
    );
  }
}

final class IssueEvidenceDto {
  const IssueEvidenceDto({
    required this.path,
    required this.operation,
    required this.message,
  });

  final DisplayPathDto? path;
  final String? operation;
  final String? message;

  factory IssueEvidenceDto.fromJson(Map<String, Object?> json) {
    return IssueEvidenceDto(
      path: _optionalObject(json, 'path', DisplayPathDto.fromJson),
      operation: _optionalStringField(json, 'operation'),
      message: _optionalStringField(json, 'message'),
    );
  }
}

final class ScanIssueDto {
  const ScanIssueDto({
    required this.code,
    required this.severity,
    required this.evidence,
  });

  final String code;
  final String severity;
  final IssueEvidenceDto evidence;

  factory ScanIssueDto.fromJson(Map<String, Object?> json) {
    return ScanIssueDto(
      code: _stringField(json, 'code'),
      severity: _stringField(json, 'severity'),
      evidence: IssueEvidenceDto.fromJson(_objectField(json, 'evidence')),
    );
  }
}

final class NodeDetailsResponseDto {
  const NodeDetailsResponseDto({
    required this.snapshotId,
    required this.summary,
    required this.timestamps,
    required this.childIds,
    required this.issues,
  });

  final String snapshotId;
  final NodePageItemDto summary;
  final NodeTimestampsDto? timestamps;
  final List<String> childIds;
  final List<ScanIssueDto> issues;

  factory NodeDetailsResponseDto.fromJson(Map<String, Object?> json) {
    return NodeDetailsResponseDto(
      snapshotId: _decimalField(json, 'snapshotId'),
      summary: NodePageItemDto.fromJson(_objectField(json, 'summary')),
      timestamps: _optionalObject(
        json,
        'timestamps',
        NodeTimestampsDto.fromJson,
      ),
      childIds: _stringListField(json, 'childIds'),
      issues: _objectListField(json, 'issues', ScanIssueDto.fromJson),
    );
  }
}

final class NodeTimestampsDto {
  const NodeTimestampsDto({
    required this.createdAtUnixMs,
    required this.modifiedAtUnixMs,
  });

  final String? createdAtUnixMs;
  final String? modifiedAtUnixMs;

  factory NodeTimestampsDto.fromJson(Map<String, Object?> json) {
    return NodeTimestampsDto(
      createdAtUnixMs: _optionalDecimalField(json, 'createdAtUnixMs'),
      modifiedAtUnixMs: _optionalDecimalField(json, 'modifiedAtUnixMs'),
    );
  }
}

final class ScanEventEnvelopeDto {
  const ScanEventEnvelopeDto({
    required this.protocolVersion,
    required this.sequence,
    required this.emittedAtUnixMs,
    required this.event,
  });

  final ProtocolVersionDto protocolVersion;
  final String sequence;
  final String emittedAtUnixMs;
  final ScanEventDto event;

  factory ScanEventEnvelopeDto.fromJson(Map<String, Object?> json) {
    return ScanEventEnvelopeDto(
      protocolVersion: ProtocolVersionDto.fromJson(
        _objectField(json, 'protocolVersion'),
      ),
      sequence: _decimalField(json, 'sequence'),
      emittedAtUnixMs: _decimalField(json, 'emittedAtUnixMs'),
      event: ScanEventDto.fromJson(_objectField(json, 'event')),
    );
  }
}

final class ScanEventDto {
  const ScanEventDto({
    required this.type,
    required this.sessionId,
    required this.progress,
    required this.snapshotId,
    required this.message,
  });

  final String type;
  final String? sessionId;
  final ScanProgressDto? progress;
  final String? snapshotId;
  final String? message;

  factory ScanEventDto.fromJson(Map<String, Object?> json) {
    return ScanEventDto(
      type: _stringField(json, 'type'),
      sessionId: _optionalDecimalField(json, 'sessionId'),
      progress: _optionalObject(json, 'progress', ScanProgressDto.fromJson),
      snapshotId: _optionalDecimalField(json, 'snapshotId'),
      message: _optionalStringField(json, 'message'),
    );
  }
}

final class CapabilitySetDto {
  const CapabilitySetDto({
    required this.hardlinks,
    required this.filesystemBoundary,
    required this.cooperativeCancellation,
    required this.metadataEnrichment,
    required this.growingTreeStreaming,
  });

  final String hardlinks;
  final String filesystemBoundary;
  final String cooperativeCancellation;
  final String metadataEnrichment;
  final String growingTreeStreaming;

  factory CapabilitySetDto.fromJson(Map<String, Object?> json) {
    return CapabilitySetDto(
      hardlinks: _stringField(json, 'hardlinks'),
      filesystemBoundary: _stringField(json, 'filesystemBoundary'),
      cooperativeCancellation: _stringField(json, 'cooperativeCancellation'),
      metadataEnrichment: _stringField(json, 'metadataEnrichment'),
      growingTreeStreaming:
          _optionalStringField(json, 'growingTreeStreaming') ?? 'unknown',
    );
  }
}

final class ScannerCapabilityDto {
  const ScannerCapabilityDto({
    required this.backendName,
    required this.capabilities,
  });

  final String backendName;
  final CapabilitySetDto capabilities;

  factory ScannerCapabilityDto.fromJson(Map<String, Object?> json) {
    return ScannerCapabilityDto(
      backendName: _stringField(json, 'backendName'),
      capabilities: CapabilitySetDto.fromJson(
        _objectField(json, 'capabilities'),
      ),
    );
  }
}

final class ScannerIdentityProofDto {
  const ScannerIdentityProofDto({
    required this.platform,
    required this.processKind,
    required this.verification,
    required this.executablePath,
    required this.bundleIdentifier,
  });

  final String platform;
  final String processKind;
  final String verification;
  final String? executablePath;
  final String? bundleIdentifier;

  factory ScannerIdentityProofDto.fromJson(Map<String, Object?> json) {
    return ScannerIdentityProofDto(
      platform: _stringField(json, 'platform'),
      processKind: _stringField(json, 'processKind'),
      verification: _stringField(json, 'verification'),
      executablePath: _optionalStringField(json, 'executablePath'),
      bundleIdentifier: _optionalStringField(json, 'bundleIdentifier'),
    );
  }
}

final class PermissionProbeDto {
  const PermissionProbeDto({
    required this.status,
    required this.checkedAtUnixMs,
    required this.requiredAction,
  });

  final String status;
  final String? checkedAtUnixMs;
  final String requiredAction;

  factory PermissionProbeDto.fromJson(Map<String, Object?> json) {
    return PermissionProbeDto(
      status: _stringField(json, 'status'),
      checkedAtUnixMs: _optionalDecimalField(json, 'checkedAtUnixMs'),
      requiredAction: _stringField(json, 'requiredAction'),
    );
  }
}

final class UpdateSafetyDto {
  const UpdateSafetyDto({
    required this.quiesceRequiredBeforeUpdate,
    required this.rollbackSupported,
    required this.receiptPreservation,
  });

  final bool quiesceRequiredBeforeUpdate;
  final String rollbackSupported;
  final String receiptPreservation;

  factory UpdateSafetyDto.fromJson(Map<String, Object?> json) {
    return UpdateSafetyDto(
      quiesceRequiredBeforeUpdate: _boolField(
        json,
        'quiesceRequiredBeforeUpdate',
      ),
      rollbackSupported: _stringField(json, 'rollbackSupported'),
      receiptPreservation: _stringField(json, 'receiptPreservation'),
    );
  }
}

final class PackagingProofDto {
  const PackagingProofDto({
    required this.distributionChannel,
    required this.packageMode,
    required this.sandboxed,
    required this.signedBuild,
    required this.debugBuild,
    required this.scannerProcess,
    required this.limitations,
    required this.updateSafety,
  });

  final String distributionChannel;
  final String packageMode;
  final bool sandboxed;
  final bool signedBuild;
  final bool debugBuild;
  final String scannerProcess;
  final List<String> limitations;
  final UpdateSafetyDto updateSafety;

  factory PackagingProofDto.fromJson(Map<String, Object?> json) {
    return PackagingProofDto(
      distributionChannel: _stringField(json, 'distributionChannel'),
      packageMode: _stringField(json, 'packageMode'),
      sandboxed: _boolField(json, 'sandboxed'),
      signedBuild: _boolField(json, 'signedBuild'),
      debugBuild: _boolField(json, 'debugBuild'),
      scannerProcess: _stringField(json, 'scannerProcess'),
      limitations: _stringListField(json, 'limitations'),
      updateSafety: UpdateSafetyDto.fromJson(
        _objectField(json, 'updateSafety'),
      ),
    );
  }
}

final class RuntimeProofDto {
  const RuntimeProofDto({
    required this.scannerIdentity,
    required this.permissionProbe,
    required this.packaging,
  });

  final ScannerIdentityProofDto scannerIdentity;
  final PermissionProbeDto permissionProbe;
  final PackagingProofDto packaging;

  factory RuntimeProofDto.fromJson(Map<String, Object?> json) {
    return RuntimeProofDto(
      scannerIdentity: ScannerIdentityProofDto.fromJson(
        _objectField(json, 'scannerIdentity'),
      ),
      permissionProbe: PermissionProbeDto.fromJson(
        _objectField(json, 'permissionProbe'),
      ),
      packaging: PackagingProofDto.fromJson(_objectField(json, 'packaging')),
    );
  }
}

final class ProtocolLimitDto {
  const ProtocolLimitDto({
    required this.maxPageSize,
    required this.maxEventQueueItems,
  });

  final String maxPageSize;
  final String maxEventQueueItems;

  factory ProtocolLimitDto.fromJson(Map<String, Object?> json) {
    return ProtocolLimitDto(
      maxPageSize: _decimalField(json, 'maxPageSize'),
      maxEventQueueItems: _decimalField(json, 'maxEventQueueItems'),
    );
  }
}

final class CapabilityResponseDto {
  const CapabilityResponseDto({
    required this.protocolVersion,
    required this.scanner,
    required this.limits,
    required this.runtimeProof,
  });

  final ProtocolVersionDto protocolVersion;
  final ScannerCapabilityDto scanner;
  final ProtocolLimitDto limits;
  final RuntimeProofDto? runtimeProof;

  factory CapabilityResponseDto.fromJson(Map<String, Object?> json) {
    return CapabilityResponseDto(
      protocolVersion: ProtocolVersionDto.fromJson(
        _objectField(json, 'protocolVersion'),
      ),
      scanner: ScannerCapabilityDto.fromJson(_objectField(json, 'scanner')),
      limits: ProtocolLimitDto.fromJson(_objectField(json, 'limits')),
      runtimeProof: _optionalObject(
        json,
        'runtimeProof',
        RuntimeProofDto.fromJson,
      ),
    );
  }
}

final class DaemonDiagnosticsDto {
  const DaemonDiagnosticsDto({
    required this.protocolVersion,
    required this.activeSessions,
    required this.runningSessions,
    required this.completedSessions,
    required this.cancelRequestedSessions,
    required this.bufferedEvents,
    required this.storedCursors,
    required this.authRequired,
  });

  final ProtocolVersionDto protocolVersion;
  final String activeSessions;
  final String runningSessions;
  final String completedSessions;
  final String cancelRequestedSessions;
  final String bufferedEvents;
  final String storedCursors;
  final bool authRequired;

  factory DaemonDiagnosticsDto.fromJson(Map<String, Object?> json) {
    return DaemonDiagnosticsDto(
      protocolVersion: ProtocolVersionDto.fromJson(
        _objectField(json, 'protocolVersion'),
      ),
      activeSessions: _decimalField(json, 'activeSessions'),
      runningSessions: _decimalField(json, 'runningSessions'),
      completedSessions: _decimalField(json, 'completedSessions'),
      cancelRequestedSessions: _decimalField(json, 'cancelRequestedSessions'),
      bufferedEvents: _decimalField(json, 'bufferedEvents'),
      storedCursors: _decimalField(json, 'storedCursors'),
      authRequired: _boolField(json, 'authRequired'),
    );
  }
}

Map<String, Object?> parseJsonObject(Object? data) {
  if (data is Map<String, Object?>) {
    return data;
  }
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const FormatException('Expected JSON object');
}

Map<String, Object?> _objectField(Map<String, Object?> json, String key) {
  return parseJsonObject(_requiredField(json, key));
}

T? _optionalObject<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?> json) fromJson,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  return fromJson(parseJsonObject(value));
}

List<T> _objectListField<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?> json) fromJson,
) {
  final value = _requiredField(json, key);
  if (value is! List) {
    throw FormatException('Expected list field $key');
  }
  return value.map((item) => fromJson(parseJsonObject(item))).toList();
}

List<String> _stringListField(Map<String, Object?> json, String key) {
  final value = _requiredField(json, key);
  if (value is! List) {
    throw FormatException('Expected list field $key');
  }
  return value.map((item) {
    if (item is! String) {
      throw FormatException('Expected string item in $key');
    }
    return item;
  }).toList();
}

List<String> _decimalListField(Map<String, Object?> json, String key) {
  final values = _stringListField(json, key);
  for (final value in values) {
    _validateDecimal(value, key);
  }
  return values;
}

Object? _requiredField(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing required field $key');
  }
  return json[key];
}

String _stringField(Map<String, Object?> json, String key) {
  final value = _requiredField(json, key);
  if (value is! String) {
    throw FormatException('Expected string field $key');
  }
  return value;
}

String? _optionalStringField(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Expected optional string field $key');
  }
  return value;
}

String _decimalField(Map<String, Object?> json, String key) {
  final value = _stringField(json, key);
  _validateDecimal(value, key);
  return value;
}

String? _optionalDecimalField(Map<String, Object?> json, String key) {
  final value = _optionalStringField(json, key);
  if (value == null) {
    return null;
  }
  _validateDecimal(value, key);
  return value;
}

int _intField(Map<String, Object?> json, String key) {
  final value = _requiredField(json, key);
  if (value is! int) {
    throw FormatException('Expected int field $key');
  }
  return value;
}

bool _boolField(Map<String, Object?> json, String key) {
  final value = _requiredField(json, key);
  if (value is! bool) {
    throw FormatException('Expected bool field $key');
  }
  return value;
}

void _validateDecimal(String value, String field) {
  if (value.isEmpty || value.codeUnits.any((unit) => unit < 48 || unit > 57)) {
    throw FormatException('Expected decimal string field $field');
  }
}

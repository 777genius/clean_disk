part of 'scan_home_page.dart';

String _targetDisplayName(ScanTarget target) {
  final parts = target.path.value
      .split(RegExp(r'[/\\]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return target.path.value;
  }
  return parts.last;
}

String _targetChoiceLabel(
  CleanDiskLocalizations l10n,
  ScanTargetChoice choice,
) {
  return switch (choice.kind) {
    ScanTargetChoiceKind.home => l10n.targetHome,
    ScanTargetChoiceKind.downloads => l10n.targetDownloads,
    ScanTargetChoiceKind.library => l10n.targetLibrary,
    ScanTargetChoiceKind.applications => l10n.targetApplications,
    ScanTargetChoiceKind.root => l10n.targetRoot,
    ScanTargetChoiceKind.volume =>
      choice.displayName.isEmpty ? l10n.targetVolume : choice.displayName,
  };
}

IconData _targetChoiceIcon(ScanTargetChoiceKind kind) {
  return switch (kind) {
    ScanTargetChoiceKind.home => Icons.home_outlined,
    ScanTargetChoiceKind.downloads => Icons.download_outlined,
    ScanTargetChoiceKind.library => Icons.folder_special_outlined,
    ScanTargetChoiceKind.applications => Icons.apps_outlined,
    ScanTargetChoiceKind.root => Icons.storage_outlined,
    ScanTargetChoiceKind.volume => Icons.dns_outlined,
  };
}

String _displayPathForSelection({
  required ScanWorkspaceStore store,
  required ScanTarget target,
  required NodePageItem selected,
}) {
  final parts = _knownTreePathParts(store, selected.nodeId);
  if (parts.isEmpty) {
    return _joinDisplayPath(target.path.value, ['...', selected.name]);
  }
  return _joinDisplayPath(
    target.path.value,
    _pathPartsRelativeToTarget(target.path.value, parts),
  );
}

List<String> _knownTreePathParts(ScanWorkspaceStore store, NodeId nodeId) {
  final visibleParts = _visibleTreePathParts(store, nodeId);
  if (visibleParts.isNotEmpty) {
    return visibleParts;
  }

  final rowsById = <NodeId, NodePageItem>{};
  for (final row in store.visibleTreeRows) {
    rowsById[row.item.nodeId] = row.item;
  }
  for (final row in store.visibleRows) {
    rowsById.putIfAbsent(row.nodeId, () => row);
  }
  for (final row in store.diskUsageMapAllRows) {
    rowsById.putIfAbsent(row.nodeId, () => row);
  }

  final selected = rowsById[nodeId];
  if (selected == null) {
    return const [];
  }

  final parts = <String>[];
  var current = selected;
  final treeRootParentId = store.viewport.parentId;
  final visited = <NodeId>{};
  while (visited.add(current.nodeId)) {
    parts.add(current.name);
    final parentId = current.parentId;
    if (parentId == null || parentId == treeRootParentId) {
      break;
    }
    final parent = rowsById[parentId];
    if (parent == null) {
      return const [];
    }
    current = parent;
  }
  return parts.reversed.toList(growable: false);
}

List<String> _visibleTreePathParts(ScanWorkspaceStore store, NodeId nodeId) {
  final rowsById = <NodeId, ScanTreeNodeRow>{
    for (final row in store.visibleTreeRows) row.item.nodeId: row,
  };
  final selectedRow = rowsById[nodeId];
  if (selectedRow == null) {
    return const [];
  }

  final parts = <String>[];
  var current = selectedRow.item;
  final treeRootParentId = store.viewport.parentId;
  while (true) {
    parts.add(current.name);
    final parentId = current.parentId;
    if (parentId == null || parentId == treeRootParentId) {
      break;
    }
    final parent = rowsById[parentId];
    if (parent == null) {
      break;
    }
    current = parent.item;
  }
  return parts.reversed.toList(growable: false);
}

List<String> _pathPartsRelativeToTarget(String basePath, List<String> parts) {
  final baseParts = basePath
      .split(RegExp(r'[/\\]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (baseParts.isEmpty || parts.isEmpty) {
    return parts;
  }

  final maxOverlap = baseParts.length < parts.length
      ? baseParts.length
      : parts.length;
  for (var length = maxOverlap; length > 0; length -= 1) {
    final baseSuffix = baseParts.sublist(baseParts.length - length);
    final pathPrefix = parts.take(length).toList(growable: false);
    if (_samePathParts(baseSuffix, pathPrefix)) {
      return parts.skip(length).toList(growable: false);
    }
  }
  return parts;
}

bool _samePathParts(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _joinDisplayPath(String basePath, List<String> parts) {
  final normalizedBase = basePath == '/'
      ? '/'
      : basePath.replaceAll(RegExp(r'[/\\]+$'), '');
  final suffix = parts.where((part) => part.isNotEmpty).join('/');
  if (suffix.isEmpty) {
    return normalizedBase;
  }
  if (normalizedBase == '/') {
    return '/$suffix';
  }
  return '$normalizedBase/$suffix';
}

bool _isRevealableDisplayPath(String path) {
  if (path.trim().isEmpty) {
    return false;
  }
  return !path
      .split(RegExp(r'[/\\]+'))
      .where((part) {
        return part.isNotEmpty;
      })
      .any((part) => part.contains('...') || part.contains('…'));
}

String _nodeKindText(CleanDiskLocalizations l10n, NodeKind kind) {
  return switch (kind) {
    NodeKind.file => l10n.nodeTypeFile,
    NodeKind.directory => l10n.nodeTypeDirectory,
    NodeKind.symlink => l10n.nodeTypeSymlink,
    NodeKind.other => l10n.nodeTypeOther,
    NodeKind.unknown => l10n.nodeTypeUnknown,
  };
}

IconData _nodeKindIcon(NodeKind kind) {
  return switch (kind) {
    NodeKind.file => Icons.insert_drive_file_outlined,
    NodeKind.directory => Icons.folder_outlined,
    NodeKind.symlink => Icons.link_outlined,
    NodeKind.other => Icons.storage_outlined,
    NodeKind.unknown => Icons.help_outline,
  };
}

String _sizeQuantityText(
  CleanDiskLocalizations l10n,
  MeasuredQuantity quantity,
) {
  return switch (quantity) {
    MeasuredQuantity.apparentBytes => l10n.sizeQuantityApparent,
    MeasuredQuantity.allocatedBytes => l10n.sizeQuantityAllocated,
    MeasuredQuantity.blockCount => l10n.sizeQuantityBlocks,
    MeasuredQuantity.unknown => l10n.sizeQuantityUnknown,
  };
}

String _sizeConfidenceText(
  CleanDiskLocalizations l10n,
  SizeConfidence confidence,
) {
  return switch (confidence) {
    SizeConfidence.exact => l10n.sizeConfidenceExact,
    SizeConfidence.high => l10n.sizeConfidenceHigh,
    SizeConfidence.medium => l10n.sizeConfidenceMedium,
    SizeConfidence.low => l10n.sizeConfidenceLow,
    SizeConfidence.unknown => l10n.sizeConfidenceUnknown,
  };
}

String _nodeFlagsText(CleanDiskLocalizations l10n, NodeFlags flags) {
  final labels = [
    if (flags.hidden) l10n.nodeFlagHidden,
    if (flags.system) l10n.nodeFlagSystem,
    if (flags.package) l10n.nodeFlagPackage,
    if (flags.symlink) l10n.nodeFlagSymlink,
  ];
  if (labels.isEmpty) {
    return l10n.nodeFlagsNone;
  }
  return labels.join(', ');
}

String _formatBytes(BigInt value) {
  final bytes = value.toDouble();
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(bytes / (1000 * 1000 * 1000)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1000 * 1000) {
    return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1000) {
    return '${(bytes / 1000).toStringAsFixed(1)} KB';
  }
  return '$value B';
}

String _formatElapsed(BigInt elapsedMs) {
  final duration = Duration(milliseconds: elapsedMs.toInt());
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _formatRate(double value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  if (value >= 10) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _deletePlanStateText(
  CleanDiskLocalizations l10n,
  DeletePlanItemState state,
) {
  return switch (state) {
    DeletePlanItemState.staleSnapshot => l10n.cleanupStateStaleSnapshot,
    DeletePlanItemState.changedMetadata => l10n.cleanupStateChangedMetadata,
    DeletePlanItemState.missingPermission => l10n.cleanupStateMissingPermission,
    DeletePlanItemState.policyConflict => l10n.cleanupStatePolicyConflict,
    DeletePlanItemState.unknownReclaim => l10n.cleanupStateUnknownReclaim,
  };
}

String _reclaimConfidenceText(
  CleanDiskLocalizations l10n,
  ReclaimEstimateConfidence confidence,
) {
  return switch (confidence) {
    ReclaimEstimateConfidence.high => l10n.reclaimConfidenceHigh,
    ReclaimEstimateConfidence.medium => l10n.reclaimConfidenceMedium,
    ReclaimEstimateConfidence.low => l10n.reclaimConfidenceLow,
    ReclaimEstimateConfidence.unknown => l10n.reclaimConfidenceUnknown,
  };
}

String _cleanupReceiptItemStateText(
  CleanDiskLocalizations l10n,
  CleanupItemOutcomeState state,
) {
  return switch (state) {
    CleanupItemOutcomeState.movedToTrash => l10n.cleanupReceiptItemMoved,
    CleanupItemOutcomeState.blocked => l10n.cleanupReceiptItemBlocked,
    CleanupItemOutcomeState.failed => l10n.cleanupReceiptItemFailed,
    CleanupItemOutcomeState.unknownRequiresReview =>
      l10n.cleanupReceiptItemUnknown,
    CleanupItemOutcomeState.pending ||
    CleanupItemOutcomeState.dispatchRecorded ||
    CleanupItemOutcomeState.unknown => l10n.cleanupReceiptItemPending,
  };
}

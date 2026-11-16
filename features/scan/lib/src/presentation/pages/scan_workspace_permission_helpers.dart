part of 'scan_home_page.dart';

String _identityProofText(
  CleanDiskLocalizations l10n,
  ScannerIdentityVerification verification,
) {
  return switch (verification) {
    ScannerIdentityVerification.verified => l10n.permissionIdentityVerified,
    ScannerIdentityVerification.unverified => l10n.permissionIdentityUnverified,
    ScannerIdentityVerification.unknown => l10n.permissionIdentityUnknown,
  };
}

Color _identityProofColor(ScannerIdentityVerification verification) {
  return switch (verification) {
    ScannerIdentityVerification.verified => _ScanColors.cyan,
    ScannerIdentityVerification.unverified => _ScanColors.yellow,
    ScannerIdentityVerification.unknown => _ScanColors.textSoft,
  };
}

String _permissionProbeText(
  CleanDiskLocalizations l10n,
  PermissionProbeStatus status,
) {
  return switch (status) {
    PermissionProbeStatus.verified => l10n.permissionProbeVerified,
    PermissionProbeStatus.denied => l10n.permissionProbeDenied,
    PermissionProbeStatus.notDetermined => l10n.permissionProbeNotDetermined,
    PermissionProbeStatus.notProbed => l10n.permissionProbePending,
    PermissionProbeStatus.degraded => l10n.permissionProbeDegraded,
    PermissionProbeStatus.unsupported => l10n.permissionProbeUnsupported,
    PermissionProbeStatus.unknown => l10n.permissionProbeUnknown,
  };
}

Color _permissionProbeColor(PermissionProbeStatus status) {
  return switch (status) {
    PermissionProbeStatus.verified => _ScanColors.cyan,
    PermissionProbeStatus.denied => _ScanColors.pink,
    PermissionProbeStatus.notDetermined => _ScanColors.yellow,
    PermissionProbeStatus.degraded => _ScanColors.violet,
    PermissionProbeStatus.notProbed ||
    PermissionProbeStatus.unsupported ||
    PermissionProbeStatus.unknown => _ScanColors.textSoft,
  };
}

String _scannerProcessText(
  CleanDiskLocalizations l10n,
  ScannerProcessKind processKind,
) {
  return switch (processKind) {
    ScannerProcessKind.appBundle => l10n.permissionScannerAppBundle,
    ScannerProcessKind.bundledHelper => l10n.permissionScannerBundledHelper,
    ScannerProcessKind.currentProcess => l10n.permissionScannerCurrentProcess,
    ScannerProcessKind.externalProcess => l10n.permissionScannerExternalProcess,
    ScannerProcessKind.unknown => l10n.permissionScannerUnknown,
  };
}

Color _scannerProcessColor(ScannerProcessKind processKind) {
  return switch (processKind) {
    ScannerProcessKind.appBundle ||
    ScannerProcessKind.bundledHelper => _ScanColors.cyan,
    ScannerProcessKind.currentProcess => _ScanColors.yellow,
    ScannerProcessKind.externalProcess => _ScanColors.pink,
    ScannerProcessKind.unknown => _ScanColors.textSoft,
  };
}

String _permissionActionText(CleanDiskLocalizations l10n, RuntimeProof proof) {
  final action = proof.permissionProbe.requiredAction;
  if (action != PermissionRequiredAction.none &&
      action != PermissionRequiredAction.unknown) {
    return switch (action) {
      PermissionRequiredAction.openMacosFullDiskAccess =>
        l10n.permissionActionMacosFullDiskAccess,
      PermissionRequiredAction.runAsAdministrator =>
        l10n.permissionActionWindowsAdministrator,
      PermissionRequiredAction.reviewLinuxPermissions =>
        l10n.permissionActionLinuxPermissions,
      PermissionRequiredAction.none => l10n.permissionActionNone,
      PermissionRequiredAction.unknown => l10n.permissionActionUnknown,
    };
  }
  if (_hasReducedCapabilityWarning(proof.packaging)) {
    return l10n.permissionActionReducedPackage;
  }
  if (action == PermissionRequiredAction.unknown) {
    return l10n.permissionActionUnknown;
  }
  return l10n.permissionActionNone;
}

Color _permissionActionColor(RuntimeProof proof) {
  final action = proof.permissionProbe.requiredAction;
  if (action != PermissionRequiredAction.none &&
      action != PermissionRequiredAction.unknown) {
    return _ScanColors.yellow;
  }
  if (_hasReducedCapabilityWarning(proof.packaging)) {
    return _ScanColors.yellow;
  }
  if (action == PermissionRequiredAction.unknown) {
    return _ScanColors.textSoft;
  }
  return _ScanColors.cyan;
}

bool _shouldShowDetailedPermissionProof(
  RuntimeProof proof, {
  required VoidCallback? onRepair,
}) {
  final probe = proof.permissionProbe.status;
  final action = proof.permissionProbe.requiredAction;
  final needsRepairGuidance =
      action != PermissionRequiredAction.none &&
      action != PermissionRequiredAction.unknown;
  final hasConfirmedAccessProblem =
      probe == PermissionProbeStatus.denied ||
      probe == PermissionProbeStatus.degraded ||
      probe == PermissionProbeStatus.unsupported;
  return onRepair != null || hasConfirmedAccessProblem || needsRepairGuidance;
}

bool _shouldUseCompactPermissionProof(
  RuntimeProof proof, {
  required _PermissionWarningData? warning,
  required bool showDetailedProof,
  required VoidCallback? onRepair,
}) {
  if (showDetailedProof || onRepair != null) {
    return false;
  }
  return proof.permissionProbe.status == PermissionProbeStatus.verified &&
      (warning == null || warning.compact);
}

bool _shouldShowPermissionProof(
  RuntimeProof proof, {
  required VoidCallback? onRepair,
}) {
  if (onRepair != null) {
    return true;
  }
  return !_hasConfirmedPermissionAccess(proof);
}

bool _hasConfirmedPermissionAccess(RuntimeProof proof) {
  return proof.permissionProbe.status == PermissionProbeStatus.verified &&
      proof.permissionProbe.requiredAction == PermissionRequiredAction.none;
}

_PermissionWarningData? _permissionWarningData(
  CleanDiskLocalizations l10n,
  RuntimeProof proof,
) {
  final probe = proof.permissionProbe.status;
  final identity = proof.scannerIdentity.verification;
  final hasAccessWarning = _hasActivePermissionWarning(probe);
  final identityRisk = identity == ScannerIdentityVerification.unverified;
  final packagingRisk = _hasReducedCapabilityWarning(proof.packaging);
  if (!hasAccessWarning &&
      probe != PermissionProbeStatus.verified &&
      !identityRisk &&
      !packagingRisk) {
    return null;
  }
  if (!hasAccessWarning &&
      probe == PermissionProbeStatus.verified &&
      !identityRisk &&
      !packagingRisk) {
    return null;
  }
  if (probe == PermissionProbeStatus.denied) {
    return _PermissionWarningData(
      title: l10n.permissionWarningTitle,
      message: l10n.permissionWarningDeniedText,
      icon: Icons.warning_amber_outlined,
      color: _ScanColors.yellow,
      compact: false,
    );
  }
  if (hasAccessWarning) {
    return _PermissionWarningData(
      title: l10n.permissionWarningTitle,
      message: l10n.permissionWarningUnverifiedText,
      icon: Icons.warning_amber_outlined,
      color: _ScanColors.yellow,
      compact: false,
    );
  }
  return _PermissionWarningData(
    title: l10n.permissionWarningDevTitle,
    message: l10n.permissionWarningDevIdentityText,
    icon: Icons.info_outline,
    color: _ScanColors.cyan,
    compact: true,
  );
}

bool _hasActivePermissionWarning(PermissionProbeStatus probe) {
  return switch (probe) {
    PermissionProbeStatus.denied ||
    PermissionProbeStatus.notDetermined ||
    PermissionProbeStatus.degraded ||
    PermissionProbeStatus.unsupported => true,
    PermissionProbeStatus.verified ||
    PermissionProbeStatus.notProbed ||
    PermissionProbeStatus.unknown => false,
  };
}

bool _isNeutralPermissionProof(
  RuntimeProof proof, {
  required _PermissionWarningData? warning,
  required VoidCallback? onRepair,
}) {
  final probe = proof.permissionProbe;
  final isPending =
      probe.status == PermissionProbeStatus.notProbed ||
      probe.status == PermissionProbeStatus.unknown;
  return isPending &&
      probe.checkedAtUnixMs == null &&
      warning == null &&
      onRepair == null;
}

bool _shouldShowPermissionCheckedLine(
  PermissionProbeStatus probe,
  BigInt? checkedAt,
) {
  if (checkedAt != null) {
    return true;
  }
  return switch (probe) {
    PermissionProbeStatus.notProbed || PermissionProbeStatus.unknown => false,
    PermissionProbeStatus.verified ||
    PermissionProbeStatus.denied ||
    PermissionProbeStatus.notDetermined ||
    PermissionProbeStatus.degraded ||
    PermissionProbeStatus.unsupported => true,
  };
}

final class _PermissionWarningData {
  const _PermissionWarningData({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.compact,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final bool compact;
}

List<String> _permissionRepairSteps(
  CleanDiskLocalizations l10n,
  RuntimeProof proof,
) {
  return switch (proof.permissionProbe.requiredAction) {
    PermissionRequiredAction.openMacosFullDiskAccess => [
      l10n.permissionRepairMacosStepOne,
      l10n.permissionRepairMacosStepTwo,
      l10n.permissionRepairMacosStepThree,
    ],
    PermissionRequiredAction.runAsAdministrator => [
      l10n.permissionRepairWindowsStepOne,
      l10n.permissionRepairWindowsStepTwo,
      l10n.permissionRepairWindowsStepThree,
    ],
    PermissionRequiredAction.reviewLinuxPermissions => [
      l10n.permissionRepairLinuxStepOne,
      l10n.permissionRepairLinuxStepTwo,
      l10n.permissionRepairLinuxStepThree,
    ],
    PermissionRequiredAction.none ||
    PermissionRequiredAction.unknown => [l10n.permissionRepairManualStep],
  };
}

bool _hasReducedCapabilityWarning(PackagingProof packaging) {
  final packageMode = packaging.packageMode;
  if (packageMode == PackageMode.unknown &&
      !packaging.debugBuild &&
      packaging.scannerProcess == ScannerProcessKind.unknown) {
    return false;
  }
  return packaging.debugBuild ||
      (!packaging.signedBuild && packageMode != PackageMode.unknown) ||
      packageMode == PackageMode.developmentShell ||
      packaging.scannerProcess == ScannerProcessKind.externalProcess;
}

String _packagingProofText(
  CleanDiskLocalizations l10n,
  PackagingProof packaging,
) {
  final mode = switch (packaging.packageMode) {
    PackageMode.developmentShell => l10n.permissionPackageDevelopment,
    PackageMode.appBundle => l10n.permissionPackageAppBundle,
    PackageMode.bundledDaemon => l10n.permissionPackageBundledDaemon,
    PackageMode.systemService => l10n.permissionPackageSystemService,
    PackageMode.portable => l10n.permissionPackagePortable,
    PackageMode.unknown => l10n.permissionPackageUnknown,
  };
  if (packaging.packageMode == PackageMode.unknown) {
    return mode;
  }
  final signature = packaging.signedBuild
      ? l10n.permissionSignedBuild
      : l10n.permissionUnsignedBuild;
  return '$mode / $signature';
}

Color _packagingProofColor(PackagingProof packaging) {
  if (packaging.packageMode == PackageMode.unknown) {
    return _ScanColors.textSoft;
  }
  if (packaging.signedBuild &&
      packaging.scannerProcess != ScannerProcessKind.externalProcess) {
    return _ScanColors.cyan;
  }
  return _ScanColors.yellow;
}

String _updateSafetyText(
  CleanDiskLocalizations l10n,
  UpdateSafety updateSafety,
) {
  if (updateSafety.quiesceRequiredBeforeUpdate) {
    return l10n.permissionUpdateQuiesceRequired;
  }
  if (updateSafety.rollbackSupported == SupportLevel.unknown ||
      updateSafety.receiptPreservation == SupportLevel.unknown) {
    return l10n.permissionUpdateUnknown;
  }
  return l10n.permissionUpdateNoQuiesce;
}

Color _updateSafetyColor(UpdateSafety updateSafety) {
  if (updateSafety.quiesceRequiredBeforeUpdate) {
    return _ScanColors.yellow;
  }
  if (updateSafety.rollbackSupported == SupportLevel.unknown ||
      updateSafety.receiptPreservation == SupportLevel.unknown) {
    return _ScanColors.textSoft;
  }
  return _ScanColors.cyan;
}

String _lastProbeText(CleanDiskLocalizations l10n, BigInt? checkedAtUnixMs) {
  if (checkedAtUnixMs == null) {
    return l10n.permissionCheckedNever;
  }
  final maxDateTimeMs = BigInt.from(8640000000000000);
  if (checkedAtUnixMs < BigInt.zero || checkedAtUnixMs > maxDateTimeMs) {
    return l10n.permissionCheckedUnknown;
  }
  final checkedAt = DateTime.fromMillisecondsSinceEpoch(
    checkedAtUnixMs.toInt(),
  ).toLocal();
  return [
    _twoDigits(checkedAt.hour),
    _twoDigits(checkedAt.minute),
    _twoDigits(checkedAt.second),
  ].join(':');
}

String _formatNodeTimestamp(CleanDiskLocalizations l10n, BigInt? unixMs) {
  if (unixMs == null) {
    return l10n.metricNoDataValue;
  }
  final maxDateTimeMs = BigInt.from(8640000000000000);
  if (unixMs < BigInt.zero || unixMs > maxDateTimeMs) {
    return l10n.metricNoDataValue;
  }
  final value = DateTime.fromMillisecondsSinceEpoch(unixMs.toInt()).toLocal();
  return [
    [
      value.year.toString().padLeft(4, '0'),
      _twoDigits(value.month),
      _twoDigits(value.day),
    ].join('-'),
    [_twoDigits(value.hour), _twoDigits(value.minute)].join(':'),
  ].join(' ');
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _issueText(ScanIssue issue) {
  final evidence = issue.evidence;
  final message = evidence.message;
  if (message != null && message.trim().isNotEmpty) {
    return message;
  }
  final path = evidence.path?.text;
  if (path != null && path.trim().isNotEmpty) {
    return '${issue.code.name}: $path';
  }
  return issue.code.name;
}

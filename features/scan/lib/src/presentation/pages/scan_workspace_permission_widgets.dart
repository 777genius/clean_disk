part of 'scan_home_page.dart';

class _ChipTarget extends StatefulWidget {
  const _ChipTarget({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_ChipTarget> createState() => _ChipTargetState();
}

class _ChipTargetState extends State<_ChipTarget> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() {
      _hovered = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null;
    final backgroundColor = widget.selected
        ? (_hovered && isInteractive
              ? _ScanColors.selectedSoft.withValues(alpha: 0.92)
              : _ScanColors.selectedSoft)
        : (_hovered && isInteractive
              ? _ScanColors.selectedSoft.withValues(alpha: 0.52)
              : _ScanColors.panel);
    final content = Container(
      key: widget.onTap == null && widget.selected
          ? const ValueKey('scan-target-chip-current')
          : null,
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _hovered && isInteractive
              ? _ScanColors.cyan.withValues(alpha: 0.74)
              : widget.selected
              ? _ScanColors.cyan
              : _ScanColors.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            widget.icon,
            color: widget.selected ? _ScanColors.cyan : Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(
                color: widget.selected ? _ScanColors.cyan : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
    if (!isInteractive) {
      return content;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: widget.selected
              ? const ValueKey('scan-target-chip-current')
              : null,
          onTap: widget.onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(8),
          focusColor: _ScanColors.cyan.withValues(alpha: 0.10),
          highlightColor: _ScanColors.cyan.withValues(alpha: 0.08),
          hoverColor: Colors.transparent,
          splashColor: _ScanColors.cyan.withValues(alpha: 0.12),
          child: content,
        ),
      ),
    );
  }
}

class _PermissionProofCard extends StatelessWidget {
  const _PermissionProofCard({
    required this.proof,
    this.onProbe,
    this.onRepair,
  });

  final RuntimeProof proof;
  final VoidCallback? onProbe;
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final identity = proof.scannerIdentity.verification;
    final probe = proof.permissionProbe.status;
    final warning = _permissionWarningData(l10n, proof);
    final checkedAt = proof.permissionProbe.checkedAtUnixMs;
    final showDetailedProof = _shouldShowDetailedPermissionProof(
      proof,
      onRepair: onRepair,
    );
    final summaryLines = [
      _ProofStatusData(
        label: l10n.permissionProbeLabel,
        value: _permissionProbeText(l10n, probe),
        color: _permissionProbeColor(probe),
      ),
      if (_shouldShowPermissionCheckedLine(probe, checkedAt))
        _ProofStatusData(
          label: l10n.permissionCheckedLabel,
          value: _lastProbeText(l10n, checkedAt),
          color: checkedAt == null ? _ScanColors.textSoft : _ScanColors.cyan,
        ),
    ];
    final detailLines = [
      _ProofStatusData(
        label: l10n.permissionIdentityLabel,
        value: _identityProofText(l10n, identity),
        color: _identityProofColor(identity),
      ),
      _ProofStatusData(
        label: l10n.permissionScannerLabel,
        value: _scannerProcessText(l10n, proof.scannerIdentity.processKind),
        color: _scannerProcessColor(proof.scannerIdentity.processKind),
      ),
      _ProofStatusData(
        label: l10n.permissionActionLabel,
        value: _permissionActionText(l10n, proof),
        color: _permissionActionColor(proof),
      ),
      _ProofStatusData(
        label: l10n.permissionPackageLabel,
        value: _packagingProofText(l10n, proof.packaging),
        color: _packagingProofColor(proof.packaging),
      ),
      _ProofStatusData(
        label: l10n.permissionUpdateLabel,
        value: _updateSafetyText(l10n, proof.packaging.updateSafety),
        color: _updateSafetyColor(proof.packaging.updateSafety),
      ),
    ];

    if (_isNeutralPermissionProof(
      proof,
      warning: warning,
      onRepair: onRepair,
    )) {
      return const _NeutralPermissionProofCard();
    }

    if (_shouldUseCompactPermissionProof(
      proof,
      warning: warning,
      showDetailedProof: showDetailedProof,
      onRepair: onRepair,
    )) {
      return _CompactPermissionProofCard(
        proof: proof,
        warning: warning,
        onProbe: onProbe,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ScanColors.innerPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: _ScanColors.cyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.permissionProofTitle,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: onProbe,
                  tooltip: l10n.permissionProbeAction,
                  icon: const Icon(Icons.refresh, size: 17),
                  color: _ScanColors.cyan,
                  style: IconButton.styleFrom(
                    backgroundColor: _ScanColors.input,
                    side: const BorderSide(color: _ScanColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (onRepair != null) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    key: const ValueKey('permission-repair-action'),
                    onPressed: onRepair,
                    tooltip: _permissionActionText(l10n, proof),
                    icon: const Icon(Icons.settings_suggest_outlined, size: 17),
                    color: _ScanColors.yellow,
                    style: IconButton.styleFrom(
                      backgroundColor: _ScanColors.input,
                      side: const BorderSide(color: _ScanColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _ProofStatusGrid(lines: summaryLines),
          if (showDetailedProof) ...[
            const SizedBox(height: 10),
            _ProofStatusGrid(lines: detailLines),
          ],
          if (warning != null) ...[
            const SizedBox(height: 10),
            _PermissionWarning(warning: warning),
          ],
        ],
      ),
    );
  }
}

class _CompactPermissionProofCard extends StatelessWidget {
  const _CompactPermissionProofCard({
    required this.proof,
    required this.warning,
    required this.onProbe,
  });

  final RuntimeProof proof;
  final _PermissionWarningData? warning;
  final VoidCallback? onProbe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final status = _permissionProbeText(l10n, proof.permissionProbe.status);
    final checked = _lastProbeText(l10n, proof.permissionProbe.checkedAtUnixMs);
    return Container(
      key: const ValueKey('permission-proof-compact'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _ScanColors.innerPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: _ScanColors.cyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.permissionProofTitle,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          status,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle(context).copyWith(
                            color: _ScanColors.cyan,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: _ScanColors.textSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            checked,
                            overflow: TextOverflow.ellipsis,
                            style: _bodyStyle(
                              context,
                            ).copyWith(color: _ScanColors.textSoft),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: onProbe,
                  tooltip: l10n.permissionProbeAction,
                  icon: const Icon(Icons.refresh, size: 17),
                  color: _ScanColors.cyan,
                  style: IconButton.styleFrom(
                    backgroundColor: _ScanColors.input,
                    side: const BorderSide(color: _ScanColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (warning case final warning?) ...[
            const SizedBox(height: 6),
            _CompactPermissionWarningLine(warning: warning),
          ],
        ],
      ),
    );
  }
}

class _CompactPermissionWarningLine extends StatelessWidget {
  const _CompactPermissionWarningLine({required this.warning});

  final _PermissionWarningData warning;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('permission-warning-compact'),
      children: [
        Icon(warning.icon, color: warning.color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${warning.title}: ${warning.message}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
          ),
        ),
      ],
    );
  }
}

class _NeutralPermissionProofCard extends StatelessWidget {
  const _NeutralPermissionProofCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return SizedBox(
      key: const ValueKey('permission-proof-neutral'),
      width: double.infinity,
      height: 32,
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: _ScanColors.cyan,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.permissionNeutralProbeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ProofStatusData {
  const _ProofStatusData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _ProofStatusGrid extends StatelessWidget {
  const _ProofStatusGrid({required this.lines});

  final List<_ProofStatusData> lines;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ProofStatusColumn(lines: _evenLines)),
              const SizedBox(width: 16),
              Expanded(child: _ProofStatusColumn(lines: _oddLines)),
            ],
          );
        }
        return _ProofStatusColumn(lines: lines);
      },
    );
  }

  List<_ProofStatusData> get _evenLines {
    return [
      for (var index = 0; index < lines.length; index += 1)
        if (index.isEven) lines[index],
    ];
  }

  List<_ProofStatusData> get _oddLines {
    return [
      for (var index = 0; index < lines.length; index += 1)
        if (index.isOdd) lines[index],
    ];
  }
}

class _PermissionWarning extends StatelessWidget {
  const _PermissionWarning({required this.warning});

  final _PermissionWarningData warning;

  @override
  Widget build(BuildContext context) {
    final compact = warning.compact;
    return Container(
      key: ValueKey(
        compact ? 'permission-warning-compact' : 'permission-warning-prominent',
      ),
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warning.color.withAlpha(compact ? 14 : 20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warning.color.withAlpha(compact ? 90 : 120)),
      ),
      child: Row(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Icon(warning.icon, color: warning.color, size: compact ? 17 : 18),
          const SizedBox(width: 8),
          Expanded(
            child: compact
                ? Text(
                    '${warning.title}: ${warning.message}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(
                      context,
                    ).copyWith(color: _ScanColors.textSoft),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        warning.title,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        warning.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle(
                          context,
                        ).copyWith(color: _ScanColors.textSoft),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProofStatusColumn extends StatelessWidget {
  const _ProofStatusColumn({required this.lines});

  final List<_ProofStatusData> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < lines.length; index += 1) ...[
          if (index > 0) const SizedBox(height: 6),
          _ProofStatusLine(
            label: lines[index].label,
            value: lines[index].value,
            color: lines[index].color,
          ),
        ],
      ],
    );
  }
}

class _ProofStatusLine extends StatelessWidget {
  const _ProofStatusLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 280;
        final labelText = Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
        );
        final valueText = Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _bodyStyle(
            context,
          ).copyWith(color: color, fontWeight: FontWeight.w800),
        );
        final statusDot = Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );

        return Row(
          children: [
            SizedBox(width: compact ? 82 : 88, child: labelText),
            SizedBox(width: compact ? 6 : 8),
            statusDot,
            SizedBox(width: compact ? 6 : 8),
            Expanded(child: valueText),
          ],
        );
      },
    );
  }
}

class _CleanupConfirmItemList extends StatelessWidget {
  const _CleanupConfirmItemList({required this.plan});

  final DeletePlan plan;

  @override
  Widget build(BuildContext context) {
    final shown = plan.items.take(4).toList(growable: false);
    return Container(
      key: const ValueKey('cleanup-confirm-items'),
      constraints: const BoxConstraints(maxHeight: 172),
      decoration: BoxDecoration(
        color: _ScanColors.input.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in shown.indexed)
            _CleanupConfirmItemRow(
              key: ValueKey(
                'cleanup-confirm-item-${entry.$2.intent.nodeId.value}',
              ),
              item: entry.$2,
              showDivider: entry.$1 < shown.length - 1,
            ),
          if (plan.items.length > shown.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+${plan.items.length - shown.length}',
                  style: _monoStyle(
                    context,
                  ).copyWith(color: _ScanColors.textSoft),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CleanupConfirmItemRow extends StatelessWidget {
  const _CleanupConfirmItemRow({
    super.key,
    required this.item,
    required this.showDivider,
  });

  final DeletePlanItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: _ScanColors.border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            _nodeKindIcon(item.intent.kind),
            size: 18,
            color: _ScanColors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.intent.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatSize(item.intent.measuredSize),
            style: _monoStyle(context).copyWith(color: _ScanColors.pink),
          ),
        ],
      ),
    );
  }
}

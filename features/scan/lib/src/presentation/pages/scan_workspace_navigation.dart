part of 'scan_home_page.dart';

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.valueMaxLines = 1,
  });

  final String label;
  final String value;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: valueMaxLines > 1 ? 50 : 36,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _ScanColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 136,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: value,
              child: Text(
                value,
                maxLines: valueMaxLines,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                softWrap: valueMaxLines > 1,
                style: _monoStyle(context).copyWith(color: _ScanColors.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : 132,
      height: compact ? 30 : null,
      padding: EdgeInsets.only(left: compact ? 8 : 18),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _ScanColors.border)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(context).copyWith(
              color: _ScanColors.textSoft,
              fontSize: compact ? 11 : 12,
              height: 1.05,
            ),
          ),
          SizedBox(height: compact ? 1 : 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _monoStyle(context).copyWith(
              color: Colors.white,
              fontSize: compact ? 12 : 14,
              height: 1.08,
            ),
          ),
        ],
      ),
    );
  }
}

class _WindowChromeInset extends StatelessWidget {
  const _WindowChromeInset({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final needsNativeTrafficLightInset =
        Theme.of(context).platform == TargetPlatform.macOS;
    if (!needsNativeTrafficLightInset) {
      return const SizedBox.shrink();
    }

    return SizedBox(width: compact ? 78 : 82);
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          context.cleanDiskL10n.appTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _HeaderTargetPicker extends StatelessWidget {
  const _HeaderTargetPicker({
    required this.activeTarget,
    required this.targetChoices,
    required this.isLoadingTargetChoices,
    required this.runtimeProof,
    required this.scanActionLabel,
    required this.canPickTarget,
    required this.canScan,
    required this.canRepairPermission,
    required this.onPickTarget,
    required this.onChooseTarget,
    required this.onChooseFolderTarget,
    required this.onPermissionProbe,
    required this.onPermissionRepair,
    required this.onScan,
  });

  final ScanTarget activeTarget;
  final List<ScanTargetChoice> targetChoices;
  final bool isLoadingTargetChoices;
  final RuntimeProof runtimeProof;
  final String scanActionLabel;
  final bool canPickTarget;
  final bool canScan;
  final bool canRepairPermission;
  final VoidCallback onPickTarget;
  final ValueChanged<ScanTargetChoice> onChooseTarget;
  final VoidCallback onChooseFolderTarget;
  final VoidCallback onPermissionProbe;
  final VoidCallback onPermissionRepair;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(_ScanColors.panel),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: _ScanColors.border),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        Builder(
          builder: (context) {
            final controller = MenuController.maybeOf(context);
            return _HeaderTargetMenu(
              activeTarget: activeTarget,
              targetChoices: targetChoices,
              isLoadingTargetChoices: isLoadingTargetChoices,
              runtimeProof: runtimeProof,
              scanActionLabel: scanActionLabel,
              canPickTarget: canPickTarget,
              canScan: canScan,
              canRepairPermission: canRepairPermission,
              onPickTarget: () {
                controller?.close();
                onPickTarget();
              },
              onChooseTarget: onChooseTarget,
              onChooseFolderTarget: () {
                controller?.close();
                onChooseFolderTarget();
              },
              onPermissionProbe: onPermissionProbe,
              onPermissionRepair: onPermissionRepair,
              onScan: () {
                onScan?.call();
                controller?.close();
              },
            );
          },
        ),
      ],
      builder: (context, controller, child) {
        return _BreadcrumbButton(
          target: activeTarget,
          expanded: controller.isOpen,
          onTap: () {
            controller.isOpen ? controller.close() : controller.open();
          },
        );
      },
    );
  }
}

class _HeaderTargetMenu extends StatelessWidget {
  const _HeaderTargetMenu({
    required this.activeTarget,
    required this.targetChoices,
    required this.isLoadingTargetChoices,
    required this.runtimeProof,
    required this.scanActionLabel,
    required this.canPickTarget,
    required this.canScan,
    required this.canRepairPermission,
    required this.onPickTarget,
    required this.onChooseTarget,
    required this.onChooseFolderTarget,
    required this.onPermissionProbe,
    required this.onPermissionRepair,
    required this.onScan,
  });

  final ScanTarget activeTarget;
  final List<ScanTargetChoice> targetChoices;
  final bool isLoadingTargetChoices;
  final RuntimeProof runtimeProof;
  final String scanActionLabel;
  final bool canPickTarget;
  final bool canScan;
  final bool canRepairPermission;
  final VoidCallback onPickTarget;
  final ValueChanged<ScanTargetChoice> onChooseTarget;
  final VoidCallback onChooseFolderTarget;
  final VoidCallback onPermissionProbe;
  final VoidCallback onPermissionRepair;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final choices = targetChoices.take(6).toList(growable: false);
    final permissionRepair = canRepairPermission ? onPermissionRepair : null;

    return SizedBox(
      key: const ValueKey('scan-target-header-menu'),
      width: 390,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCaption(l10n.scanScopeSection.toUpperCase()),
            const SizedBox(height: 8),
            _HeaderTargetMenuCurrent(target: activeTarget),
            const SizedBox(height: 10),
            if (isLoadingTargetChoices)
              const LinearProgressIndicator(
                minHeight: 3,
                color: _ScanColors.cyan,
                backgroundColor: _ScanColors.progressTrack,
              )
            else
              for (final choice in choices)
                _HeaderTargetMenuChoice(
                  choice: choice,
                  selected: choice.target.path.value == activeTarget.path.value,
                  onTap: () => onChooseTarget(choice),
                ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _FlatMenuAction(
                    key: const ValueKey('scan-target-menu-pick-folder-action'),
                    icon: Icons.folder_open_outlined,
                    label: l10n.targetPickAction,
                    onTap: canPickTarget ? onChooseFolderTarget : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FlatMenuAction(
                    key: const ValueKey('scan-target-menu-open-picker-action'),
                    icon: Icons.tune,
                    label: l10n.targetOtherPathAction,
                    onTap: canPickTarget ? onPickTarget : null,
                  ),
                ),
              ],
            ),
            if (_shouldShowPermissionProof(
              runtimeProof,
              onRepair: permissionRepair,
            )) ...[
              const SizedBox(height: 10),
              _HeaderPermissionLine(
                proof: runtimeProof,
                onProbe: onPermissionProbe,
                onRepair: permissionRepair,
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                key: const ValueKey('scan-target-menu-scan-action'),
                onPressed: canScan ? onScan : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(scanActionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: _ScanColors.cyan,
                  foregroundColor: _ScanColors.onPrimary,
                  disabledBackgroundColor: _ScanColors.input,
                  disabledForegroundColor: _ScanColors.textSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderTargetMenuCurrent extends StatelessWidget {
  const _HeaderTargetMenuCurrent({required this.target});

  final ScanTarget target;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('scan-target-menu-current'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _ScanColors.input,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.folder_open_outlined,
            color: _ScanColors.cyan,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              target.path.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _monoStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderTargetMenuChoice extends StatefulWidget {
  const _HeaderTargetMenuChoice({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final ScanTargetChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_HeaderTargetMenuChoice> createState() =>
      _HeaderTargetMenuChoiceState();
}

class _HeaderTargetMenuChoiceState extends State<_HeaderTargetMenuChoice> {
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
    final l10n = context.cleanDiskL10n;
    final backgroundColor = widget.selected
        ? (_hovered
              ? _ScanColors.selectedSoft.withValues(alpha: 0.96)
              : _ScanColors.selectedSoft)
        : (_hovered
              ? _ScanColors.selectedSoft.withValues(alpha: 0.42)
              : Colors.transparent);
    final borderColor = _hovered
        ? _ScanColors.cyan.withValues(alpha: 0.56)
        : Colors.transparent;
    final foregroundColor = widget.selected || _hovered
        ? _ScanColors.cyan
        : _ScanColors.text;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('scan-target-menu-choice-${widget.choice.id}'),
          onTap: widget.onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.transparent,
          splashColor: _ScanColors.cyan.withValues(alpha: 0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  _targetChoiceIcon(widget.choice.kind),
                  color: widget.selected || _hovered
                      ? _ScanColors.cyan
                      : _ScanColors.textSoft,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _targetChoiceLabel(l10n, widget.choice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(context).copyWith(
                      color: foregroundColor,
                      fontWeight: widget.selected || _hovered
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        widget.choice.target.path.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: _monoStyle(context).copyWith(
                          color: _hovered
                              ? _ScanColors.text
                              : _ScanColors.textSoft,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlatMenuAction extends StatelessWidget {
  const _FlatMenuAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: _ScanColors.cyan,
          disabledForegroundColor: _ScanColors.textSoft.withAlpha(120),
          side: const BorderSide(color: _ScanColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

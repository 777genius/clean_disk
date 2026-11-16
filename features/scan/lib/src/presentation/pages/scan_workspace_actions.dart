part of 'scan_home_page.dart';

class _DeleteQueuePreview extends StatelessWidget {
  const _DeleteQueuePreview({
    required this.store,
    required this.onRefreshPreview,
    required this.onExecuteCleanup,
    required this.onStoreChanged,
  });

  final ScanWorkspaceStore store;
  final VoidCallback onRefreshPreview;
  final VoidCallback onExecuteCleanup;
  final VoidCallback onStoreChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final queued = store.queuedItems;
    final plan = store.deletePlan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: _ScanColors.border),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              Icons.playlist_add_check_outlined,
              color: _ScanColors.cyan,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.deleteQueueTitle,
                style: _bodyStyle(context).copyWith(color: Colors.white),
              ),
            ),
            if (queued.isNotEmpty)
              Text(
                _formatBytes(plan.knownReclaimBytes),
                style: _monoStyle(context).copyWith(color: _ScanColors.cyan),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (queued.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deleteQueueEmpty,
                style: _bodyStyle(
                  context,
                ).copyWith(color: _ScanColors.textSoft),
              ),
              if (store.cleanupReceipt case final receipt?) ...[
                const SizedBox(height: 8),
                _CleanupReceiptSummary(receipt: receipt),
              ],
            ],
          )
        else ...[
          for (final item in plan.items.take(3))
            _DeleteQueueItem(
              item: item,
              onRemove: () {
                store.removeQueuedNode(item.intent.nodeId);
                onStoreChanged();
              },
            ),
          if (queued.length > 3)
            Text(
              l10n.deleteQueueMoreCount(count: queued.length - 3),
              style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
            ),
          const SizedBox(height: 8),
          Text(
            plan.hasBlockingStates
                ? l10n.cleanupPreviewBlocked
                : l10n.cleanupPreviewReady,
            style: _bodyStyle(context).copyWith(
              color: plan.hasBlockingStates
                  ? _ScanColors.yellow
                  : _ScanColors.cyan,
            ),
          ),
          if (store.cleanupReceipt case final receipt?) ...[
            const SizedBox(height: 8),
            _CleanupReceiptSummary(receipt: receipt),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              key: const ValueKey('cleanup-preview-refresh-action'),
              onPressed: onRefreshPreview,
              icon: const Icon(Icons.verified_user_outlined, size: 16),
              label: Text(l10n.cleanupPreviewRefreshAction),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              key: const ValueKey('cleanup-preview-trash-action'),
              onPressed: plan.canAuthorizeCleanup ? onExecuteCleanup : null,
              icon: const Icon(Icons.delete_outline, size: 17),
              label: Text(l10n.cleanupPreviewTrashAction),
              style: FilledButton.styleFrom(
                backgroundColor: _ScanColors.pink,
                disabledBackgroundColor: _ScanColors.input,
                foregroundColor: Colors.white,
                disabledForegroundColor: _ScanColors.textSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _CleanupTrashNotice(),
        ],
      ],
    );
  }
}

class _CleanupTrashNotice extends StatelessWidget {
  const _CleanupTrashNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return Container(
      key: const ValueKey('cleanup-preview-trash-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _ScanColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: _ScanColors.textSoft, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cleanupPreviewTrashNoticeTitle,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.cleanupPreviewTrashNoticeText,
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

class _DeleteQueueItem extends StatelessWidget {
  const _DeleteQueueItem({required this.item, required this.onRemove});

  final DeletePlanItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final stateColor = item.isBlocked ? _ScanColors.yellow : _ScanColors.cyan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Icon(
                  _nodeKindIcon(item.intent.kind),
                  size: 20,
                  color: _ScanColors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.intent.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(context).copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSize(item.intent.measuredSize),
                  style: _monoStyle(context).copyWith(color: _ScanColors.pink),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: IconButton(
                    tooltip: l10n.deleteQueueRemoveAction,
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 16),
                    color: _ScanColors.textSoft,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _StatePill(
                label: item.isBlocked
                    ? l10n.cleanupPreviewBlockedShort
                    : l10n.cleanupPreviewReadyShort,
                color: stateColor,
              ),
              _StatePill(
                label: _reclaimConfidenceText(
                  l10n,
                  item.reclaimEstimate.confidence,
                ),
                color: _ScanColors.textSoft,
              ),
              for (final state in item.states.take(2))
                _StatePill(
                  label: _deletePlanStateText(l10n, state),
                  color: _ScanColors.yellow,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CleanupReceiptSummary extends StatelessWidget {
  const _CleanupReceiptSummary({required this.receipt});

  final CleanupReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final review = receipt.hasReviewItems;
    final color = review ? _ScanColors.yellow : _ScanColors.cyan;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review ? l10n.cleanupReceiptNeedsReview : l10n.cleanupReceiptReady,
            style: _bodyStyle(context).copyWith(color: color),
          ),
          const SizedBox(height: 6),
          for (final item in receipt.items.take(3))
            Text(
              '${item.displayName}: ${_cleanupReceiptItemStateText(l10n, item.state)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _monoStyle(context).copyWith(color: _ScanColors.textSoft),
            ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.label,
    required this.color,
    this.maxWidth = 150,
  });

  final String label;
  final Color color;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: _monoStyle(context).copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

class _ToolbarSearchField extends StatelessWidget {
  const _ToolbarSearchField({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: IgnorePointer(
        ignoring: !enabled,
        child: AppTextField(
          key: const ValueKey('scan-search-field'),
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          height: 36,
          textInputAction: TextInputAction.search,
          prefixIcon: Icons.search,
          prefixIconSize: 18,
          prefixIconColor: _ScanColors.textSoft,
          placeholderColor: _ScanColors.textSoft,
          textStyle: _bodyStyle(context).copyWith(color: _ScanColors.text),
          containerPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}

class _SortMenuButton extends StatelessWidget {
  const _SortMenuButton({
    required this.iconOnly,
    required this.currentSort,
    required this.tooltip,
    required this.selected,
    required this.onSort,
    this.text,
  });

  final bool iconOnly;
  final ChildSort currentSort;
  final String tooltip;
  final bool selected;
  final ValueChanged<ChildSort> onSort;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return PopupMenuButton<ChildSort>(
      key: const ValueKey('scan-toolbar-sort-action'),
      tooltip: tooltip,
      color: _ScanColors.innerPanel,
      elevation: 12,
      position: PopupMenuPosition.under,
      onSelected: onSort,
      itemBuilder: (context) => [
        _sortMenuItem(context, l10n, ChildSort.sizeDesc),
        _sortMenuItem(context, l10n, ChildSort.sizeAsc),
        _sortMenuItem(context, l10n, ChildSort.nameAsc),
        _sortMenuItem(context, l10n, ChildSort.nameDesc),
      ],
      child: iconOnly
          ? _SortIconSurface(selected: selected)
          : _SortTextSurface(
              text: text ?? _sortButtonLabelForMenu(currentSort, l10n),
              selected: selected,
            ),
    );
  }

  PopupMenuItem<ChildSort> _sortMenuItem(
    BuildContext context,
    CleanDiskLocalizations l10n,
    ChildSort sort,
  ) {
    final active = currentSort == sort;
    return PopupMenuItem<ChildSort>(
      key: ValueKey('scan-sort-option-${sort.name}'),
      value: sort,
      child: Row(
        children: [
          Icon(
            active ? Icons.check : Icons.sort,
            color: active ? _ScanColors.cyan : _ScanColors.textSoft,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _sortMenuLabel(sort, l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(
                color: active ? Colors.white : _ScanColors.text,
                fontWeight: active ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortIconSurface extends StatelessWidget {
  const _SortIconSurface({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _ScanColors.selectedRow : _ScanColors.input,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? _ScanColors.cyan : _ScanColors.border,
        ),
      ),
      child: Icon(
        Icons.tune,
        size: 20,
        color: selected ? _ScanColors.cyan : _ScanColors.textSoft,
      ),
    );
  }
}

class _SortTextSurface extends StatelessWidget {
  const _SortTextSurface({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 148),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? _ScanColors.selectedRow : _ScanColors.input,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? _ScanColors.cyan : _ScanColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tune,
            size: 18,
            color: selected ? _ScanColors.cyan : _ScanColors.textSoft,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(
                color: selected ? _ScanColors.text : _ScanColors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(
            Icons.play_arrow,
            size: 18,
            color: _ScanColors.onPrimary,
          ),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(context).copyWith(
              color: _ScanColors.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
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
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        color: !enabled
            ? _ScanColors.textSoft.withValues(alpha: 0.56)
            : primary
            ? _ScanColors.onPrimary
            : Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: primary && enabled
              ? _ScanColors.cyan
              : _ScanColors.input,
          disabledBackgroundColor: _ScanColors.input.withValues(alpha: 0.72),
          side: BorderSide(
            color: !enabled
                ? _ScanColors.border.withValues(alpha: 0.72)
                : primary
                ? _ScanColors.cyan
                : _ScanColors.border,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _PaneToggleAction extends StatelessWidget {
  const _PaneToggleAction({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _ScanColors.input,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _ScanColors.border),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    super.key,
    required this.icon,
    required this.label,
    this.accent = _ScanColors.text,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color foreground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return _ScanColors.textSoft.withAlpha(120);
      }
      return accent;
    }

    Color? overlay(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      if (states.contains(WidgetState.pressed)) {
        return accent.withAlpha(30);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return accent.withAlpha(18);
      }
      return null;
    }

    BorderSide side(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: _ScanColors.border.withAlpha(150));
      }
      return BorderSide(color: accent.withAlpha(180));
    }

    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(foreground),
          overlayColor: WidgetStateProperty.resolveWith(overlay),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10),
          ),
          textStyle: WidgetStatePropertyAll(
            _bodyStyle(context).copyWith(fontSize: 13),
          ),
          side: WidgetStateProperty.resolveWith(side),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}

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

class _HeaderPermissionLine extends StatelessWidget {
  const _HeaderPermissionLine({
    required this.proof,
    required this.onProbe,
    this.onRepair,
  });

  final RuntimeProof proof;
  final VoidCallback onProbe;
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowPermissionProof(proof, onRepair: onRepair)) {
      return const SizedBox.shrink(key: ValueKey('permission-proof-hidden'));
    }

    final l10n = context.cleanDiskL10n;
    final probe = proof.permissionProbe.status;
    final color = _permissionProbeColor(probe);
    final text = _permissionProbeText(l10n, probe);

    return Container(
      key: const ValueKey('scan-target-menu-permission-line'),
      height: 36,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _ScanColors.border),
          bottom: BorderSide(color: _ScanColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${l10n.permissionProofTitle}: $text',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
            ),
          ),
          IconButton(
            onPressed: onProbe,
            tooltip: l10n.permissionProbeAction,
            icon: const Icon(Icons.refresh, size: 16),
            color: _ScanColors.cyan,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
          if (onRepair != null)
            IconButton(
              key: const ValueKey('permission-repair-action'),
              onPressed: onRepair,
              tooltip: _permissionActionText(l10n, proof),
              icon: const Icon(Icons.settings_suggest_outlined, size: 16),
              color: _ScanColors.yellow,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            ),
        ],
      ),
    );
  }
}

class _BreadcrumbButton extends StatefulWidget {
  const _BreadcrumbButton({
    required this.target,
    required this.expanded,
    this.onTap,
  });

  final ScanTarget target;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  State<_BreadcrumbButton> createState() => _BreadcrumbButtonState();
}

class _BreadcrumbButtonState extends State<_BreadcrumbButton> {
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
    final content = Container(
      key: const ValueKey('scan-target-breadcrumb'),
      height: 36,
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _hovered && isInteractive
            ? _ScanColors.selectedSoft.withValues(alpha: 0.56)
            : _ScanColors.input,
        border: Border.all(
          color: widget.expanded
              ? _ScanColors.cyan
              : _hovered && isInteractive
              ? _ScanColors.cyan.withValues(alpha: 0.72)
              : _ScanColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Tooltip(
        message: widget.target.path.value,
        child: Row(
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 17,
              color: _ScanColors.cyan,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.target.path.value,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(context).copyWith(color: _ScanColors.text),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              widget.expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: _ScanColors.textSoft,
              size: 18,
            ),
          ],
        ),
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
          key: const ValueKey('scan-target-breadcrumb-action'),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _ScanColors.innerPanel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _ScanColors.border),
      ),
      child: Center(
        child: Text(
          text,
          style: _bodyStyle(context).copyWith(color: _ScanColors.cyan),
        ),
      ),
    );
  }
}

class _SectionCaption extends StatelessWidget {
  const _SectionCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: _ScanColors.textSoft,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider.vertical() : vertical = true;
  const _Divider.horizontal() : vertical = false;

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return vertical
        ? const VerticalDivider(width: 1, color: _ScanColors.border)
        : const Divider(height: 1, color: _ScanColors.border);
  }
}

abstract final class _ScanColors {
  static const background = Color(0xFF050914);
  static const topBar = Color(0xFF070B17);
  static const footer = Color(0xFF060B16);
  static const panel = Color(0xFF0A1020);
  static const innerPanel = Color(0xFF0D1428);
  static const panelHeader = Color(0xFF10172B);
  static const input = Color(0xFF0B1224);
  static const border = Color(0xFF263148);
  static const selectedRow = Color(0xFF14265E);
  static const selectedSoft = Color(0xFF0D2142);
  static const progressTrack = Color(0xFF20283D);
  static const text = Color(0xFFDCE6FF);
  static const textSoft = Color(0xFF93A0BF);
  static const onPrimary = Color(0xFF011216);
  static const blue = Color(0xFF3B82F6);
  static const cyan = Color(0xFF22E7F2);
  static const violet = Color(0xFF8B5CF6);
  static const pink = Color(0xFFFF5C8A);
  static const yellow = Color(0xFFFFCA3A);
}

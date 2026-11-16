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

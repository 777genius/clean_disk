part of 'scan_home_page.dart';

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.compact,
    required this.statusText,
    required this.searchController,
    required this.searchFocusNode,
    required this.currentSort,
    required this.queryMode,
    required this.activeTarget,
    required this.targetChoices,
    required this.isLoadingTargetChoices,
    required this.runtimeProof,
    required this.scanActionLabel,
    required this.canSearch,
    required this.canSort,
    required this.canPickTarget,
    required this.canRepairPermission,
    required this.canScan,
    required this.onScan,
    required this.onPickTarget,
    required this.onChooseTarget,
    required this.onChooseFolderTarget,
    required this.onPermissionProbe,
    required this.onPermissionRepair,
    required this.onPause,
    required this.canCancelScan,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSort,
  });

  final bool compact;
  final String statusText;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ChildSort currentSort;
  final ScanQueryMode queryMode;
  final ScanTarget activeTarget;
  final List<ScanTargetChoice> targetChoices;
  final bool isLoadingTargetChoices;
  final RuntimeProof runtimeProof;
  final String scanActionLabel;
  final bool canSearch;
  final bool canSort;
  final bool canPickTarget;
  final bool canRepairPermission;
  final bool canScan;
  final VoidCallback? onScan;
  final VoidCallback onPickTarget;
  final ValueChanged<ScanTargetChoice> onChooseTarget;
  final VoidCallback onChooseFolderTarget;
  final VoidCallback onPermissionProbe;
  final VoidCallback onPermissionRepair;
  final VoidCallback onPause;
  final bool canCancelScan;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<ChildSort> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final windowWidth = MediaQuery.sizeOf(context).width;
    final showSearch = canSearch;
    final showCompactTools = showSearch || canSort;
    final search = showSearch
        ? _ToolbarSearchField(
            controller: searchController,
            focusNode: searchFocusNode,
            placeholder: l10n.searchPlaceholder,
            enabled: true,
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
          )
        : null;
    final sortText = _sortLabel(currentSort, l10n);
    final sortButtonText = _sortButtonLabel(currentSort, l10n);

    return Container(
      height: compact && showCompactTools ? 96 : 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _ScanColors.topBar,
        border: Border(bottom: BorderSide(color: _ScanColors.border)),
      ),
      child: compact
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const _WindowChromeInset(compact: true),
                    const _AppTitle(),
                    const Spacer(),
                    _SquareAction(
                      key: const ValueKey('scan-toolbar-scan-action'),
                      icon: Icons.play_arrow,
                      tooltip: scanActionLabel,
                      onTap: canScan ? onScan : null,
                      primary: true,
                    ),
                    if (canCancelScan) ...[
                      const SizedBox(width: 8),
                      _SquareAction(
                        icon: Icons.stop_circle_outlined,
                        tooltip: l10n.cancelScanAction,
                        onTap: onPause,
                      ),
                    ],
                  ],
                ),
                if (showCompactTools) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (search case final search?)
                        Expanded(child: search)
                      else
                        const Spacer(),
                      if (canSort) ...[
                        const SizedBox(width: 8),
                        _SortMenuButton(
                          iconOnly: true,
                          currentSort: currentSort,
                          tooltip: sortText,
                          selected: queryMode == ScanQueryMode.children,
                          onSort: onSort,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            )
          : Row(
              children: [
                const _WindowChromeInset(compact: false),
                const _AppTitle(),
                const SizedBox(width: 18),
                _HeaderTargetPicker(
                  activeTarget: activeTarget,
                  targetChoices: targetChoices,
                  isLoadingTargetChoices: isLoadingTargetChoices,
                  runtimeProof: runtimeProof,
                  scanActionLabel: scanActionLabel,
                  canPickTarget: canPickTarget,
                  canScan: canScan,
                  canRepairPermission: canRepairPermission,
                  onPickTarget: onPickTarget,
                  onChooseTarget: onChooseTarget,
                  onChooseFolderTarget: onChooseFolderTarget,
                  onPermissionProbe: onPermissionProbe,
                  onPermissionRepair: onPermissionRepair,
                  onScan: onScan,
                ),
                const SizedBox(width: 16),
                _PrimaryActionButton(
                  key: const ValueKey('scan-toolbar-scan-action'),
                  label: scanActionLabel,
                  onTap: canScan ? onScan : null,
                ),
                if (canCancelScan) ...[
                  const SizedBox(width: 12),
                  _SquareAction(
                    icon: Icons.stop_circle_outlined,
                    tooltip: l10n.cancelScanAction,
                    onTap: onPause,
                  ),
                ],
                const Spacer(),
                _WideToolbarTrailingActions(
                  showStatus: windowWidth >= 1360,
                  statusText: statusText,
                  search: search,
                  currentSort: currentSort,
                  sortText: sortText,
                  sortButtonText: sortButtonText,
                  sortSelected: queryMode == ScanQueryMode.children,
                  canSort: canSort,
                  onSort: onSort,
                ),
              ],
            ),
    );
  }

  String _sortLabel(ChildSort sort, CleanDiskLocalizations l10n) {
    return switch (sort) {
      ChildSort.sizeDesc =>
        '${l10n.sortFilterAction}: ${l10n.sortSizeDescLabel}',
      ChildSort.sizeAsc => '${l10n.sortFilterAction}: ${l10n.sortSizeAscLabel}',
      ChildSort.nameAsc => '${l10n.sortFilterAction}: ${l10n.sortNameAscLabel}',
      ChildSort.nameDesc =>
        '${l10n.sortFilterAction}: ${l10n.sortNameDescLabel}',
      ChildSort.insertion => l10n.sortFilterAction,
    };
  }

  String _sortButtonLabel(ChildSort sort, CleanDiskLocalizations l10n) {
    return switch (sort) {
      ChildSort.sizeDesc => l10n.sortSizeDescLabel,
      ChildSort.sizeAsc => l10n.sortSizeAscLabel,
      ChildSort.nameAsc => l10n.sortNameAscLabel,
      ChildSort.nameDesc => l10n.sortNameDescLabel,
      ChildSort.insertion => l10n.sortFilterAction,
    };
  }
}

class _WideToolbarTrailingActions extends StatelessWidget {
  const _WideToolbarTrailingActions({
    required this.showStatus,
    required this.statusText,
    required this.search,
    required this.currentSort,
    required this.sortText,
    required this.sortButtonText,
    required this.sortSelected,
    required this.canSort,
    required this.onSort,
  });

  final bool showStatus;
  final String statusText;
  final Widget? search;
  final ChildSort currentSort;
  final String sortText;
  final String sortButtonText;
  final bool sortSelected;
  final bool canSort;
  final ValueChanged<ChildSort> onSort;

  @override
  Widget build(BuildContext context) {
    final search = this.search;
    if (!showStatus && search == null && !canSort) {
      return const SizedBox.shrink();
    }
    final searchWidth = showStatus ? 220.0 : 280.0;
    return Row(
      children: [
        if (showStatus && (search != null || canSort)) ...[
          const SizedBox(width: 12),
          _StatusPill(text: statusText),
          const SizedBox(width: 14),
        ] else if (search != null || canSort)
          const SizedBox(width: 12),
        if (search != null) SizedBox(width: searchWidth, child: search),
        if (canSort) ...[
          const SizedBox(width: 10),
          _SortMenuButton(
            iconOnly: false,
            currentSort: currentSort,
            text: sortButtonText,
            tooltip: sortText,
            selected: sortSelected,
            onSort: onSort,
          ),
        ],
      ],
    );
  }
}

class _AiAssistantRail extends StatelessWidget {
  const _AiAssistantRail({
    required this.store,
    required this.activeTarget,
    required this.onScan,
    required this.onCollapse,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final VoidCallback? onScan;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final summary = _metricSummary(store);
    final selected = store.selectedDetails?.summary;
    final focusName =
        selected?.name ??
        summary.largest?.name ??
        _targetDisplayName(activeTarget);
    final focusSize = selected == null
        ? (summary.largest == null
              ? (_metricSummarySizeText(store) ?? l10n.metricNoDataValue)
              : _formatSize(summary.largest!.size))
        : _formatSize(selected.size);
    final isRunning = store.sessionStatus?.state == SessionState.running;
    final statusText = isRunning
        ? l10n.aiStatusScanning
        : store.hasReadableSnapshot
        ? l10n.aiStatusReady
        : l10n.aiStatusRunScanFirst;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _ScanColors.cyan.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: _ScanColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiAssistantTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(context),
                    ),
                    Text(
                      l10n.aiAssistantSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(
                        context,
                      ).copyWith(color: _ScanColors.textSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PaneToggleAction(
                buttonKey: const ValueKey('scan-ai-collapse-action'),
                icon: Icons.keyboard_double_arrow_left,
                iconColor: _ScanColors.cyan,
                tooltip: l10n.aiAssistantTitle,
                onTap: onCollapse,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AiFocusSummary(
            title: focusName,
            subtitle: focusSize,
            status: statusText,
          ),
          const SizedBox(height: 16),
          _SectionCaption(l10n.aiHistorySection.toUpperCase()),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _AiMessageBubble(
                  author: l10n.aiAuthorAssistant,
                  text: l10n.aiIntroMessage,
                ),
                const SizedBox(height: 8),
                _AiMessageBubble(
                  author: l10n.aiAuthorUser,
                  text: l10n.aiUserStarterMessage,
                  user: true,
                ),
                const SizedBox(height: 8),
                _AiMessageBubble(
                  author: l10n.aiAuthorAssistant,
                  text: store.hasReadableSnapshot
                      ? l10n.aiSnapshotAdvice(focusName: focusName)
                      : l10n.aiNoSnapshotAdvice,
                ),
                const SizedBox(height: 12),
                _AiQuickHint(
                  icon: Icons.rule_folder_outlined,
                  title: l10n.aiSafeModeTitle,
                  text: l10n.aiSafeModeText,
                ),
                const SizedBox(height: 8),
                _AiQuickHint(
                  icon: Icons.history,
                  title: l10n.aiDialogMemoryTitle,
                  text: l10n.aiDialogMemoryText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('scan-ai-chat-input'),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _ScanColors.input,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: _ScanColors.cyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.aiAskPlaceholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(
                      context,
                    ).copyWith(color: _ScanColors.textSoft),
                  ),
                ),
              ],
            ),
          ),
          if (!store.hasReadableSnapshot && onScan != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(l10n.scanAction),
                style: FilledButton.styleFrom(
                  backgroundColor: _ScanColors.cyan,
                  foregroundColor: _ScanColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollapsedAiRail extends StatelessWidget {
  const _CollapsedAiRail({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;

    return Container(
      key: const ValueKey('scan-ai-collapsed-rail'),
      width: _WideWorkspace._collapsedAssistantRailWidth,
      color: _ScanColors.background,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          _PaneToggleAction(
            buttonKey: const ValueKey('scan-ai-expand-action'),
            icon: Icons.keyboard_double_arrow_right,
            tooltip: l10n.aiAssistantTitle,
            onTap: onExpand,
          ),
          const SizedBox(height: 8),
          _PaneToggleAction(
            buttonKey: const ValueKey('scan-ai-indicator-action'),
            icon: Icons.auto_awesome,
            iconColor: _ScanColors.cyan,
            tooltip: l10n.aiAssistantTitle,
            onTap: onExpand,
          ),
          const SizedBox(height: 14),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              'AI',
              maxLines: 1,
              style: _titleStyle(context).copyWith(
                color: _ScanColors.cyan,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chat_bubble_outline,
            color: _ScanColors.textSoft.withValues(alpha: 0.72),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _AiFocusSummary extends StatelessWidget {
  const _AiFocusSummary({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('scan-ai-focus-summary'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _ScanColors.border),
          bottom: BorderSide(color: _ScanColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.saved_search, color: _ScanColors.violet, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subtitle - $status',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    context,
                  ).copyWith(color: _ScanColors.textSoft, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMessageBubble extends StatelessWidget {
  const _AiMessageBubble({
    required this.author,
    required this.text,
    this.user = false,
  });

  final String author;
  final String text;
  final bool user;

  @override
  Widget build(BuildContext context) {
    final accent = user ? _ScanColors.blue : _ScanColors.cyan;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: user ? 0.86 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: user
                ? _ScanColors.selectedSoft.withAlpha(160)
                : _ScanColors.innerPanel,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: _bodyStyle(
                  context,
                ).copyWith(color: _ScanColors.text, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiQuickHint extends StatelessWidget {
  const _AiQuickHint({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _ScanColors.textSoft, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: _bodyStyle(
                context,
              ).copyWith(color: _ScanColors.textSoft, height: 1.22),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    color: _ScanColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

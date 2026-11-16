part of 'scan_home_page.dart';

class _EmptyRowsState extends StatelessWidget {
  const _EmptyRowsState({
    required this.store,
    required this.onScan,
    required this.showScanAction,
  });

  final ScanWorkspaceStore store;
  final VoidCallback? onScan;
  final bool showScanAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final state = _emptyRowsState(l10n: l10n, store: store);
    final canShowScanAction =
        showScanAction &&
        onScan != null &&
        store.pageLoadState != ScanPageLoadState.loading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final lifted = constraints.maxHeight >= 360;
        return Align(
          alignment: Alignment(0, lifted ? -0.34 : 0),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                key: const ValueKey('scan-empty-state-content'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(state.icon, color: state.accent, size: 34),
                  const SizedBox(height: 10),
                  Text(
                    state.title,
                    textAlign: TextAlign.center,
                    style: _titleStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: _bodyStyle(
                      context,
                    ).copyWith(color: _ScanColors.textSoft),
                  ),
                  if (canShowScanAction) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const ValueKey('scan-empty-scan-action'),
                      onPressed: onScan,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(
                        store.sessionStatus?.state == SessionState.completed
                            ? l10n.scanAgainAction
                            : l10n.scanAction,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _ScanColors.cyan,
                        foregroundColor: _ScanColors.background,
                        minimumSize: const Size(150, 38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TableStateBanner extends StatelessWidget {
  const _TableStateBanner({required this.state});

  final _RowsStateContent state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: state.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: state.accent.withAlpha(110)),
      ),
      child: Row(
        children: [
          Icon(state.icon, color: state.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.message,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueryModeBanner extends StatelessWidget {
  const _QueryModeBanner({required this.state, required this.onClearSearch});

  final _RowsStateContent state;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: state.accent.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: state.accent.withAlpha(105)),
      ),
      child: Row(
        children: [
          Icon(state.icon, color: state.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            key: const ValueKey('scan-query-clear-action'),
            onPressed: onClearSearch,
            icon: const Icon(Icons.account_tree_outlined, size: 16),
            label: Text(l10n.searchBackToTreeAction),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ScanColors.cyan,
              side: BorderSide(color: _ScanColors.cyan.withAlpha(150)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineFailureBanner extends StatelessWidget {
  const _InlineFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _ScanColors.yellow.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.yellow.withAlpha(120)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _ScanColors.yellow, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineInfoBanner extends StatelessWidget {
  const _InlineInfoBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _ScanColors.cyan.withAlpha(16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.cyan.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _ScanColors.cyan, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineDangerBanner extends StatelessWidget {
  const _InlineDangerBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _ScanColors.pink.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.pink.withAlpha(100)),
      ),
      child: Row(
        children: [
          const Icon(Icons.delete_outline, color: _ScanColors.pink, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(color: _ScanColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});

  final List<ScanIssue> issues;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ScanColors.innerPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ScanColors.yellow.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in issues.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _issueIcon(issue.severity),
                    color: _issueColor(issue.severity),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _issueText(issue),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: _bodyStyle(
                        context,
                      ).copyWith(color: _ScanColors.textSoft),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

final class _RowsStateContent {
  const _RowsStateContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
}

class _EmptyDetailsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: _ScanColors.violet, size: 40),
          const SizedBox(height: 12),
          Text(
            context.cleanDiskL10n.noSelectionTitle,
            style: _titleStyle(context),
          ),
          const SizedBox(height: 6),
          Text(
            context.cleanDiskL10n.noSelectionText,
            style: _bodyStyle(context).copyWith(color: _ScanColors.textSoft),
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionCaption(label.toUpperCase()),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(context).copyWith(
                    color: _ScanColors.textSoft,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

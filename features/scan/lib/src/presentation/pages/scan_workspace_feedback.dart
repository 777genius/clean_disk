part of 'scan_home_page.dart';

class _ScanFooter extends StatefulWidget {
  const _ScanFooter({required this.store, required this.onCancelScan});

  final ScanWorkspaceStore store;
  final VoidCallback onCancelScan;

  @override
  State<_ScanFooter> createState() => _ScanFooterState();
}

class _ScanFooterState extends State<_ScanFooter>
    with SingleTickerProviderStateMixin {
  static const _runningProgressCap = 0.94;
  static const _runningProgressDuration = Duration(minutes: 3);

  late final AnimationController _progressController;
  ScanSessionId? _runningSessionId;
  DateTime? _runningStartedAt;
  Timer? _runningProgressTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this);
    _syncProgressController();
  }

  @override
  void didUpdateWidget(_ScanFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncProgressController();
  }

  @override
  void dispose() {
    _runningProgressTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _syncProgressController() {
    final status = widget.store.sessionStatus;
    final running = status?.state == SessionState.running;
    final hasSnapshot = widget.store.activeSnapshotId != null;

    if (running) {
      final sessionId = status?.sessionId;
      if (_runningSessionId != sessionId) {
        _runningSessionId = sessionId;
        _runningStartedAt = DateTime.now();
        _progressController
          ..stop()
          ..value = 0;
      }
      _ensureRunningProgressTimer();
      _syncEstimatedRunningProgress();
      return;
    }

    _runningSessionId = null;
    _runningStartedAt = null;
    _runningProgressTimer?.cancel();
    _runningProgressTimer = null;
    _progressController.stop();
    if (hasSnapshot) {
      if (_progressController.value < 1) {
        _progressController.animateTo(
          1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (_progressController.value != 0) {
      _progressController.value = 0;
    }
  }

  void _ensureRunningProgressTimer() {
    if (_runningProgressTimer != null) {
      return;
    }
    _runningProgressTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _syncEstimatedRunningProgress(),
    );
  }

  void _syncEstimatedRunningProgress() {
    if (!mounted) {
      return;
    }
    if (widget.store.sessionStatus?.state != SessionState.running) {
      _runningProgressTimer?.cancel();
      _runningProgressTimer = null;
      return;
    }

    final startedAt = _runningStartedAt;
    if (startedAt == null) {
      return;
    }

    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final rawFraction =
        elapsedMs / _runningProgressDuration.inMilliseconds.toDouble();
    final easedFraction = Curves.easeOutCubic.transform(
      rawFraction.clamp(0.0, 1.0),
    );
    final nextValue = (easedFraction * _runningProgressCap).clamp(
      0.0,
      _runningProgressCap,
    );
    if (nextValue > _progressController.value) {
      _progressController.value = nextValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final progress = widget.store.progress;
    final running = widget.store.sessionStatus?.state == SessionState.running;
    final canCancelScan = running && widget.store.canCancelScan;
    final hasSnapshot = widget.store.activeSnapshotId != null;
    final hasBlockingRuntimeState =
        widget.store.daemonAvailability == ScanDaemonAvailability.offline ||
        widget.store.daemonAvailability == ScanDaemonAvailability.incompatible;
    final shouldHideFooter =
        (!running && !hasSnapshot && !hasBlockingRuntimeState) ||
        (widget.store.sessionStatus?.state == SessionState.completed &&
            widget.store.hasReadableSnapshot);
    if (shouldHideFooter) {
      return const SizedBox.shrink(key: ValueKey('scan-footer-hidden'));
    }

    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        final progressFraction = _progressController.value.clamp(0.0, 1.0);
        final statusText = running
            ? '${l10n.scanRunningStatus} ${_progressPercentText(progressFraction)}'
            : _footerStatus(l10n, widget.store);

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;

            return Container(
              key: const ValueKey('scan-footer'),
              height: compact ? 70 : 56,
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 24),
              decoration: const BoxDecoration(
                color: _ScanColors.footer,
                border: Border(top: BorderSide(color: _ScanColors.border)),
              ),
              child: compact
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            _FooterStatusIndicator(
                              running: running,
                              completed: hasSnapshot,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                statusText,
                                overflow: TextOverflow.ellipsis,
                                style: _bodyStyle(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (canCancelScan) ...[
                              const SizedBox(width: 8),
                              _FooterStopAction(
                                tooltip: l10n.cancelScanAction,
                                onTap: widget.onCancelScan,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        _FooterProgress(progressFraction: progressFraction),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: _FooterStat(
                                label: l10n.progressFilesScannedLabel,
                                value: _progressItemsText(
                                  l10n,
                                  progress,
                                  isRunning: running,
                                ),
                                compact: true,
                              ),
                            ),
                            Expanded(
                              child: _FooterStat(
                                label: l10n.progressElapsedLabel,
                                value: _progressElapsedText(
                                  l10n,
                                  progress,
                                  isRunning: running,
                                ),
                                compact: true,
                              ),
                            ),
                            Expanded(
                              child: _FooterStat(
                                label: l10n.progressThroughputLabel,
                                value: _progressThroughputText(
                                  l10n,
                                  progress,
                                  isRunning: running,
                                ),
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _FooterStatusIndicator(
                                    running: running,
                                    completed: hasSnapshot,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    statusText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _bodyStyle(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              _FooterProgress(
                                progressFraction: progressFraction,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        if (canCancelScan) ...[
                          _FooterStopAction(
                            tooltip: l10n.cancelScanAction,
                            onTap: widget.onCancelScan,
                          ),
                          const SizedBox(width: 16),
                        ],
                        _FooterStat(
                          label: l10n.progressFilesScannedLabel,
                          value: _progressItemsText(
                            l10n,
                            progress,
                            isRunning: running,
                          ),
                        ),
                        _FooterStat(
                          label: l10n.progressElapsedLabel,
                          value: _progressElapsedText(
                            l10n,
                            progress,
                            isRunning: running,
                          ),
                        ),
                        _FooterStat(
                          label: l10n.progressThroughputLabel,
                          value: _progressThroughputText(
                            l10n,
                            progress,
                            isRunning: running,
                          ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  String _footerStatus(CleanDiskLocalizations l10n, ScanWorkspaceStore store) {
    return switch (store.daemonAvailability) {
      ScanDaemonAvailability.offline => l10n.scanOfflineStatus,
      ScanDaemonAvailability.incompatible => l10n.scanIncompatibleStatus,
      _ =>
        store.activeSnapshotId == null
            ? l10n.scanReadyStatus
            : l10n.scanCompletedStatus,
    };
  }

  String _progressPercentText(double value) {
    final percent = (value * 100).floor().clamp(0, 99);
    return '$percent%';
  }
}

class _FooterStatusIndicator extends StatelessWidget {
  const _FooterStatusIndicator({
    required this.running,
    required this.completed,
  });

  final bool running;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    if (running) {
      return const SizedBox(
        key: ValueKey('scan-footer-running-indicator'),
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _ScanColors.cyan,
        ),
      );
    }

    if (completed) {
      return Container(
        key: const ValueKey('scan-footer-completed-indicator'),
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _ScanColors.cyan,
        ),
        child: const Icon(Icons.check, size: 14, color: _ScanColors.background),
      );
    }

    return SizedBox(
      key: const ValueKey('scan-footer-idle-indicator'),
      width: 18,
      height: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _ScanColors.cyan, width: 2),
        ),
      ),
    );
  }
}

class _FooterProgress extends StatelessWidget {
  const _FooterProgress({required this.progressFraction});

  final double progressFraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        key: const ValueKey('scan-footer-progress'),
        value: progressFraction.clamp(0.0, 1.0),
        minHeight: 4,
        backgroundColor: _ScanColors.progressTrack,
        valueColor: const AlwaysStoppedAnimation<Color>(_ScanColors.cyan),
      ),
    );
  }
}

class _FooterStopAction extends StatelessWidget {
  const _FooterStopAction({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        key: const ValueKey('scan-footer-stop-action'),
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        icon: const Icon(Icons.stop_rounded),
        color: _ScanColors.pink,
        style: IconButton.styleFrom(
          backgroundColor: _ScanColors.input,
          side: const BorderSide(color: _ScanColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

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

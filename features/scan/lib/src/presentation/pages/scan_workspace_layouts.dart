part of 'scan_home_page.dart';

class _WideWorkspace extends StatefulWidget {
  const _WideWorkspace({
    required this.store,
    required this.activeTarget,
    required this.onScan,
    required this.onRefreshCleanupPreview,
    required this.onExecuteCleanup,
    required this.onRefreshFolderTarget,
    required this.onClearSearch,
    required this.onStoreChanged,
    required this.diskUsageMapRenderer,
    required this.diskUsageMapCollapsed,
    required this.onToggleDiskUsageMap,
    required this.nodeTableCollapsed,
    required this.onToggleNodeTable,
    required this.aiPaneCollapsed,
    required this.onToggleAiPane,
    required this.detailsPaneCollapsed,
    required this.onToggleDetailsPane,
  });

  static const _assistantRailWidth = 340.0;
  static const _collapsedAssistantRailWidth = 52.0;
  static const _detailsPaneWidth = 380.0;
  static const _collapsedDetailsPaneWidth = 52.0;

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final VoidCallback? onScan;
  final VoidCallback onRefreshCleanupPreview;
  final VoidCallback onExecuteCleanup;
  final ValueChanged<ScanTarget> onRefreshFolderTarget;
  final VoidCallback onClearSearch;
  final VoidCallback onStoreChanged;
  final DiskUsageMapRenderer? diskUsageMapRenderer;
  final bool diskUsageMapCollapsed;
  final VoidCallback onToggleDiskUsageMap;
  final bool nodeTableCollapsed;
  final VoidCallback onToggleNodeTable;
  final bool aiPaneCollapsed;
  final VoidCallback onToggleAiPane;
  final bool detailsPaneCollapsed;
  final VoidCallback onToggleDetailsPane;

  @override
  State<_WideWorkspace> createState() => _WideWorkspaceState();
}

class _WideWorkspaceState extends State<_WideWorkspace> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showDetailsPane =
        widget.store.hasReadableSnapshot || widget.store.selectedNodeId != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: const ValueKey('scan-ai-rail'),
            width: widget.aiPaneCollapsed
                ? _WideWorkspace._collapsedAssistantRailWidth
                : _WideWorkspace._assistantRailWidth,
            child: ClipRect(
              child: widget.aiPaneCollapsed
                  ? _CollapsedAiRail(onExpand: widget.onToggleAiPane)
                  : _AiAssistantRail(
                      store: widget.store,
                      activeTarget: widget.activeTarget,
                      onScan: widget.onScan,
                      onCollapse: widget.onToggleAiPane,
                    ),
            ),
          ),
        ),
        const _Divider.vertical(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showMetricStrip = _shouldShowMetricStrip(widget.store);
              final showDiskUsageMap = _shouldShowDiskUsageMap(
                widget.store,
                widget.diskUsageMapRenderer,
              );
              final diskUsageMapHeight = _wideDiskUsageMapHeight(
                viewportHeight: constraints.maxHeight,
                metricStripVisible: showMetricStrip,
                nodeTableCollapsed: widget.nodeTableCollapsed,
              );

              return Scrollbar(
                controller: _scrollController,
                notificationPredicate: (notification) =>
                    notification.depth == 0,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: Column(
                    children: [
                      if (showMetricStrip) ...[
                        _MetricStrip(store: widget.store),
                        const SizedBox(height: 8),
                      ],
                      if (showDiskUsageMap) ...[
                        _DiskUsageMapPanel(
                          store: widget.store,
                          activeTarget: widget.activeTarget,
                          renderer: widget.diskUsageMapRenderer!,
                          collapsed: widget.diskUsageMapCollapsed,
                          compact: false,
                          height: diskUsageMapHeight,
                          onToggle: widget.onToggleDiskUsageMap,
                          onStoreChanged: widget.onStoreChanged,
                        ),
                        const SizedBox(height: 8),
                      ],
                      _NodeTable(
                        store: widget.store,
                        activeTarget: widget.activeTarget,
                        onScan: widget.onScan,
                        showEmptyScanAction: false,
                        onRefreshFolderTarget: widget.onRefreshFolderTarget,
                        onClearSearch: widget.onClearSearch,
                        onStoreChanged: widget.onStoreChanged,
                        collapsed: widget.nodeTableCollapsed,
                        onToggleCollapsed: widget.onToggleNodeTable,
                        rowsScrollable: false,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (showDetailsPane) ...[
          const _Divider.vertical(),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: widget.detailsPaneCollapsed
                  ? _WideWorkspace._collapsedDetailsPaneWidth
                  : _WideWorkspace._detailsPaneWidth,
              child: ClipRect(
                child: widget.detailsPaneCollapsed
                    ? _CollapsedDetailsRail(
                        onExpand: widget.onToggleDetailsPane,
                      )
                    : _DetailsPane(
                        store: widget.store,
                        activeTarget: widget.activeTarget,
                        onRefreshCleanupPreview: widget.onRefreshCleanupPreview,
                        onExecuteCleanup: widget.onExecuteCleanup,
                        onStoreChanged: widget.onStoreChanged,
                        onCollapse: widget.onToggleDetailsPane,
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

double _wideDiskUsageMapHeight({
  required double viewportHeight,
  required bool metricStripVisible,
  required bool nodeTableCollapsed,
}) {
  const defaultHeight = 260.0;
  if (!nodeTableCollapsed || !viewportHeight.isFinite) {
    return defaultHeight;
  }

  const viewportVerticalPadding = 22.0;
  const sectionGap = 8.0;
  const metricStripHeight = 64.0;
  const diskUsageMapChromeHeight = 114.0;
  const collapsedNodeTableHeight = 92.0;
  final reservedHeight =
      viewportVerticalPadding +
      sectionGap +
      diskUsageMapChromeHeight +
      collapsedNodeTableHeight +
      (metricStripVisible ? metricStripHeight + sectionGap : 0);

  return (viewportHeight - reservedHeight)
      .clamp(defaultHeight, double.infinity)
      .toDouble();
}

class _CompactWorkspace extends StatelessWidget {
  const _CompactWorkspace({
    required this.store,
    required this.activeTarget,
    required this.canChangeTarget,
    required this.onScan,
    required this.onPickTarget,
    required this.onPermissionProbe,
    required this.onPermissionRepair,
    required this.onRefreshCleanupPreview,
    required this.onExecuteCleanup,
    required this.onRefreshFolderTarget,
    required this.onClearSearch,
    required this.onStoreChanged,
    required this.diskUsageMapRenderer,
    required this.diskUsageMapCollapsed,
    required this.onToggleDiskUsageMap,
    required this.nodeTableCollapsed,
    required this.onToggleNodeTable,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final bool canChangeTarget;
  final VoidCallback? onScan;
  final VoidCallback onPickTarget;
  final VoidCallback onPermissionProbe;
  final VoidCallback onPermissionRepair;
  final VoidCallback onRefreshCleanupPreview;
  final VoidCallback onExecuteCleanup;
  final ValueChanged<ScanTarget> onRefreshFolderTarget;
  final VoidCallback onClearSearch;
  final VoidCallback onStoreChanged;
  final DiskUsageMapRenderer? diskUsageMapRenderer;
  final bool diskUsageMapCollapsed;
  final VoidCallback onToggleDiskUsageMap;
  final bool nodeTableCollapsed;
  final VoidCallback onToggleNodeTable;

  @override
  Widget build(BuildContext context) {
    final showDetailsPane =
        store.hasReadableSnapshot || store.selectedNodeId != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Column(
        children: [
          _TargetChips(
            activeTarget: activeTarget,
            canChangeTarget: canChangeTarget,
            onPickTarget: onPickTarget,
          ),
          const SizedBox(height: 10),
          if (_shouldShowPermissionProof(
            store.runtimeProof,
            onRepair: store.canRepairPermission ? onPermissionRepair : null,
          )) ...[
            _PermissionProofCard(
              proof: store.runtimeProof,
              onProbe: onPermissionProbe,
              onRepair: store.canRepairPermission ? onPermissionRepair : null,
            ),
            const SizedBox(height: 10),
          ],
          if (_shouldShowMetricStrip(store)) ...[
            _MetricStrip(store: store),
            const SizedBox(height: 10),
          ],
          if (_shouldShowDiskUsageMap(store, diskUsageMapRenderer)) ...[
            _DiskUsageMapPanel(
              store: store,
              activeTarget: activeTarget,
              renderer: diskUsageMapRenderer!,
              collapsed: diskUsageMapCollapsed,
              compact: true,
              onToggle: onToggleDiskUsageMap,
              onStoreChanged: onStoreChanged,
            ),
            const SizedBox(height: 10),
          ],
          _NodeTable(
            store: store,
            activeTarget: activeTarget,
            onScan: onScan,
            showEmptyScanAction: true,
            onRefreshFolderTarget: onRefreshFolderTarget,
            onClearSearch: onClearSearch,
            onStoreChanged: onStoreChanged,
            collapsed: nodeTableCollapsed,
            onToggleCollapsed: onToggleNodeTable,
            rowsScrollable: false,
          ),
          if (showDetailsPane) ...[
            const SizedBox(height: 10),
            _DetailsPane(
              store: store,
              activeTarget: activeTarget,
              onRefreshCleanupPreview: onRefreshCleanupPreview,
              onExecuteCleanup: onExecuteCleanup,
              onStoreChanged: onStoreChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiskUsageMapPanel extends StatelessWidget {
  const _DiskUsageMapPanel({
    required this.store,
    required this.activeTarget,
    required this.renderer,
    required this.collapsed,
    required this.compact,
    this.height,
    required this.onToggle,
    required this.onStoreChanged,
  });

  final ScanWorkspaceStore store;
  final ScanTarget activeTarget;
  final DiskUsageMapRenderer renderer;
  final bool collapsed;
  final bool compact;
  final double? height;
  final VoidCallback onToggle;
  final VoidCallback onStoreChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.cleanDiskL10n;
    final projection = _diskUsageMapProjection(
      l10n: l10n,
      store: store,
      activeTarget: activeTarget,
    );
    if (projection == null) {
      return const SizedBox.shrink();
    }

    final toggleLabel = collapsed
        ? l10n.diskUsageMapExpandAction
        : l10n.diskUsageMapCollapseAction;
    final breadcrumbItems = _diskUsageMapBreadcrumbItems(
      store: store,
      activeTarget: activeTarget,
    );
    final parentBreadcrumbNodeId = _diskUsageMapParentBreadcrumbNodeId(
      breadcrumbItems,
    );

    return Container(
      key: const ValueKey('scan-disk-usage-map-panel'),
      decoration: _panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
            child: Row(
              children: [
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: const ValueKey('scan-disk-usage-map-toggle-action'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggle,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.grid_view_rounded,
                            color: _ScanColors.cyan,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.diskUsageMapTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _diskUsageMapSummaryText(
                                    l10n,
                                    projection,
                                    store.diskUsageMapFocusNode,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: _ScanColors.textSoft,
                                        letterSpacing: 0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('scan-disk-usage-map-toggle-button'),
                  tooltip: toggleLabel,
                  onPressed: onToggle,
                  color: _ScanColors.textSoft,
                  iconSize: 24,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: collapsed
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DiskUsageMapBreadcrumbTrail(
                        items: breadcrumbItems,
                        backTooltip: l10n.diskUsageMapBackAction,
                        canGoBack: parentBreadcrumbNodeId != null,
                        onBack: () => _selectDiskUsageMapBreadcrumb(
                          parentBreadcrumbNodeId,
                          store,
                        ),
                        onSelect: (nodeId) =>
                            _selectDiskUsageMapBreadcrumb(nodeId, store),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: SizedBox(
                          width: double.infinity,
                          height: height ?? (compact ? 220 : 260),
                          child: DiskUsageMapView(
                            projection: projection,
                            renderer: renderer,
                            labels: _diskUsageMapLabels(l10n),
                            style: _diskUsageMapStyle,
                            selectedNodeId: store.selectedNodeId?.value,
                            focusedNodeId: store.diskUsageMapFocusNodeId?.value,
                            onTileSelected: (tile) =>
                                _selectDiskUsageMapTile(tile, store),
                            onTileActivated: (tile) =>
                                _selectDiskUsageMapTile(tile, store),
                            dataFallbackMaxItems: compact ? 8 : 12,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _selectDiskUsageMapBreadcrumb(NodeId? nodeId, ScanWorkspaceStore store) {
    store.setDiskUsageMapFocus(nodeId);
    if (nodeId == null) {
      return;
    }
    unawaited(store.selectNode(nodeId).whenComplete(onStoreChanged));
  }

  void _selectDiskUsageMapTile(
    DiskUsageMapTile tile,
    ScanWorkspaceStore store,
  ) {
    if (!_isSelectableDiskUsageMapTile(tile)) {
      return;
    }

    final nodeId = NodeId(tile.nodeId);
    store.toggleDiskUsageMapFocus(nodeId);
    unawaited(store.selectNode(nodeId).whenComplete(onStoreChanged));
  }
}

class _DiskUsageMapBreadcrumbTrail extends StatefulWidget {
  const _DiskUsageMapBreadcrumbTrail({
    required this.items,
    required this.backTooltip,
    required this.canGoBack,
    required this.onBack,
    required this.onSelect,
  });

  final List<_DiskUsageMapBreadcrumbItem> items;
  final String backTooltip;
  final bool canGoBack;
  final VoidCallback onBack;
  final ValueChanged<NodeId?> onSelect;

  @override
  State<_DiskUsageMapBreadcrumbTrail> createState() =>
      _DiskUsageMapBreadcrumbTrailState();
}

class _DiskUsageMapBreadcrumbTrailState
    extends State<_DiskUsageMapBreadcrumbTrail> {
  final _scrollController = ScrollController();
  String? _lastPathSignature;

  @override
  void initState() {
    super.initState();
    _lastPathSignature = _pathSignature(widget.items);
    _scrollToCurrentPathEnd();
  }

  @override
  void didUpdateWidget(covariant _DiskUsageMapBreadcrumbTrail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _pathSignature(widget.items);
    if (signature == _lastPathSignature) {
      return;
    }
    _lastPathSignature = signature;
    _scrollToCurrentPathEnd();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentPathEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('scan-disk-usage-map-breadcrumb-trail'),
      padding: const EdgeInsets.fromLTRB(10, 0, 8, 8),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('scan-disk-usage-map-back-action'),
            tooltip: widget.backTooltip,
            onPressed: widget.canGoBack ? widget.onBack : null,
            color: _ScanColors.textSoft,
            disabledColor: _ScanColors.textSoft.withAlpha(90),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                },
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: false,
                interactive: true,
                thickness: 3,
                radius: const Radius.circular(999),
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  key: const ValueKey('scan-disk-usage-map-breadcrumb-scroll'),
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      for (
                        var index = 0;
                        index < widget.items.length;
                        index += 1
                      ) ...[
                        if (index > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: _ScanColors.textSoft,
                              size: 16,
                            ),
                          ),
                        _DiskUsageMapBreadcrumbButton(
                          item: widget.items[index],
                          onTap: widget.items[index].selected
                              ? null
                              : () =>
                                    widget.onSelect(widget.items[index].nodeId),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _pathSignature(List<_DiskUsageMapBreadcrumbItem> items) {
    return items
        .map((item) => '${item.nodeId?.value ?? 'root'}:${item.label}')
        .join('/');
  }
}

class _DiskUsageMapBreadcrumbButton extends StatelessWidget {
  const _DiskUsageMapBreadcrumbButton({
    required this.item,
    required this.onTap,
  });

  final _DiskUsageMapBreadcrumbItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.selected ? _ScanColors.cyan : _ScanColors.textSoft;
    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 450),
      child: InkWell(
        key: ValueKey(
          'scan-disk-usage-map-breadcrumb-${item.nodeId?.value ?? 'root'}',
        ),
        onTap: onTap,
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(context).copyWith(
                color: color,
                fontWeight: item.selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

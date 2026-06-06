import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef AppTreeTableRowContextMenuCallback =
    void Function(AppTreeTableRow row, Offset globalPosition);

final class AppTreeTableColumnLabels {
  const AppTreeTableColumnLabels({
    required this.name,
    required this.size,
    required this.percent,
    required this.items,
  });

  final String name;
  final String size;
  final String percent;
  final String items;
}

final class AppTreeTableRow {
  const AppTreeTableRow({
    required this.id,
    required this.name,
    required this.sizeText,
    required this.percentText,
    required this.itemsText,
    required this.progress,
    required this.depth,
    required this.selected,
    required this.hasChildren,
    required this.expanded,
    required this.icon,
    this.loading = false,
    this.queued = false,
    this.warning = false,
    this.danger = false,
    this.dangerText,
    this.stale = false,
    this.disabled = false,
  });

  final String id;
  final String name;
  final String sizeText;
  final String percentText;
  final String itemsText;
  final double progress;
  final int depth;
  final bool selected;
  final bool hasChildren;
  final bool expanded;
  final IconData icon;
  final bool loading;
  final bool queued;
  final bool warning;
  final bool danger;
  final String? dangerText;
  final bool stale;
  final bool disabled;
}

final class AppTreeTableStyle {
  const AppTreeTableStyle({
    required this.backgroundColor,
    required this.headerColor,
    required this.borderColor,
    required this.rowBorderColor,
    required this.selectedRowColor,
    required this.textColor,
    required this.selectedTextColor,
    required this.mutedTextColor,
    required this.iconColor,
    required this.progressTrackColor,
    required this.progressColor,
    required this.selectedProgressColor,
    this.queuedColor = const Color(0xFF22E7F2),
    this.warningColor = const Color(0xFFFACC15),
    this.dangerColor = const Color(0xFFFF5C8A),
    this.focusedBorderColor = const Color(0xFF22E7F2),
    this.disabledOpacity = 0.55,
    this.borderRadius = 8,
    this.headerHeight = 34,
    this.rowHeight = 42,
    this.nameFlex = 5,
    this.sizeFlex = 2,
    this.percentFlex = 2,
    this.itemsFlex = 2,
  });

  final Color backgroundColor;
  final Color headerColor;
  final Color borderColor;
  final Color rowBorderColor;
  final Color selectedRowColor;
  final Color textColor;
  final Color selectedTextColor;
  final Color mutedTextColor;
  final Color iconColor;
  final Color progressTrackColor;
  final Color progressColor;
  final Color selectedProgressColor;
  final Color queuedColor;
  final Color warningColor;
  final Color dangerColor;
  final Color focusedBorderColor;
  final double disabledOpacity;
  final double borderRadius;
  final double headerHeight;
  final double rowHeight;
  final int nameFlex;
  final int sizeFlex;
  final int percentFlex;
  final int itemsFlex;
}

class AppTreeTable extends StatefulWidget {
  const AppTreeTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyState,
    required this.style,
    this.showHeader = true,
    this.onRowTap,
    this.onRowToggleExpansion,
    this.onRowContextMenu,
  });

  final AppTreeTableColumnLabels columns;
  final List<AppTreeTableRow> rows;
  final Widget emptyState;
  final AppTreeTableStyle style;
  final bool showHeader;
  final ValueChanged<AppTreeTableRow>? onRowTap;
  final ValueChanged<AppTreeTableRow>? onRowToggleExpansion;
  final AppTreeTableRowContextMenuCallback? onRowContextMenu;

  @override
  State<AppTreeTable> createState() => _AppTreeTableState();
}

class _AppTreeTableState extends State<AppTreeTable> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'AppTreeTable');
  String? _focusedRowId;

  @override
  void didUpdateWidget(covariant AppTreeTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.rows.any((row) => row.id == _focusedRowId)) {
      _focusedRowId = null;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureFocusedRow();

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveTreeFocusIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveTreeFocusIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _SetTreeExpansionIntent(
          expanded: true,
        ),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _SetTreeExpansionIntent(
          expanded: false,
        ),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _MoveTreeFocusIntent: CallbackAction<_MoveTreeFocusIntent>(
            onInvoke: (intent) {
              _moveFocus(intent.delta);
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activateFocusedRow();
              return null;
            },
          ),
          _SetTreeExpansionIntent: CallbackAction<_SetTreeExpansionIntent>(
            onInvoke: (intent) {
              _setFocusedRowExpansion(intent.expanded);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: _buildTable(),
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: widget.style.backgroundColor,
        borderRadius: BorderRadius.circular(widget.style.borderRadius),
        border: Border.all(color: widget.style.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (widget.showHeader)
            _AppTreeTableHeader(columns: widget.columns, style: widget.style),
          Expanded(
            child: widget.rows.isEmpty
                ? widget.emptyState
                : ListView.builder(
                    primary: false,
                    itemExtent: widget.style.rowHeight,
                    itemCount: widget.rows.length,
                    itemBuilder: (context, index) {
                      final row = widget.rows[index];
                      return _AppTreeTableRowTile(
                        key: ValueKey('app-tree-table-row-${row.id}'),
                        row: row,
                        focused: row.id == _focusedRowId,
                        style: widget.style,
                        onTap: widget.onRowTap == null
                            ? null
                            : () {
                                setState(() {
                                  _focusedRowId = row.id;
                                });
                                widget.onRowTap!(row);
                              },
                        onToggleExpansion:
                            widget.onRowToggleExpansion == null ||
                                !row.hasChildren
                            ? null
                            : () {
                                setState(() {
                                  _focusedRowId = row.id;
                                });
                                widget.onRowToggleExpansion!(row);
                              },
                        onContextMenu: widget.onRowContextMenu == null
                            ? null
                            : (details) {
                                setState(() {
                                  _focusedRowId = row.id;
                                });
                                widget.onRowContextMenu!(
                                  row,
                                  details.globalPosition,
                                );
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _ensureFocusedRow() {
    if (widget.rows.isEmpty) {
      _focusedRowId = null;
      return;
    }
    if (_focusedRowId != null &&
        widget.rows.any((row) => row.id == _focusedRowId)) {
      return;
    }
    for (final row in widget.rows) {
      if (row.selected) {
        _focusedRowId = row.id;
        return;
      }
    }
    _focusedRowId = widget.rows.first.id;
  }

  void _moveFocus(int delta) {
    if (widget.rows.isEmpty) {
      return;
    }
    final currentIndex = widget.rows.indexWhere(
      (row) => row.id == _focusedRowId,
    );
    final safeIndex = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = (safeIndex + delta).clamp(0, widget.rows.length - 1);
    setState(() {
      _focusedRowId = widget.rows[nextIndex].id;
    });
  }

  void _activateFocusedRow() {
    AppTreeTableRow? row;
    for (final candidate in widget.rows) {
      if (candidate.id == _focusedRowId) {
        row = candidate;
        break;
      }
    }
    if (row == null || row.disabled) {
      return;
    }
    widget.onRowTap?.call(row);
  }

  void _setFocusedRowExpansion(bool expanded) {
    final row = _focusedRow();
    if (row == null ||
        row.disabled ||
        !row.hasChildren ||
        row.expanded == expanded) {
      return;
    }
    widget.onRowToggleExpansion?.call(row);
  }

  AppTreeTableRow? _focusedRow() {
    for (final candidate in widget.rows) {
      if (candidate.id == _focusedRowId) {
        return candidate;
      }
    }
    return null;
  }
}

final class _MoveTreeFocusIntent extends Intent {
  const _MoveTreeFocusIntent(this.delta);

  final int delta;
}

final class _SetTreeExpansionIntent extends Intent {
  const _SetTreeExpansionIntent({required this.expanded});

  final bool expanded;
}

class _AppTreeTableHeader extends StatelessWidget {
  const _AppTreeTableHeader({required this.columns, required this.style});

  final AppTreeTableColumnLabels columns;
  final AppTreeTableStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: style.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: style.headerColor,
      child: Row(
        children: [
          Expanded(
            flex: style.nameFlex,
            child: _HeaderText(columns.name, style: style),
          ),
          Expanded(
            flex: style.sizeFlex,
            child: _HeaderText(columns.size, style: style),
          ),
          Expanded(
            flex: style.percentFlex,
            child: _HeaderText(columns.percent, style: style),
          ),
          Expanded(
            flex: style.itemsFlex,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _HeaderText(columns.items, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppTreeTableRowTile extends StatelessWidget {
  const _AppTreeTableRowTile({
    super.key,
    required this.row,
    required this.focused,
    required this.style,
    required this.onTap,
    required this.onToggleExpansion,
    required this.onContextMenu,
  });

  final AppTreeTableRow row;
  final bool focused;
  final AppTreeTableStyle style;
  final VoidCallback? onTap;
  final VoidCallback? onToggleExpansion;
  final GestureTapDownCallback? onContextMenu;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null && !row.disabled,
      enabled: !row.disabled,
      selected: row.selected,
      label: '${row.name}, ${row.sizeText}, ${row.itemsText}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: row.disabled ? null : onContextMenu,
        child: Material(
          color: _rowColor(row, style),
          child: InkWell(
            onTap: row.disabled ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: focused
                        ? style.focusedBorderColor
                        : Colors.transparent,
                    width: focused ? 3 : 0,
                  ),
                  bottom: BorderSide(color: style.rowBorderColor),
                ),
              ),
              child: Opacity(
                opacity: row.disabled || row.stale ? style.disabledOpacity : 1,
                child: Row(
                  children: [
                    Expanded(
                      flex: style.nameFlex,
                      child: Row(
                        children: [
                          SizedBox(width: row.depth.clamp(0, 8) * 18),
                          _TreeDisclosureButton(
                            row: row,
                            style: style,
                            onToggleExpansion: onToggleExpansion,
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            row.icon,
                            size: 20,
                            color: row.danger
                                ? style.dangerColor
                                : style.iconColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              row.name,
                              overflow: TextOverflow.ellipsis,
                              style: _bodyStyle(context).copyWith(
                                color: row.danger
                                    ? style.dangerColor
                                    : row.selected
                                    ? style.selectedTextColor
                                    : style.textColor,
                                fontWeight: row.selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (row.warning) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: style.warningColor,
                            ),
                          ],
                          if (row.danger) ...[
                            const SizedBox(width: 8),
                            _RowStatusPill(
                              icon: Icons.delete_outline,
                              label: row.dangerText,
                              color: style.dangerColor,
                            ),
                          ],
                          if (row.queued) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.add_circle_outline,
                              size: 16,
                              color: style.queuedColor,
                            ),
                          ],
                          if (row.loading) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: style.selectedProgressColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: style.sizeFlex,
                      child: Text(
                        row.sizeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _monoStyle(context, style),
                      ),
                    ),
                    Expanded(
                      flex: style.percentFlex,
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: row.progress.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: style.progressTrackColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  row.selected
                                      ? style.selectedProgressColor
                                      : style.progressColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 56,
                            child: Text(
                              row.percentText,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              textAlign: TextAlign.end,
                              style: _monoStyle(context, style),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: style.itemsFlex,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          row.itemsText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _monoStyle(context, style),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _rowColor(AppTreeTableRow row, AppTreeTableStyle style) {
    if (row.selected) {
      return style.selectedRowColor;
    }
    if (row.danger) {
      return style.dangerColor.withAlpha(24);
    }
    if (row.queued) {
      return style.queuedColor.withAlpha(24);
    }
    return Colors.transparent;
  }
}

class _RowStatusPill extends StatelessWidget {
  const _RowStatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 3 : 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(130)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          if (label != null) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TreeDisclosureButton extends StatelessWidget {
  const _TreeDisclosureButton({
    required this.row,
    required this.style,
    required this.onToggleExpansion,
  });

  final AppTreeTableRow row;
  final AppTreeTableStyle style;
  final VoidCallback? onToggleExpansion;

  @override
  Widget build(BuildContext context) {
    if (!row.hasChildren) {
      return const SizedBox(width: 24, height: 24);
    }

    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        key: ValueKey('app-tree-table-toggle-${row.id}'),
        onPressed: row.disabled ? null : onToggleExpansion,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        tooltip: row.expanded ? 'Collapse' : 'Expand',
        icon: Icon(
          row.expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
          color: style.mutedTextColor,
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {required this.style});

  final String text;
  final AppTreeTableStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: _bodyStyle(context).copyWith(color: style.mutedTextColor),
    );
  }
}

TextStyle _bodyStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(letterSpacing: 0) ??
      const TextStyle(letterSpacing: 0);
}

TextStyle _monoStyle(BuildContext context, AppTreeTableStyle style) {
  return _bodyStyle(context).copyWith(
    color: style.mutedTextColor,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

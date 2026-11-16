part of 'scan_home_page.dart';

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

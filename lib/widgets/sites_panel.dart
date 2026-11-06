import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';

import '../state/shortcuts_controller.dart';
import '../theme/app_theme.dart';
import 'panel_frame.dart';
import 'site_icon.dart';

/// Меню «Мои сайты»: сетка добавленных сайтов, как в приложениях Google.
class SitesPanel extends StatefulWidget {
  final ShortcutsController sites;
  final ValueChanged<String> onOpen;
  const SitesPanel({super.key, required this.sites, required this.onOpen});

  @override
  State<SitesPanel> createState() => _SitesPanelState();
}

class _SitesPanelState extends State<SitesPanel> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: 'Мои сайты',
      action: ListenableBuilder(
        listenable: widget.sites,
        builder: (context, _) {
          if (widget.sites.items.isEmpty) return const SizedBox.shrink();
          return TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: _editing ? AppColors.orange : AppColors.muted,
            ),
            child: Text(_editing ? 'Готово' : 'Изменить',
                style: const TextStyle(fontSize: 12)),
          );
        },
      ),
      child: ListenableBuilder(
        listenable: widget.sites,
        builder: (context, _) {
          final items = widget.sites.items;
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 30),
              child: Text(
                'Здесь будут сайты, которые вы добавите звёздочкой в адресной строке.',
                style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
            child: Wrap(
              spacing: 0,
              runSpacing: 2,
              children: [
                for (final s in items)
                  _SiteTile(
                    key: ValueKey(s.id),
                    site: s,
                    editing: _editing,
                    onTap: () => widget.onOpen(s.url),
                    onRemove: () => widget.sites.remove(s.id),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SiteTile extends StatefulWidget {
  final Shortcut site;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _SiteTile({
    super.key,
    required this.site,
    required this.editing,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_SiteTile> createState() => _SiteTileState();
}

class _SiteTileState extends State<_SiteTile> {
  bool _hover = false;

  Widget _icon() {
    final s = widget.site;
    if (s.icon != null) return Icon(s.icon, color: s.color, size: 32);
    return SiteIcon(
      url: s.url,
      label: s.label,
      iconUrl: s.iconUrl,
      size: 34,
      letterSize: 26,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        width: 84,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.editing ? null : widget.onTap,
              child: Container(
                // Плитка занимает всю свою ширину, иначе значки «ездят» по длине подписи.
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _hover ? const Color(0xFF181B20) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.tile,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0xFF1C2127)),
                      ),
                      child: _icon(),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.site.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFD4D8DD)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.editing)
              Positioned(
                top: 2,
                right: 6,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onRemove,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2227),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.close,
                        size: 13, color: Color(0xFFFF6B6B)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

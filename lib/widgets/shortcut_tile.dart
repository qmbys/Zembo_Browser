import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import '../state/shortcuts_controller.dart';
import '../theme/app_theme.dart';
import 'site_icon.dart';

class ShortcutTile extends StatelessWidget {
  final Shortcut? shortcut; // null — плитка «Добавить»
  final bool editing;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const ShortcutTile({
    super.key,
    this.shortcut,
    this.editing = false,
    this.onTap,
    this.onRemove,
  });

  bool get isAdd => shortcut == null;

  @override
  Widget build(BuildContext context) {
    final label = shortcut?.label ?? 'Добавить';
    return SizedBox(
      width: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              width: 76,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.tile,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFF171B20)),
                    ),
                    child: _icon(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFD4D8DD), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (editing && !isAdd)
            Positioned(
              top: -6,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2227),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.close,
                      size: 14, color: Color(0xFFFF6B6B)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _icon() {
    if (isAdd) {
      return const Icon(Icons.add, color: Color(0xFFADB6C0), size: 29);
    }
    final s = shortcut!;
    if (s.icon != null) return Icon(s.icon, color: s.color, size: 28);
    return SiteIcon(
      url: s.url,
      label: s.label,
      iconUrl: s.iconUrl,
      size: 30,
      letterSize: 24,
    );
  }
}

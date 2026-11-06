import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import '../state/shortcuts_controller.dart';
import '../theme/app_theme.dart';
import '../state/suggest_service.dart';
import 'search_field.dart';
import 'shortcut_tile.dart';
import 'zembo_mark.dart';

class HomeContent extends StatefulWidget {
  final ValueChanged<String>? onSearch;
  final bool showShortcuts;
  final ShortcutsController shortcuts;
  final SuggestService? suggest;

  const HomeContent({
    super.key,
    required this.shortcuts,
    this.suggest,
    this.onSearch,
    this.showShortcuts = true,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _editing = false;

  Future<void> _addShortcut() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF171A1E),
        title: const Text('Добавить ярлык'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                cursorColor: AppColors.orange,
                decoration: InputDecoration(labelText: tr('Название')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                cursorColor: AppColors.orange,
                decoration:
                    InputDecoration(labelText: tr('Адрес сайта')),
                onSubmitted: (_) => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Добавить',
                style: TextStyle(color: AppColors.orange)),
          ),
        ],
      ),
    );

    if (ok == true) {
      widget.shortcuts.add(label: nameCtrl.text, url: urlCtrl.text);
    }
    nameCtrl.dispose();
    urlCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 32),
              child: ConstrainedBox(
                // Контент центрируется по высоте окна и не вылезает за экран.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 736),
                    child: Padding(
                      // Небольшой подъём вверх, как на макете.
                      padding: const EdgeInsets.only(bottom: 70),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ZemboMark(size: 78),
                          const SizedBox(height: 14),
                          const Text(
                            'Zembo Browser',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -.7,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 36),
                          SearchField(onSubmit: widget.onSearch, service: widget.suggest),
                          // Когда ярлыки скрыты, оставляем на их месте пустое место,
                          // чтобы поиск не съезжал вниз.
                          if (!widget.showShortcuts) const SizedBox(height: 128),
                          if (widget.showShortcuts) ...[
                            const SizedBox(height: 40),
                            ListenableBuilder(
                              listenable: widget.shortcuts,
                              builder: (context, _) => Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 28,
                                runSpacing: 24,
                                children: [
                                  for (final s in widget.shortcuts.items)
                                    ShortcutTile(
                                      key: ValueKey(s.id),
                                      shortcut: s,
                                      editing: _editing,
                                      onTap: _editing
                                          ? null
                                          : () => widget.onSearch?.call(s.url),
                                      onRemove: () =>
                                          widget.shortcuts.remove(s.id),
                                    ),
                                  // «Добавить» видно только в режиме редактирования.
                                  if (_editing)
                                    ShortcutTile(onTap: _addShortcut),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showShortcuts)
              Positioned(
                right: 16,
                bottom: 14,
                child: _EditButton(
                  editing: _editing,
                  onTap: () => setState(() => _editing = !_editing),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Неброская кнопка в правом нижнем углу.
class _EditButton extends StatefulWidget {
  final bool editing;
  final VoidCallback onTap;
  const _EditButton({required this.editing, required this.onTap});

  @override
  State<_EditButton> createState() => _EditButtonState();
}

class _EditButtonState extends State<_EditButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.editing;
    final color = active
        ? AppColors.orange
        : (_hover ? const Color(0xFFADB6C0) : const Color(0xFF4A5159));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? Icons.check : Icons.edit_outlined,
                  size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                active ? 'Готово' : 'Редактировать',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

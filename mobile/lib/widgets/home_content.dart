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

  bool _adding = false;
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _addShortcut() => setState(() => _adding = true);

  void _closeForm() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _adding = false;
      _nameCtrl.clear();
      _urlCtrl.clear();
    });
  }

  void _submitForm() {
    final url = _urlCtrl.text.trim();
    if (url.isNotEmpty) {
      widget.shortcuts.add(label: _nameCtrl.text, url: url);
    }
    _closeForm();
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
                            if (_adding)
                              _AddShortcutForm(
                                name: _nameCtrl,
                                url: _urlCtrl,
                                onCancel: _closeForm,
                                onSubmit: _submitForm,
                              )
                            else
                            ListenableBuilder(
                              listenable: widget.shortcuts,
                              builder: (context, _) => _ShortcutGrid(
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


/// Сетка ярлыков: 4 колонки одинаковой ширины, ряды выровнены по колонкам.
class _ShortcutGrid extends StatelessWidget {
  final List<Widget> children;
  const _ShortcutGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const columns = 4;
      final cell = box.maxWidth / columns;
      return Wrap(
        spacing: 0,
        runSpacing: 22,
        children: [
          for (final c in children)
            SizedBox(width: cell, child: Center(child: c)),
        ],
      );
    });
  }
}

/// Форма добавления ярлыка прямо на странице (без отдельного окна).
class _AddShortcutForm extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController url;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  const _AddShortcutForm({
    required this.name,
    required this.url,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Добавить ярлык',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: name,
            cursorColor: AppColors.orange,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: tr('Название')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: url,
            cursorColor: AppColors.orange,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: tr('Адрес сайта')),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Отмена')),
              TextButton(
                onPressed: onSubmit,
                child: const Text('Добавить',
                    style: TextStyle(color: AppColors.orange)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

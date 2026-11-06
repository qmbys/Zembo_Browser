import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';

import '../state/page_menu.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Контекстное меню страницы: картинки, ссылки, текст, видео, поля ввода.
class ContextMenuLayer extends StatelessWidget {
  final TabsController tabs;
  const ContextMenuLayer({super.key, required this.tabs});

  static const double _width = 280;
  static const double _topBar = 100; // высота верхней панели браузера

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tabs,
      builder: (context, _) {
        final c = tabs.ctx;
        if (c == null) return const SizedBox.shrink();

        final entries = _entries(c);
        final height = entries.fold<double>(
            12, (sum, e) => sum + (e is _Sep ? 9 : 34));

        return LayoutBuilder(
          builder: (context, box) {
            final offsetY = tabs.active.fullscreen ? 0.0 : _topBar;
            var left = c.x;
            var top = c.y + offsetY;
            if (left + _width > box.maxWidth - 8) left = box.maxWidth - _width - 8;
            if (top + height > box.maxHeight - 8) top = box.maxHeight - height - 8;
            if (left < 8) left = 8;
            if (top < 8) top = 8;

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: tabs.closeContext,
                    onSecondaryTap: tabs.closeContext,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    color: const Color(0xFF14171B),
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: _width,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF252A30)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final e in entries)
                            e is _Sep
                                ? const Divider(
                                    height: 9,
                                    thickness: 1,
                                    indent: 10,
                                    endIndent: 10,
                                    color: Color(0xFF22272D))
                                : _Item(e as _Entry),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Object> _entries(PageContext c) {
    final out = <Object>[];
    void sep() {
      if (out.isNotEmpty && out.last is! _Sep) out.add(const _Sep());
    }

    void add(IconData icon, String label, VoidCallback onTap) =>
        out.add(_Entry(icon, label, onTap));

    String short(String s) {
      final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      return t.length > 22 ? '${t.substring(0, 22)}…' : t;
    }

    if (c.editable) {
      if (c.text.isNotEmpty) {
        add(Icons.content_cut, 'Вырезать', () => tabs.ctxCut(c));
        add(Icons.copy, 'Копировать', () => tabs.ctxCopy(c.text));
      }
      add(Icons.content_paste, 'Вставить', () => tabs.ctxPaste(c));
      add(Icons.select_all, 'Выделить всё', () => tabs.ctxSelectAll(c));
      return out;
    }

    if (c.text.isNotEmpty) {
      add(Icons.copy, 'Копировать', () => tabs.ctxCopy(c.text));
      add(Icons.search, 'Искать «${short(c.text)}»', () => tabs.ctxSearch(c.text));
    }

    if (c.link.isNotEmpty) {
      sep();
      add(Icons.open_in_new, 'Открыть ссылку в новой вкладке',
          () => tabs.ctxOpenInNewTab(c.link));
      add(Icons.link, 'Копировать ссылку', () => tabs.ctxCopy(c.link));
    }

    if (c.img.isNotEmpty) {
      sep();
      add(Icons.image_outlined, 'Открыть изображение в новой вкладке',
          () => tabs.ctxOpenInNewTab(c.img));
      if (PageContext.isHttp(c.img)) {
        add(Icons.download_outlined, 'Сохранить изображение',
            () => tabs.ctxSaveImage(c));
      }
      add(Icons.link, 'Копировать ссылку на изображение',
          () => tabs.ctxCopy(c.img));
    }

    if (PageContext.isHttp(c.video)) {
      sep();
      add(Icons.link, 'Копировать ссылку на видео', () => tabs.ctxCopy(c.video));
    }
    if (c.video.isNotEmpty || tabs.active.hasVideo) {
      if (PageContext.isHttp(c.video)) {
        // разделитель уже поставлен
      } else {
        sep();
      }
      add(Icons.picture_in_picture_alt_outlined, 'Картинка в картинке', () {
        tabs.closeContext();
        tabs.startPip();
      });
    }

    final specific = c.text.isNotEmpty ||
        c.link.isNotEmpty ||
        c.img.isNotEmpty ||
        c.video.isNotEmpty;
    if (!specific) {
      add(Icons.arrow_back, 'Назад', () {
        tabs.closeContext();
        tabs.back();
      });
      add(Icons.arrow_forward, 'Вперёд', () {
        tabs.closeContext();
        tabs.forward();
      });
      add(Icons.refresh, 'Обновить', () {
        tabs.closeContext();
        tabs.reload();
      });
      sep();
    } else {
      sep();
    }
    add(Icons.content_copy, 'Копировать адрес страницы', () => tabs.ctxCopy(c.page));
    return out;
  }
}

class _Sep {
  const _Sep();
}

class _Entry {
  _Entry(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _Item extends StatefulWidget {
  final _Entry entry;
  const _Item(this.entry);

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.entry.onTap,
        child: Container(
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFF1C2026) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.entry.icon, size: 17, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

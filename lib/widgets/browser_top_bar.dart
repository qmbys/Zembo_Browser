import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../models/browser_tab.dart';
import '../state/downloads_controller.dart';
import '../state/mail_controller.dart';
import '../state/panels_controller.dart';
import '../state/shortcuts_controller.dart';
import '../state/suggest_service.dart';
import 'download_ring.dart';
import 'protection_panel.dart';
import 'suggest_anchor.dart';
import 'zembo_icons.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';
import 'window_controls.dart';
import 'zembo_mark.dart';

class BrowserTopBar extends StatefulWidget {
  final TabsController controller;
  final PanelsController panels;
  final DownloadsController downloads;
  final MailController mail;
  final ShortcutsController shortcuts;
  final ShortcutsController menuSites;
  final SuggestService suggest;
  const BrowserTopBar({
    super.key,
    required this.controller,
    required this.panels,
    required this.downloads,
    required this.mail,
    required this.shortcuts,
    required this.menuSites,
    required this.suggest,
  });

  @override
  State<BrowserTopBar> createState() => _BrowserTopBarState();
}

class _BrowserTopBarState extends State<BrowserTopBar> {
  final _address = TextEditingController();
  final _addressFocus = FocusNode();

  TabsController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_syncAddress);
    c.addressFocus.addListener(_focusAddress);
    _syncAddress();
  }

  void _focusAddress() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _addressFocus.requestFocus();
      _address.selection =
          TextSelection(baseOffset: 0, extentOffset: _address.text.length);
    });
  }

  @override
  void dispose() {
    c.removeListener(_syncAddress);
    c.addressFocus.removeListener(_focusAddress);
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  int? _lastTabId;
  String _lastAddress = '';

  void _syncAddress() {
    final tab = c.active;
    final addr = tab.address;
    final tabChanged = tab.id != _lastTabId;
    // Не перебиваем текст, пока пользователь печатает в адресной строке.
    if (tabChanged || (addr != _lastAddress && !_addressFocus.hasFocus)) {
      _address.text = addr;
    }
    _lastTabId = tab.id;
    _lastAddress = addr;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        c,
        widget.panels,
        widget.downloads,
        widget.mail,
        c.settings,
        widget.shortcuts,
        widget.menuSites,
      ]),
      builder: (context, _) {
        final active = c.active;
        return Container(
          height: 100,
          color: AppColors.chrome,
          child: Column(
            children: [
              _TabStrip(controller: c),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    _ToolbarButton(
                      icon: Icons.arrow_back,
                      muted: active.isHome,
                      onTap: active.isHome ? null : c.back,
                    ),
                    _ToolbarButton(
                      icon: Icons.arrow_forward,
                      muted: !c.canGoForward,
                      onTap: c.canGoForward ? c.forward : null,
                    ),
                    _ToolbarButton(
                      icon: Icons.refresh,
                      muted: !(active.isBrowsing || active.isSearch),
                      onTap: (active.isBrowsing || active.isSearch) ? c.reload : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _addressField()),
                    const SizedBox(width: 12),
                    ..._rightButtons(active),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Кнопки справа от адресной строки: порядок и видимость задаются в настройках.
  List<Widget> _rightButtons(BrowserTab active) {
    final out = <Widget>[];
    for (final id in c.settings.toolbarOrder) {
      if (!c.settings.toolbarVisible(id)) continue;
      switch (id) {
        case 'sites':
          out.add(_ToolbarButton(
            iconWidget: ZemboGridIcon(active: widget.panels.open == PanelKind.sites),
            tooltip: tr('Мои сайты'),
            onTap: () => widget.panels.toggle(PanelKind.sites),
          ));
        case 'pip':
          // Появляется, только когда на странице есть плеер.
          if (active.isBrowsing && active.hasVideo) {
            out.add(_ToolbarButton(
              icon: Icons.picture_in_picture_alt_outlined,
              tooltip: tr('Картинка в картинке'),
              onTap: c.startPip,
            ));
          }
        case 'extensions':
          out.add(_ToolbarButton(
            icon: Icons.extension_outlined,
            tooltip: tr('Расширения'),
            active: widget.panels.open == PanelKind.extensions,
            onTap: () => widget.panels.toggle(PanelKind.extensions),
          ));
        case 'downloads':
          out.add(_ToolbarButton(
            icon: Icons.download_outlined,
            tooltip: tr(widget.downloads.activeSummary ?? 'Загрузки'),
            active: widget.panels.open == PanelKind.downloads,
            ring: widget.downloads.hasActive,
            onTap: () => widget.panels.toggle(PanelKind.downloads),
          ));
        case 'mail':
          out.add(_ToolbarButton(
            icon: Icons.mail_outline,
            tooltip: tr(widget.mail.totalUnseen > 0
                ? 'Почта · непрочитанных: ${widget.mail.totalUnseen}'
                : 'Почта'),
            active: widget.panels.open == PanelKind.mail,
            badge: widget.mail.totalUnseen > 0,
            onTap: () => widget.panels.toggle(PanelKind.mail),
          ));
        case 'shield':
          out.add(_ToolbarButton(
            icon: shieldIconFor(c.settings.protectionLevel),
            tooltip: tr('Уровень защиты'),
            muted: c.settings.protectionLevel == 0,
            onTap: () => widget.panels.toggle(PanelKind.protection),
          ));
        case 'menu':
          out.add(_MenuButton(controller: c, panels: widget.panels));
      }
    }
    return out;
  }

  Widget _addressField() {
    final field = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF171B20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 19, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _address,
              focusNode: _addressFocus,
              onSubmitted: (v) {
                _addressFocus.unfocus();
                c.navigate(v);
              },
              cursorColor: AppColors.orange,
              style: const TextStyle(fontSize: 13, color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: tr('Введите поисковый запрос или адрес сайта'),
                hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          // Настройки сайта: cookie, местоположение, микрофон и т.д.
          if (c.active.isBrowsing)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message: tr('Настройки сайта'),
                child: InkResponse(
                  radius: 14,
                  onTap: () => widget.panels.toggle(PanelKind.site),
                  child: Icon(Icons.tune,
                      size: 17,
                      color: widget.panels.open == PanelKind.site
                          ? AppColors.foreground
                          : AppColors.muted),
                ),
              ),
            ),
          // Кнопка «скопировать адрес» (видна, когда в строке что-то есть).
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _address,
            builder: (context, value, _) {
              if (value.text.isEmpty || !c.settings.showCopyButton) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: tr('Скопировать адрес'),
                  child: InkResponse(
                    radius: 14,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value.text));
                      c.showToast('Адрес скопирован');
                    },
                    child: const Icon(Icons.content_copy_outlined,
                        size: 17, color: AppColors.muted),
                  ),
                ),
              );
            },
          ),
          if (c.active.isBrowsing && c.settings.showStarButton) _starButton(),
        ],
      ),
    );

    // Подсказки под адресной строкой: история и варианты поисковой системы.
    return SuggestAnchor(
      controller: _address,
      focusNode: _addressFocus,
      service: widget.suggest,
      onPick: (s) {
        _addressFocus.unfocus();
        c.navigate(s.url ?? s.text);
      },
      child: field,
    );
  }

  /// Название для нового ярлыка: заголовок страницы (если короткий) или домен.
  String _siteLabel(BrowserTab t) {
    final host = (Uri.tryParse(t.url!)?.host ?? '').replaceFirst('www.', '');
    final title = (t.pageTitle ?? '').trim();
    if (title.isNotEmpty && title.length <= 18) return title;
    return host.isEmpty ? t.url! : host;
  }

  /// Звёздочка: добавить сайт в ярлыки на главной и/или в меню «Мои сайты».
  Widget _starButton() {
    final tab = c.active;
    final url = tab.url!;
    final inShortcuts = widget.shortcuts.containsUrl(url);
    final inMenu = widget.menuSites.containsUrl(url);
    final saved = inShortcuts || inMenu;

    return PopupMenuButton<String>(
      tooltip: tr('Добавить сайт'),
      padding: EdgeInsets.zero,
      color: const Color(0xFF171A1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF252A30)),
      ),
      offset: const Offset(0, 36),
      onSelected: (v) {
        if (v == 'shortcuts') {
          if (inShortcuts) {
            widget.shortcuts.removeByUrl(url);
            c.showToast('Убрано из ярлыков');
          } else {
            widget.shortcuts.add(
                label: _siteLabel(tab), url: url, iconUrl: tab.iconUrl);
            c.showToast('Добавлено в ярлыки на главной');
          }
        } else {
          if (inMenu) {
            widget.menuSites.removeByUrl(url);
            c.showToast('Убрано из меню');
          } else {
            widget.menuSites.add(
                label: _siteLabel(tab), url: url, iconUrl: tab.iconUrl);
            c.showToast('Добавлено в меню «Мои сайты»');
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'shortcuts',
          child: Row(children: [
            Icon(inShortcuts ? Icons.check_box : Icons.add_box_outlined,
                size: 18,
                color: inShortcuts ? AppColors.orange : const Color(0xFFCAD0D7)),
            const SizedBox(width: 12),
            Text(inShortcuts ? 'В ярлыках на главной' : 'В ярлыки на главной',
                style: const TextStyle(fontSize: 14)),
          ]),
        ),
        PopupMenuItem(
          value: 'menu',
          child: Row(children: [
            Icon(inMenu ? Icons.check_box : Icons.apps,
                size: 18,
                color: inMenu ? AppColors.orange : const Color(0xFFCAD0D7)),
            const SizedBox(width: 12),
            Text(inMenu ? 'В меню «Мои сайты»' : 'В меню «Мои сайты»',
                style: const TextStyle(fontSize: 14)),
          ]),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(
          saved ? Icons.star : Icons.star_border,
          size: 19,
          color: saved ? Colors.white : AppColors.muted,
        ),
      ),
    );
  }
}

/// Строка вкладок + перетаскиваемая область + кнопки окна.
class _TabStrip extends StatefulWidget {
  final TabsController controller;
  const _TabStrip({required this.controller});

  @override
  State<_TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<_TabStrip> {
  static const double _maxTabWidth = 240;
  static const double _minTabWidth = 40;
  static const double _minActiveWidth = 64; // иконка + крестик
  static const double _plusWidth = 44;
  static const double _minDragArea = 40;
  static const double _controlsWidth = 46 * 3;

  final _scroll = ScrollController();
  int _lastCount = 0;
  int _lastActive = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToActive(double offset, double width, double viewport) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    double target = pos.pixels;
    if (offset < pos.pixels) {
      target = offset;
    } else if (offset + width > pos.pixels + viewport) {
      target = offset + width - viewport;
    }
    target = target.clamp(0.0, pos.maxScrollExtent).toDouble();
    if (target != pos.pixels) _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return SizedBox(
      height: 52,
      child: LayoutBuilder(
        builder: (context, box) {
          final tabs = c.tabs;
          final available = (box.maxWidth - 8 - _plusWidth - _minDragArea - _controlsWidth)
              .clamp(0.0, double.infinity)
              .toDouble();
          final base = (available / tabs.length)
              .clamp(_minTabWidth, _maxTabWidth)
              .toDouble();

          double widthOf(BrowserTab t) => t.id == c.activeId
              ? (base < _minActiveWidth ? _minActiveWidth : base)
              : base;

          final total = tabs.fold<double>(0, (sum, t) => sum + widthOf(t));
          final viewport = total < available ? total : available;

          // Прокрутить к активной вкладке, если она появилась / сменилась.
          final activeIndex = tabs.indexWhere((t) => t.id == c.activeId);
          if (tabs.length != _lastCount || activeIndex != _lastActive) {
            _lastCount = tabs.length;
            _lastActive = activeIndex;
            double off = 0;
            for (var i = 0; i < activeIndex; i++) {
              off += widthOf(tabs[i]);
            }
            final w = widthOf(tabs[activeIndex]);
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToActive(off, w, viewport));
          }

          return Row(
            children: [
              const SizedBox(width: 8),
              SizedBox(
                width: viewport,
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent && _scroll.hasClients) {
                      final pos = _scroll.position;
                      final next = (pos.pixels + event.scrollDelta.dy + event.scrollDelta.dx)
                          .clamp(0.0, pos.maxScrollExtent)
                          .toDouble();
                      _scroll.jumpTo(next);
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        for (final tab in tabs)
                          _TabItem(
                            key: ValueKey(tab.id),
                            tab: tab,
                            width: widthOf(tab),
                            active: tab.id == c.activeId,
                            onSelect: () => c.select(tab.id),
                            onClose: () => c.close(tab.id),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              _NewTabButton(onTap: c.addTab),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                  child: const DragToMoveArea(
                    child: SizedBox(height: 52, width: double.infinity),
                  ),
                ),
              ),
              const WindowControls(),
            ],
          );
        },
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  final BrowserTab tab;
  final double width;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  const _TabItem({
    super.key,
    required this.tab,
    required this.width,
    required this.active,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final wide = widget.width >= 90;
    final showClose = wide || widget.active;
    final bg = widget.active
        ? const Color(0xFF15171A)
        : (_hover ? const Color(0xFF101215) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: widget.width,
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: wide ? 14 : 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment:
                  wide ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (widget.tab.isSettings)
                  const Icon(Icons.settings, size: 20, color: AppColors.muted)
                else if (widget.tab.loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.orange),
                  )
                else if (widget.tab.iconUrl != null || widget.tab.faviconUrl != null)
                  _Favicon(
                    url: widget.tab.iconUrl ?? widget.tab.faviconUrl!,
                    fallbackUrl: widget.tab.faviconUrl,
                  )
                else
                  const ZemboMark(size: 22),
                if (wide) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.active
                            ? AppColors.foreground
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ],
                if (showClose) ...[
                  SizedBox(width: wide ? 8 : 4),
                  _CloseButton(onTap: widget.onClose),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Иконка сайта в заголовке вкладки. Если загрузить не удалось — логотип Zembo.
class _Favicon extends StatelessWidget {
  final String url;
  final String? fallbackUrl;
  const _Favicon({required this.url, this.fallbackUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            url,
            key: ValueKey(url),
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) {
              final f = fallbackUrl;
              if (f == null || f == url) return const ZemboMark(size: 22);
              return Image.network(
                f,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const ZemboMark(size: 22),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Крестик вкладки: при наведении слегка краснеет.
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? const Color(0x33FF4545) : Colors.transparent,
          ),
          child: Icon(
            Icons.close,
            size: 16,
            color: _hover ? const Color(0xFFFF6B6B) : const Color(0xCCFFFFFF),
          ),
        ),
      ),
    );
  }
}

class _NewTabButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewTabButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Вкладки прижаты к низу и имеют высоту 40 — плюс выравниваем по их центру.
    return SizedBox(
      width: 44,
      height: 52,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            onPressed: onTap,
            splashRadius: 16,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add, size: 22, color: Color(0xE6FFFFFF)),
            tooltip: tr('Новая вкладка'),
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final bool muted;
  final bool active;
  final bool badge;
  final bool ring;
  final String? tooltip;
  final VoidCallback? onTap;
  const _ToolbarButton({
    this.icon,
    this.iconWidget,
    this.muted = false,
    this.active = false,
    this.badge = false,
    this.ring = false,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? const Color(0xFF68717A)
        : (active ? AppColors.orange : const Color(0xFFCAD0D7));
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (icon == Icons.download_outlined) DownloadRing(active: ring),
          IconButton(
            onPressed: onTap ?? (muted ? null : () {}),
            tooltip: tooltip,
            splashRadius: 18,
            padding: EdgeInsets.zero,
            icon: iconWidget ?? Icon(icon, size: 21, color: color),
          ),
          if (badge)
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Меню «три точки».
class _MenuButton extends StatelessWidget {
  final TabsController controller;
  final PanelsController panels;
  const _MenuButton({required this.controller, required this.panels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: PopupMenuButton<String>(
        tooltip: '',
        padding: EdgeInsets.zero,
        color: const Color(0xFF171A1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF252A30)),
        ),
        offset: const Offset(0, 42),
        icon: const Icon(Icons.more_vert, size: 21, color: Color(0xFFCAD0D7)),
        onSelected: (value) {
          switch (value) {
            case 'new_tab':
              controller.addTab();
            case 'downloads':
              panels.show(PanelKind.downloads);
            case 'extensions':
              panels.show(PanelKind.extensions);
            case 'settings':
              controller.openSettings();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'new_tab',
            child: Row(children: [
              Icon(Icons.add, size: 18, color: Color(0xFFCAD0D7)),
              SizedBox(width: 12),
              Text('Новая вкладка', style: TextStyle(fontSize: 14)),
            ]),
          ),
          PopupMenuItem(
            value: 'downloads',
            child: Row(children: [
              Icon(Icons.download_outlined, size: 18, color: Color(0xFFCAD0D7)),
              SizedBox(width: 12),
              Text('Загрузки', style: TextStyle(fontSize: 14)),
            ]),
          ),
          PopupMenuItem(
            value: 'extensions',
            child: Row(children: [
              Icon(Icons.extension_outlined, size: 18, color: Color(0xFFCAD0D7)),
              SizedBox(width: 12),
              Text('Расширения', style: TextStyle(fontSize: 14)),
            ]),
          ),
          PopupMenuItem(
            value: 'settings',
            child: Row(children: [
              Icon(Icons.settings_outlined, size: 18, color: Color(0xFFCAD0D7)),
              SizedBox(width: 12),
              Text('Настройки', style: TextStyle(fontSize: 14)),
            ]),
          ),
        ],
      ),
    );
  }
}

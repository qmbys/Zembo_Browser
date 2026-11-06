import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import 'package:webview_windows/webview_windows.dart';
import '../state/app_settings.dart';
import '../state/downloads_controller.dart';
import '../state/filter_lists.dart';
import '../state/filter_proxy.dart';
import '../state/history_controller.dart';
import '../state/keyboard_shortcuts.dart';
import '../state/mail_controller.dart';
import '../state/single_instance.dart';
import '../state/passwords_controller.dart';
import '../state/suggest_service.dart';
import '../state/panels_controller.dart';
import '../state/shortcuts_controller.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/browser_top_bar.dart';
import '../widgets/home_content.dart';
import '../widgets/context_menu_layer.dart';
import '../widgets/mail_suggest_layer.dart';
import '../widgets/password_layer.dart';
import '../widgets/permission_layer.dart';
import '../widgets/panel_host.dart';
import '../widgets/search_results_page.dart';
import '../widgets/pip_overlay.dart';
import '../widgets/web_page.dart';
import 'settings_page.dart';

class BrowserHomePage extends StatefulWidget {
  final AppSettings settings;
  final FilterLists? lists;
  final FilterProxy? proxy;
  final ShortcutsController? shortcuts;
  final ShortcutsController? menuSites;
  final HistoryController? history;
  const BrowserHomePage({
    super.key,
    required this.settings,
    this.lists,
    this.proxy,
    this.shortcuts,
    this.menuSites,
    this.history,
  });

  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  final _downloads = DownloadsController();
  final _panels = PanelsController();
  late final MailController _mail = MailController(widget.settings);
  late final PasswordsController _passwords = PasswordsController(widget.settings);
  late final HistoryController _history = widget.history ?? HistoryController();
  late final SuggestService _suggest = SuggestService(widget.settings, _history);
  late final TabsController _tabs =
      TabsController(widget.settings, _downloads, _history);
  late final ShortcutsController _shortcuts =
      widget.shortcuts ?? ShortcutsController();
  late final ShortcutsController _menuSites = widget.menuSites ??
      ShortcutsController(fileName: 'menu.json', defaults: false);
  late final KeyboardShortcuts _keys =
      KeyboardShortcuts(tabs: _tabs, panels: _panels);

  @override
  void initState() {
    super.initState();
    // При начале загрузки показываем панель загрузок.
    _downloads.onStarted = () => _panels.show(PanelKind.downloads);
    _downloads.currentPage = () => _tabs.active.url;
    _downloads.onOpenPage = (url) {
      _tabs.addTab();
      _tabs.navigate(url);
    };
    _downloads.init();
    _tabs.mail = _mail;
    _mail.init();
    _tabs.passwords = _passwords;
    _passwords.init();
    _keys.attach();
    // Ссылки из других программ (браузер по умолчанию).
    _urlSub = SingleInstance.urls.listen(_openExternal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final u in SingleInstance.takePending()) {
        _openExternal(u);
      }
    });
  }

  StreamSubscription<String>? _urlSub;

  void _openExternal(String url) {
    // Пустую новую вкладку используем, иначе открываем новую.
    if (!_tabs.active.isHome) _tabs.addTab();
    _tabs.navigate(url);
  }

  @override
  void dispose() {
    _urlSub?.cancel();
    _keys.detach();
    _tabs.dispose();
    _downloads.dispose();
    _mail.dispose();
    _passwords.dispose();
    _panels.dispose();
    if (widget.shortcuts == null) _shortcuts.dispose();
    if (widget.menuSites == null) _menuSites.dispose();
    _suggest.dispose();
    if (widget.history == null) _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
        children: [
          // В полноэкранном режиме видео верхняя панель скрывается.
          ListenableBuilder(
            listenable: _tabs,
            builder: (context, _) => _tabs.active.fullscreen
                ? const SizedBox.shrink()
                : BrowserTopBar(
                    controller: _tabs,
                    panels: _panels,
                    downloads: _downloads,
                    mail: _mail,
                    shortcuts: _shortcuts,
                    menuSites: _menuSites,
                    suggest: _suggest,
                  ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([_tabs, widget.settings]),
              builder: (context, _) {
                final tab = _tabs.active;
                if (tab.isSettings) {
                  return SettingsPage(
                    key: ValueKey('settings-${tab.id}'),
                    settings: widget.settings,
                    history: _history,
                    passwords: _passwords,
                    downloads: _downloads,
                    onOpenUrl: (url) {
                      _tabs.addTab();
                      _tabs.navigate(url);
                    },
                  );
                }
                if (tab.isSearch) {
                  return SearchResultsPage(
                    key: ValueKey('search-${tab.id}-${tab.search!.query}'),
                    tab: tab,
                    tabs: _tabs,
                    suggest: _suggest,
                  );
                }
                if (tab.isBrowsing) {
                  return WebPage(key: ValueKey('web-${tab.id}'), tab: tab, tabs: _tabs);
                }
                // key — чтобы у каждой вкладки было своё состояние (режим редактирования и т.п.)
                return HomeContent(
                  key: ValueKey('home-${tab.id}'),
                  onSearch: _tabs.navigate,
                  shortcuts: _shortcuts,
                  suggest: _suggest,
                  showShortcuts: widget.settings.showShortcuts,
                );
              },
            ),
          ),
        ],
          ),
          // Скрытая страница для получения результатов поиска (за краем экрана).
          Positioned(
            left: -4000,
            top: 0,
            width: 1280,
            height: 800,
            child: ListenableBuilder(
              listenable: _tabs,
              builder: (context, _) {
                final c = _tabs.scraperWeb;
                return c == null ? const SizedBox.shrink() : Webview(c);
              },
            ),
          ),
          // Окошко «картинка в картинке» и короткие сообщения.
          Positioned.fill(child: PipOverlay(tabs: _tabs)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: ListenableBuilder(
              listenable: _tabs,
              builder: (context, _) {
                final text = _tabs.toast;
                if (text == null) return const SizedBox.shrink();
                return Center(
                  child: Material(
                    color: const Color(0xFF1B1F24),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      child: Text(text,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.foreground)),
                    ),
                  ),
                );
              },
            ),
          ),
          // Панели расширений и загрузок поверх страницы.
          Positioned.fill(
            child: PanelHost(
              panels: _panels,
              settings: widget.settings,
              tabs: _tabs,
              downloads: _downloads,
              mail: _mail,
              lists: widget.lists,
              proxy: widget.proxy,
              menuSites: _menuSites,
            ),
          ),
          // Контекстное меню страницы (правая кнопка мыши).
          Positioned.fill(child: ContextMenuLayer(tabs: _tabs)),
          // Подсказка привязанных почт под полем входа на сайте.
          Positioned.fill(
            child: MailSuggestLayer(tabs: _tabs, mail: _mail, panels: _panels),
          ),
          // Сохранённые логины и предложение сохранить пароль.
          Positioned.fill(
            child: PasswordLayer(tabs: _tabs, passwords: _passwords),
          ),
          // Запрос сайта на доступ: местоположение, микрофон, камера.
          Positioned.fill(child: PermissionLayer(tabs: _tabs)),
        ],
      ),
    );
  }
}

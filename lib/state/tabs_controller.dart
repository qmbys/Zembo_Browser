import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

import '../models/browser_tab.dart';
import 'ad_blocklist.dart';
import 'app_settings.dart';
import 'brave_scraper.dart';
import 'brave_search.dart';
import 'builtin_scripts.dart';
import 'downloads_controller.dart';
import 'history_controller.dart';
import 'keyboard_shortcuts.dart';
import 'mail_controller.dart';
import 'mail_script.dart';
import 'password_script.dart';
import 'passwords_controller.dart';
import 'safe_browsing.dart';
import 'page_menu.dart';
import 'pip_script.dart';
import 'scroll_script.dart';
import 'site_permissions.dart';
import 'site_reputation.dart';

class TabsController extends ChangeNotifier {
  TabsController(this.settings, this.downloads, this.history) {
    final first = BrowserTab(id: _nextId++);
    _tabs.add(first);
    _activeId = first.id;
    _lastRejectCookies = settings.rejectCookies;
    _lastDark = settings.darkSites;
    _lastGoogleDark = settings.googleDark;
    _lastLang = settings.siteLanguage ?? '';
    _lastPw = '${settings.offerPasswords}/${settings.autofillPasswords}';
    _lastAdBlock = settings.adBlock;
    _lastAllow = settings.adAllowHosts.join(',');
    _lastHidden = jsonEncode(settings.hiddenSelectors);
    _lastScroll = '${settings.smoothScroll}/${settings.scrollSpeed}';
    _lastDnt = settings.doNotTrack;
    settings.addListener(_onSettingsChanged);
    scraper.addListener(notifyListeners);
    sitePerms.init().then((_) => _lastCookieSig = sitePerms.cookieSignature);
    sitePerms.addListener(_onSitePermsChanged);
  }

  // ---------- настройки отдельных сайтов ----------

  final SitePermissions sitePerms = SitePermissions();
  String _lastCookieSig = '';
  PermissionAsk? permAsk;
  Future<void> _permChain = Future.value();

  void _onSitePermsChanged() {
    final sig = sitePerms.cookieSignature;
    if (sig == _lastCookieSig) return;
    _lastCookieSig = sig;
    for (final t in _tabs) {
      _applyScripts(t);
    }
  }

  static PermKind? _permKindOf(WebviewPermissionKind k) {
    switch (k) {
      case WebviewPermissionKind.microphone:
        return PermKind.microphone;
      case WebviewPermissionKind.camera:
        return PermKind.camera;
      case WebviewPermissionKind.geoLocation:
        return PermKind.location;
      case WebviewPermissionKind.notifications:
        return PermKind.notifications;
      case WebviewPermissionKind.clipboardRead:
        return PermKind.clipboard;
      case WebviewPermissionKind.otherSensors:
        return PermKind.sensors;
      case WebviewPermissionKind.unknown:
        return null;
    }
  }

  /// Страница просит доступ: смотрим настройки сайта, при необходимости спрашиваем.
  Future<WebviewPermissionDecision> onPermission(BrowserTab tab, String url,
      WebviewPermissionKind kind, bool userInitiated) {
    final pk = _permKindOf(kind);
    final host = Uri.tryParse(url)?.host ?? '';
    if (pk == null || host.isEmpty) {
      return Future.value(WebviewPermissionDecision.deny);
    }
    final run = _permChain.then((_) => _decidePermission(tab, host, pk));
    _permChain = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<WebviewPermissionDecision> _decidePermission(
      BrowserTab tab, String host, PermKind pk) async {
    switch (sitePerms.get(host, pk)) {
      case PermValue.allow:
        return WebviewPermissionDecision.allow;
      case PermValue.block:
        return WebviewPermissionDecision.deny;
      case PermValue.ask:
        break;
    }
    if (_disposed || tab.closed) return WebviewPermissionDecision.deny;
    final ask = PermissionAsk(tab.id, SitePermissions.hostKey(host), pk);
    permAsk = ask;
    notifyListeners();
    final allow = await ask.result.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => false,
    );
    if (identical(permAsk, ask)) {
      permAsk = null;
      notifyListeners();
    }
    return allow ? WebviewPermissionDecision.allow : WebviewPermissionDecision.deny;
  }

  /// Ответ пользователя на запрос доступа. Решение запоминается для сайта.
  void answerPermission(bool allow) {
    final a = permAsk;
    if (a == null || a.result.isCompleted) return;
    sitePerms.set(a.host, a.kind, allow ? PermValue.allow : PermValue.block);
    a.result.complete(allow);
  }

  /// «Не сейчас»: отказ без запоминания.
  void dismissPermission() {
    final a = permAsk;
    if (a == null || a.result.isCompleted) return;
    a.result.complete(false);
  }

  final AppSettings settings;
  final DownloadsController downloads;
  final HistoryController history;
  late final BraveSearchApi _brave = BraveSearchApi(settings);
  late final BraveScraper scraper = BraveScraper(settings);

  /// Скрытая страница, из которой берутся результаты (показывается за краем экрана).
  WebviewController? get scraperWeb => scraper.controller;
  final List<BrowserTab> _tabs = [];
  int _nextId = 0;
  late int _activeId;
  bool _disposed = false;
  bool _windowFs = false;
  int? _pipPending;
  Timer? _pipTimer;

  /// Короткое сообщение внизу окна (например, «на странице нет видео»).
  String? toast;
  Timer? _toastTimer;

  /// Открытое контекстное меню страницы (правая кнопка мыши).
  PageContext? ctx;

  /// Привязанные почты (подсказка адресов в полях входа на сайтах).
  MailController? mail;

  /// Где показать подсказку почт (поле ввода на странице).
  MailPrompt? mailPrompt;

  /// Менеджер паролей, подсказка логинов и предложение сохранить пароль.
  PasswordsController? passwords;
  PasswordPrompt? pwPrompt;
  PasswordSavePrompt? pwSave;
  Timer? _pwSaveTimer;
  late bool _lastRejectCookies;
  late bool _lastDark;
  late bool _lastAdBlock;
  late String _lastAllow;
  late String _lastHidden;
  late String _lastScroll;
  late bool _lastDnt;
  late String _lastLang;
  late bool _lastGoogleDark;
  late String _lastPw;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get activeId => _activeId;
  BrowserTab get active => _tabs.firstWhere((t) => t.id == _activeId);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _pwSaveTimer?.cancel();
    sitePerms.removeListener(_onSitePermsChanged);
    sitePerms.dispose();
    _disposed = true;
    _pipTimer?.cancel();
    _toastTimer?.cancel();
    _brave.dispose();
    scraper.dispose();
    settings.removeListener(_onSettingsChanged);
    for (final t in _tabs) {
      _disposeWeb(t);
    }
    super.dispose();
  }

  // ---------- сочетания клавиш ----------

  /// Нажатие клавиш внутри страницы сайта (приходит из скрипта страницы).
  void Function(String code, bool ctrl, bool shift, bool alt, bool repeat)?
      onWebKey;

  /// Увеличивается, когда нужно перевести фокус в адресную строку.
  final ValueNotifier<int> addressFocus = ValueNotifier<int>(0);
  void requestAddressFocus() => addressFocus.value++;

  final List<String> _closedTabs = [];

  void reopenClosed() {
    if (_closedTabs.isEmpty) {
      showToast('Нет закрытых вкладок');
      return;
    }
    final v = _closedTabs.removeLast();
    addTab();
    navigate(v);
  }

  void selectRelative(int delta) {
    if (_tabs.length < 2) return;
    final i = _tabs.indexWhere((t) => t.id == _activeId);
    final next = (i + delta) % _tabs.length;
    select(_tabs[next < 0 ? next + _tabs.length : next].id);
  }

  /// Вкладка по номеру; -1 — последняя.
  void selectIndex(int i) {
    if (_tabs.isEmpty) return;
    final idx = i < 0 ? _tabs.length - 1 : i;
    if (idx >= _tabs.length) return;
    select(_tabs[idx].id);
  }

  // ---------- масштаб ----------

  static const _zoomSteps = <double>[
    0.5, 0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0
  ];

  void zoomIn() => _zoomStep(1);
  void zoomOut() => _zoomStep(-1);
  void zoomReset() => _zoomSet(active, 1.0);

  void _zoomStep(int dir) {
    final t = active;
    if (!t.isBrowsing && !t.isSearch) return;
    final cur = t.isSearch ? t.searchZoom : t.zoom;
    var i = 0;
    for (var k = 0; k < _zoomSteps.length; k++) {
      if ((_zoomSteps[k] - cur).abs() < (_zoomSteps[i] - cur).abs()) i = k;
    }
    i = (i + dir).clamp(0, _zoomSteps.length - 1);
    _zoomSet(t, _zoomSteps[i]);
  }

  void _zoomSet(BrowserTab t, double z) {
    if (!t.isBrowsing && !t.isSearch) return;
    if (t.isSearch) {
      for (final o in _tabs) {
        if (o.isSearch) o.searchZoom = z;
      }
      settings.searchZoom = z;
    } else {
      t.zoom = z;
      t.web?.setZoomFactor(z).catchError((_) {});
      settings.setZoomForHost(Uri.tryParse(t.url ?? '')?.host ?? '', z);
    }
    showToast('Масштаб ${(z * 100).round()}%');
  }

  // ---------- вкладки ----------

  void addTab({bool settings = false}) {
    final tab = BrowserTab(id: _nextId++, isSettings: settings);
    _tabs.add(tab);
    _activeId = tab.id;
    notifyListeners();
  }

  /// Открывает вкладку настроек (если уже открыта — переключается на неё).
  void openSettings() {
    final existing = _tabs.where((t) => t.isSettings);
    if (existing.isNotEmpty) {
      select(existing.first.id);
    } else {
      addTab(settings: true);
    }
  }

  void select(int id) {
    if (_activeId == id) return;
    _activeId = id;
    ctx = null;
    mailPrompt = null;
    pwPrompt = null;
    // Вернулись на вкладку с видео — картинка в картинке больше не нужна.
    for (final t in _tabs) {
      if (t.id == id && t.pip) exitPip(t);
    }
    _syncWindowFullscreen();
    notifyListeners();
  }

  void close(int id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final tab = _tabs.removeAt(index);
    final remembered = tab.isSettings
        ? 'zembo://settings'
        : (tab.url ?? tab.search?.query ?? '');
    if (remembered.isNotEmpty) {
      _closedTabs.add(remembered);
      if (_closedTabs.length > 15) _closedTabs.removeAt(0);
    }
    tab.closed = true;
    _disposeWeb(tab);

    if (_tabs.isEmpty) {
      // Последняя вкладка закрыта — открываем чистую.
      final fresh = BrowserTab(id: _nextId++);
      _tabs.add(fresh);
      _activeId = fresh.id;
    } else if (id == _activeId) {
      _activeId = _tabs[index.clamp(0, _tabs.length - 1)].id;
    }
    _syncWindowFullscreen();
    notifyListeners();
  }

  // ---------- навигация ----------

  /// Открывает адрес или поисковый запрос в активной вкладке.
  void navigate(String input) {
    final value = input.trim();
    if (value.isEmpty) return;

    if (value.toLowerCase() == 'zembo://settings') {
      openSettings();
      return;
    }

    ctx = null;
    final tab = active;

    // Поисковый запрос + Zembo Search + есть ключ Brave API -> своя страница результатов.
    if (!_looksLikeAddress(value) && _useSearchShell) {
      _openSearch(tab, value);
      return;
    }
    _openUrl(tab, _resolve(value));
  }

  bool get _useSearchShell =>
      settings.searchEngine == AppSettings.zemboSearch && settings.searchShell;

  /// С ключом — Brave Search API; без ключа (или если API не ответил) — скрытая страница.
  Future<List<SearchResult>> _search(String kind, String q, int page) async {
    if (settings.braveApiKey.trim().isNotEmpty) {
      try {
        switch (kind) {
          case 'news':
            return await _brave.news(q);
          case 'images':
            return await _brave.images(q);
          case 'videos':
            return await _brave.videos(q, page: page);
          default:
            return await _brave.web(q, page: page);
        }
      } on BraveError {
        // Ключ не подошёл или закончился лимит — пробуем без ключа.
      }
    }
    return scraper.fetch(kind, q, page: page);
  }

  void _openUrl(BrowserTab tab, String url) {
    // Если переходим со страницы результатов — запоминаем её для кнопки «назад».
    if (tab.search != null) {
      tab.prevSearch = tab.search;
      tab.search = null;
    }
    tab.isSettings = false;
    tab.url = url;
    tab.pageTitle = null;
    tab.loading = true;
    notifyListeners();
    _load(tab, url);
  }

  bool _looksLikeAddress(String v) {
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(v);
    if (hasScheme || v.startsWith('about:')) return true;
    final noSpaces = !v.contains(' ');
    final isLocal = v.startsWith('localhost') ||
        RegExp(r'^\d{1,3}(\.\d{1,3}){3}').hasMatch(v);
    return noSpaces && (v.contains('.') || isLocal);
  }

  String _resolve(String v) {
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(v);
    if (hasScheme || v.startsWith('about:')) return v;

    final noSpaces = !v.contains(' ');
    final isLocal = v.startsWith('localhost') ||
        RegExp(r'^\d{1,3}(\.\d{1,3}){3}').hasMatch(v);
    if (noSpaces && (v.contains('.') || isLocal)) {
      return (isLocal ? 'http://' : 'https://') + v;
    }
    return settings.searchUrl(v);
  }

  // ---------- страница результатов Zembo Search ----------

  void _openSearch(BrowserTab tab, String query) {
    tab.isSettings = false;
    tab.url = null;
    tab.pageTitle = null;
    tab.loading = false;
    tab.prevSearch = null;
    tab.search = SearchSession(query);
    tab.searchZoom = settings.searchZoom;
    notifyListeners();
    _loadSearch(tab, 'web');
  }

  void setSearchCategory(BrowserTab tab, String category) {
    final s = tab.search;
    if (s == null || s.category == category) return;
    s.category = category;
    notifyListeners();
    if (!s.results.containsKey(category)) _loadSearch(tab, category);
  }

  /// Проверяет ссылки из выдачи в Google Safe Browsing (если задан ключ).
  Future<void> _checkSafety(List<SearchResult> list) async {
    final key = settings.safeBrowsingKey;
    if (key.isEmpty) return;
    final urls = [
      for (final r in list)
        if (!SiteReputation.checked.contains(r.url)) r.url
    ];
    if (urls.isEmpty) return;
    try {
      final bad = await SafeBrowsing.check(key, urls);
      SiteReputation.checked.addAll(urls);
      SiteReputation.flagged.addAll(bad);
      notifyListeners();
    } catch (_) {
      // Нет сети или ключ не подошёл — остаётся примерная оценка.
    }
  }

  void loadMoreWeb(BrowserTab tab) => _loadSearch(tab, 'web', more: true);

  void loadMoreVideos(BrowserTab tab) => _loadSearch(tab, 'videos', more: true);

  /// Показать ещё одну порцию уже загруженных картинок.
  void showMoreImages(BrowserTab tab) {
    final s = tab.search;
    if (s == null) return;
    s.imagesShown += 40;
    notifyListeners();
  }

  /// Если ключ не работает — показать те же результаты на сайте Brave Search.
  void openSearchOnBrave(BrowserTab tab) {
    final q = tab.search?.query;
    if (q == null) return;
    _openUrl(tab, settings.searchUrl(q));
  }

  Future<void> _loadSearch(BrowserTab tab, String category,
      {bool more = false}) async {
    final s = tab.search;
    if (s == null || s.loading[category] == true) return;
    s.loading[category] = true;
    s.error[category] = null;
    notifyListeners();

    try {
      switch (category) {
        case 'news':
          s.results['news'] = SiteReputation.prioritize(
              SiteReputation.withoutYoutube(await _search('news', s.query, 0)));
        case 'images':
          s.imagesShown = 40;
          s.results['images'] = await _search('images', s.query, 0);
        case 'videos':
          final vpage = more ? s.videoPage + 1 : 0;
          final vraw = await _search('videos', s.query, vpage);
          if (more) {
            final have = {for (final r in s.results['videos'] ?? const <SearchResult>[]) r.url};
            final fresh = [for (final r in vraw) if (!have.contains(r.url)) r];
            s.results['videos'] = [...?s.results['videos'], ...fresh];
            s.videosHasMore = fresh.length >= 5 && vpage < 4;
          } else {
            s.results['videos'] = vraw;
            s.videosHasMore = vraw.length >= 15;
          }
          s.videoPage = vpage;
        default:
          final page = more ? s.webPage + 1 : 0;
          final raw = await _search('web', s.query, page);
          final ranked = SiteReputation.prioritize(
            SiteReputation.withoutStores(
                SiteReputation.withoutYoutube(raw), s.query),
            query: s.query,
          );
          // Один сайт — один результат (в том числе среди уже показанных).
          final unique = SiteReputation.uniqueHosts(
            ranked,
            existing: more ? (s.results['web'] ?? const <SearchResult>[]) : const [],
          );
          // На первой странице официальный сайт всегда идёт первым.
          final list =
              page == 0 ? SiteReputation.withOfficial(unique, s.query) : unique;
          if (more) {
            s.results['web'] = [...?s.results['web'], ...list];
          } else {
            s.results['web'] = list;
          }
          s.webPage = page;
          _checkSafety(list);
          s.webHasMore = raw.length >= 10 && page < 9;
      }
    } on BraveError catch (e) {
      s.error[category] = e.message;
    } catch (_) {
      s.error[category] = 'Не удалось загрузить результаты. Проверьте подключение к интернету.';
    } finally {
      s.loading[category] = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool get canGoForward {
    final t = active;
    return t.isBrowsing && t.canGoForward;
  }

  void back() {
    final t = active;
    if (t.isBrowsing && t.canGoBack && t.web != null) {
      t.web!.goBack();
    } else if (t.isBrowsing && t.prevSearch != null) {
      // С сайта — обратно к результатам поиска.
      t.search = t.prevSearch;
      t.prevSearch = null;
      t.url = null;
      t.pageTitle = null;
      t.loading = false;
      notifyListeners();
    } else {
      goHome();
    }
  }

  void forward() {
    final t = active;
    if (canGoForward) t.web?.goForward();
  }

  void reload() {
    final t = active;
    if (t.isBrowsing) {
      t.web?.reload();
    } else if (t.isSearch) {
      final s = t.search!;
      s.results.remove(s.category);
      if (s.category == 'web') s.webPage = 0;
      _loadSearch(t, s.category);
    }
  }

  void goHome() {
    final t = active;
    t.isSettings = false;
    t.url = null;
    t.search = null;
    t.prevSearch = null;
    t.pageTitle = null;
    t.loading = false;
    notifyListeners();
  }

  // ---------- WebView ----------

  Future<void> _load(BrowserTab tab, String url) async {
    try {
      tab.webInit ??= _initWeb(tab);
      await tab.webInit;
      if (tab.closed || tab.web == null || tab.url == null) return;
      await tab.web!.loadUrl(url);
    } catch (_) {
      tab.loading = false;
      notifyListeners();
    }
  }

  Future<void> _initWeb(BrowserTab tab) async {
    final c = WebviewController();
    tab.web = c;
    await c.initialize();
    if (tab.closed) {
      await c.dispose();
      return;
    }
    await c.setBackgroundColor(Colors.black);
    await c.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);

    tab.subs.add(c.url.listen((u) {
      if (tab.url != null) {
        tab.url = u;
        // У каждого сайта свой сохранённый масштаб.
        final z = settings.zoomForHost(Uri.tryParse(u)?.host ?? '');
        if ((z - tab.zoom).abs() > 0.001) {
          tab.zoom = z;
          c.setZoomFactor(z).catchError((_) {});
        }
        if (tab.pip) tab.pip = false; // страница сменилась — окошко закрываем
        notifyListeners();
      }
    }));
    // Видео на весь экран: окно браузера тоже разворачивается.
    tab.subs.add(c.containsFullScreenElementChanged.listen((v) {
      tab.fullscreen = v;
      _syncWindowFullscreen();
      notifyListeners();
    }));
    tab.subs.add(c.title.listen((t) {
      tab.pageTitle = t;
      if (tab.url != null) history.updateTitle(tab.url!, t);
      notifyListeners();
    }));
    tab.subs.add(c.loadingState.listen((s) {
      downloads.noteWebActivity();
      tab.loading = s == LoadingState.loading;
      if (tab.loading) {
        tab.hasVideo = false;
        tab.iconUrl = null;
      }
      if (s == LoadingState.navigationCompleted && tab.url != null) {
        history.record(tab.url!, tab.pageTitle ?? '');
      }
      // Полная очистка cookie затрагивает все сайты, поэтому её не делаем,
      // если для каких-то сайтов cookie разрешены отдельно.
      if (s == LoadingState.navigationCompleted &&
          settings.rejectCookies &&
          sitePerms.cookieHosts(PermValue.allow).isEmpty) {
        c.clearCookies().catchError((_) {});
      }
      notifyListeners();
    }));
    tab.subs.add(c.historyChanged.listen((h) {
      tab.canGoBack = h.canGoBack;
      tab.canGoForward = h.canGoForward;
      notifyListeners();
    }));

    tab.subs.add(c.webMessage.listen((msg) => _onWebMessage(tab, msg)));

    tab.webReady = true;
    await _applyScripts(tab, clearCookies: settings.rejectCookies);
    notifyListeners();
  }

  void _disposeWeb(BrowserTab tab) {
    for (final s in tab.subs) {
      s.cancel();
    }
    tab.subs.clear();
    tab.webReady = false;
    final c = tab.web;
    tab.web = null;
    c?.dispose().catchError((_) {});
  }

  // ---------- контекстное меню страницы ----------

  /// Показать контекстное меню в Flutter-странице (результаты поиска и т.п.).
  void showContext(PageContext c) {
    ctx = c;
    notifyListeners();
  }

  void hideMailPrompt() {
    if (mailPrompt == null) return;
    mailPrompt = null;
    notifyListeners();
  }

  /// Подставляет выбранную почту в поле ввода на странице.
  Future<void> fillMail(String email) async {
    final p = mailPrompt;
    mailPrompt = null;
    notifyListeners();
    if (p == null) return;
    for (final t in _tabs) {
      if (t.id == p.tabId) {
        try {
          await t.web?.executeScript(MailScript.fill(jsonEncode(email)));
        } catch (_) {}
      }
    }
  }

  // ---------- пароли ----------

  void hidePwPrompt() {
    if (pwPrompt == null) return;
    pwPrompt = null;
    notifyListeners();
  }

  void _onPwField(BrowserTab tab, Map m) {
    final pc = passwords;
    if (pc == null || !settings.autofillPasswords || tab.id != _activeId) return;
    final host = Uri.tryParse(tab.url ?? '')?.host ?? '';
    if (!pc.hasForHost(host)) return;
    final x = m['x'];
    final y = m['y'];
    final w = m['w'];
    if (x is! num || y is! num || w is! num) return;
    pwPrompt = PasswordPrompt(
      tabId: tab.id,
      x: x.toDouble() * tab.zoom,
      y: y.toDouble() * tab.zoom,
      width: w.toDouble() * tab.zoom,
      hasPassword: m['hasPw'] == true,
    );
    notifyListeners();
  }

  Future<void> _onPwSubmit(BrowserTab tab, Map m) async {
    final pc = passwords;
    if (pc == null || !settings.offerPasswords) return;
    final host = m['host'];
    final user = m['user'];
    final pass = m['pass'];
    if (host is! String || user is! String || pass is! String) return;
    if (pass.isEmpty || pass.length > 256 || user.length > 256) return;
    final tabHost = Uri.tryParse(tab.url ?? '')?.host ?? '';
    // Страница может предлагать сохранение только для самой себя.
    if (PasswordsController.hostKey(host) != PasswordsController.hostKey(tabHost)) {
      return;
    }
    if (pc.isNever(host)) return;
    final cur = pwSave;
    if (cur != null &&
        cur.host == PasswordsController.hostKey(host) &&
        cur.username == user &&
        cur.password == pass) {
      return;
    }
    final kind = await pc.classify(host, user, pass);
    if (kind == SaveKind.none || tab.closed) return;
    pwSave = PasswordSavePrompt(
      tabId: tab.id,
      host: PasswordsController.hostKey(host),
      username: user,
      password: pass,
      update: kind == SaveKind.update,
    );
    _pwSaveTimer?.cancel();
    _pwSaveTimer = Timer(const Duration(seconds: 45), dismissPwSave);
    notifyListeners();
  }

  void dismissPwSave() {
    _pwSaveTimer?.cancel();
    if (pwSave == null) return;
    pwSave = null;
    notifyListeners();
  }

  Future<void> acceptPwSave() async {
    final p = pwSave;
    dismissPwSave();
    final pc = passwords;
    if (p == null || pc == null) return;
    final ok = await pc.save(p.host, p.username, p.password);
    showToast(ok
        ? (p.update ? 'Пароль обновлён' : 'Пароль сохранён')
        : 'Не удалось сохранить пароль');
  }

  void neverPwSave() {
    final p = pwSave;
    dismissPwSave();
    if (p != null) passwords?.addNever(p.host);
  }

  /// Подставляет выбранный логин и пароль в поля на странице.
  Future<void> fillPassword(SavedLogin login) async {
    final p = pwPrompt;
    pwPrompt = null;
    notifyListeners();
    final pc = passwords;
    if (p == null || pc == null) return;
    for (final t in _tabs) {
      if (t.id != p.tabId) continue;
      final host = Uri.tryParse(t.url ?? '')?.host ?? '';
      if (PasswordsController.hostKey(host) != login.host) return;
      String pass = '';
      if (p.hasPassword) {
        final plain = await pc.reveal(login.id);
        if (plain == null) {
          showToast('Не удалось расшифровать пароль');
          return;
        }
        pass = plain;
      }
      try {
        await t.web?.executeScript(
            PasswordScript.fill(jsonEncode(login.username), jsonEncode(pass)));
      } catch (_) {}
    }
  }

  void closeContext() {
    if (ctx == null) return;
    ctx = null;
    notifyListeners();
  }

  void ctxCopy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    closeContext();
  }

  void ctxOpenInNewTab(String url) {
    closeContext();
    addTab();
    navigate(url);
  }

  void ctxSearch(String text) {
    closeContext();
    addTab();
    navigate(settings.searchUrl(text));
  }

  void ctxSaveImage(PageContext c) {
    closeContext();
    final uri = Uri.tryParse(c.img);
    var name = '';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      name = Uri.decodeComponent(uri.pathSegments.last);
    }
    if (name.isNotEmpty && !name.contains('.')) name = '$name.jpg';
    downloads.start(c.img,
        suggestedName: name.isEmpty ? null : name, referer: c.page);
  }

  BrowserTab? _tabById(int id) {
    for (final t in _tabs) {
      if (t.id == id) return t;
    }
    return null;
  }

  void ctxCut(PageContext c) {
    final t = _tabById(c.tabId);
    Clipboard.setData(ClipboardData(text: c.text));
    closeContext();
    if (t != null) _runNow(t, PageMenuScript.deleteSelection);
  }

  Future<void> ctxPaste(PageContext c) async {
    final t = _tabById(c.tabId);
    closeContext();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (t != null && text != null && text.isNotEmpty) {
      _runNow(t, PageMenuScript.insertText(text));
    }
  }

  void ctxSelectAll(PageContext c) {
    final t = _tabById(c.tabId);
    closeContext();
    if (t != null) _runNow(t, PageMenuScript.selectAll);
  }

  // ---------- полный экран и «картинка в картинке» ----------

  bool _fsBusy = false;
  bool _maximizedByUs = false;

  /// Приводит окно в соответствие с состоянием страницы. Перед полным экраном окно
  /// сначала разворачивается (иначе плеер не растягивается на весь экран).
  void _syncWindowFullscreen() {
    if (_fsBusy) return; // цикл ниже сам заметит новое состояние
    _applyFullscreen();
  }

  Future<void> _applyFullscreen() async {
    _fsBusy = true;
    try {
      while (_windowFs != active.fullscreen && !_disposed) {
        final want = active.fullscreen;
        if (want) {
          if (!await windowManager.isMaximized()) {
            await windowManager.maximize();
            _maximizedByUs = true;
            await Future<void>.delayed(const Duration(milliseconds: 150));
          }
          await windowManager.setFullScreen(true);
        } else {
          await windowManager.setFullScreen(false);
          if (_maximizedByUs) {
            _maximizedByUs = false;
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await windowManager.unmaximize();
          }
        }
        _windowFs = want;
      }
    } catch (_) {
      _windowFs = active.fullscreen;
    } finally {
      _fsBusy = false;
    }
  }

  void showToast(String text) {
    toast = text;
    notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      toast = null;
      notifyListeners();
    });
  }

  /// Выносит видео открытой страницы в маленькое окошко.
  void startPip() {
    final t = active;
    if (!t.isBrowsing || t.web == null || !t.webReady) {
      showToast('Откройте страницу с видео');
      return;
    }
    _pipPending = t.id;
    _pipTimer?.cancel();
    // Если страница не ответила — считаем, что видео нет.
    _pipTimer = Timer(const Duration(seconds: 2), () {
      if (_pipPending == t.id) {
        _pipPending = null;
        showToast('На странице нет видео для «картинки в картинке»');
      }
    });
    _runNow(t, PipScript.enter);
  }

  void exitPip(BrowserTab t) {
    if (!t.pip) return;
    t.pip = false;
    _runNow(t, PipScript.exit);
    notifyListeners();
  }

  void closePip(BrowserTab t) {
    if (!t.pip) return;
    t.pip = false;
    _runNow(t, PipScript.exitAndPause);
    notifyListeners();
  }

  void pipTogglePlay(BrowserTab t) => _runNow(t, PipScript.toggle);

  // ---------- встроенные расширения и cookie ----------

  String _adScript() =>
      AdBlock.script(settings.adAllowHosts, settings.hiddenSelectors);

  /// Режим «Скрыть элемент»: включает выбор баннера на открытой странице.
  void startElementPicker() => _runNow(active, ElementPicker.script);

  /// Переустанавливает скрипты, которые выполняются при создании каждой страницы.
  Future<void> _applyScripts(BrowserTab tab, {bool clearCookies = false}) async {
    final c = tab.web;
    if (c == null || !tab.webReady) return;
    try {
      for (final id in tab.scriptIds) {
        await c.removeScriptToExecuteOnDocumentCreated(id);
      }
      tab.scriptIds.clear();

      Future<void> add(String script) async {
        final id = await c.addScriptToExecuteOnDocumentCreated(script);
        if (id != null) tab.scriptIds.add(id);
      }

      final allowCookies = sitePerms.cookieHosts(PermValue.allow);
      final blockCookies = sitePerms.cookieHosts(PermValue.block);
      if (settings.rejectCookies || blockCookies.isNotEmpty) {
        await add(BuiltinScripts.cookiesFor(
          global: settings.rejectCookies,
          allow: allowCookies,
          block: blockCookies,
        ));
        if (clearCookies && settings.rejectCookies && allowCookies.isEmpty) {
          await c.clearCookies();
        }
      }
      if (settings.darkSites || settings.googleDark) {
        await add(BuiltinScripts.darkModeFor(
            all: settings.darkSites, google: settings.googleDark));
      }
      final siteLang = settings.siteLanguage;
      if (siteLang != null) {
        await add(BuiltinScripts.languageOverride(siteLang));
      }
      if (settings.offerPasswords || settings.autofillPasswords) {
        await add(PasswordScript.support);
      }
      if (settings.adBlock) {
        await add(_adScript());
        await add(BuiltinScripts.sponsorBlockFor(settings.adAllowHosts));
      }
      // Перехват скачивания файлов и поддержка «картинки в картинке» работают всегда.
      await add(DownloadScript.script);
      await add(PipScript.support);
      await add(PageMenuScript.support);
      await add(KeyScript.support);
      await add(MailScript.support);
      await add(BuiltinScripts.zemboSearchSkin);
      await add(ScrollScript.support(settings.smoothScroll, settings.scrollSpeed));
      if (settings.doNotTrack) await add(PrivacyScript.signals);
    } catch (_) {}
  }

  /// Выполнить скрипт на уже открытой странице.
  Future<void> _runNow(BrowserTab tab, String script) async {
    if (tab.web == null || !tab.webReady || !tab.isBrowsing) return;
    try {
      await tab.web!.executeScript(script);
    } catch (_) {}
  }

  void _onSettingsChanged() {
    final cookies = settings.rejectCookies != _lastRejectCookies;
    final dark = settings.darkSites != _lastDark ||
        settings.googleDark != _lastGoogleDark;
    final lang = (settings.siteLanguage ?? '') != _lastLang;
    final pwSig = '${settings.offerPasswords}/${settings.autofillPasswords}';
    final pwChanged = pwSig != _lastPw;
    final allow = settings.adAllowHosts.join(',');
    final hiddenSig = jsonEncode(settings.hiddenSelectors);
    final ads = settings.adBlock != _lastAdBlock ||
        allow != _lastAllow ||
        hiddenSig != _lastHidden;
    final scrollSig = '${settings.smoothScroll}/${settings.scrollSpeed}';
    final scroll = scrollSig != _lastScroll;
    final dnt = settings.doNotTrack != _lastDnt;
    if (!cookies && !dark && !ads && !scroll && !dnt && !lang && !pwChanged) {
      return;
    }
    _lastLang = settings.siteLanguage ?? '';
    _lastPw = pwSig;
    _lastGoogleDark = settings.googleDark;
    _lastScroll = scrollSig;
    _lastDnt = settings.doNotTrack;

    _lastRejectCookies = settings.rejectCookies;
    _lastDark = settings.darkSites;
    _lastAdBlock = settings.adBlock;
    _lastAllow = allow;
    _lastHidden = hiddenSig;

    for (final t in _tabs) {
      _applyScripts(t, clearCookies: cookies && settings.rejectCookies);
      // Сразу применяем к уже открытой странице.
      if (scroll) {
        _runNow(t, ScrollScript.live(settings.smoothScroll, settings.scrollSpeed));
      }
      if (dark) {
        _runNow(
            t,
            (settings.darkSites || settings.googleDark)
                ? BuiltinScripts.darkModeFor(
                    all: settings.darkSites, google: settings.googleDark)
                : BuiltinScripts.darkModeOff);
      }
      if (ads) {
        final host = Uri.tryParse(t.url ?? '')?.host ?? '';
        final enabled = settings.adBlock && !settings.isAdAllowed(host);
        _runNow(t, enabled ? _adScript() : AdBlock.scriptOff);
        _runNow(t, enabled
            ? BuiltinScripts.sponsorBlockFor(settings.adAllowHosts)
            : BuiltinScripts.sponsorBlockOff);
      }
    }
  }

  // ---------- SponsorBlock: запросы от страницы ----------

  void _onWebMessage(BrowserTab tab, dynamic msg) {
    try {
      dynamic m = msg;
      // Сообщение может прийти строкой с JSON (иногда дважды закодированной).
      for (var i = 0; i < 2 && m is String; i++) {
        m = jsonDecode(m);
      }
      if (m is! Map) return;

      switch (m['type']) {
        case 'zembo-sb':
          if (!settings.adBlock) return;
          final id = m['videoId'];
          final prefix = m['prefix'];
          if (id is! String || prefix is! String) return;
          if (!RegExp(r'^[0-9a-f]{4}$').hasMatch(prefix)) return;
          _loadSponsorSegments(tab, id, prefix);
        case 'zembo-icon':
          final icon = m['url'];
          if (icon is! String || icon.length > 2000) return;
          final next = PageContext.isHttp(icon) ? icon : null;
          if (tab.iconUrl != next) {
            tab.iconUrl = next;
            notifyListeners();
          }
        case 'zembo-video':
          final has = m['has'] == true;
          if (tab.hasVideo != has) {
            tab.hasVideo = has;
            notifyListeners();
          }
        case 'zembo-key':
          if (tab.id != _activeId) return;
          final code = m['code'];
          if (code is! String) return;
          onWebKey?.call(code, m['ctrl'] == true, m['shift'] == true,
              m['alt'] == true, m['repeat'] == true);
        case 'zembo-ctx':
          if (tab.id != _activeId) return;
          final parsed = PageContext.fromMap(tab.id, m['info']);
          if (parsed == null) return;
          ctx = parsed;
          notifyListeners();
        case 'zembo-pip':
          if (_pipPending != tab.id) return;
          _pipPending = null;
          _pipTimer?.cancel();
          if (m['ok'] == true) {
            tab.pip = true;
            addTab(); // на экране открывается новая вкладка, видео остаётся в окошке
          } else {
            showToast('На странице нет видео для «картинки в картинке»');
          }
        case 'zembo-hide':
          final host = m['host'];
          final selector = m['selector'];
          if (host is! String || selector is! String) return;
          // Страница может добавлять правила только для самой себя.
          final tabHost = Uri.tryParse(tab.url ?? '')?.host ?? '';
          if (host != tabHost) return;
          if (selector.length > 500 || RegExp(r'[{};<>]').hasMatch(selector)) {
            return;
          }
          settings.addHidden(host, selector);
        case 'zembo-dl':
          final url = m['url'];
          if (url is! String) return;
          final name = m['name'];
          final referer = m['referer'];
          downloads.start(
            url,
            suggestedName: (name is String && name.isNotEmpty) ? name : null,
            referer: referer is String ? referer : null,
          );
        case 'zembo-click':
          downloads.noteWebActivity();
        case 'zembo-pw-field':
          _onPwField(tab, m);
        case 'zembo-pw-hide':
          hidePwPrompt();
        case 'zembo-pw-submit':
          _onPwSubmit(tab, m);
        case 'zembo-mail-field':
          final mailCtl = mail;
          final pwHost = Uri.tryParse(tab.url ?? '')?.host ?? '';
          if (settings.autofillPasswords &&
              (passwords?.hasForHost(pwHost) ?? false)) {
            return; // для этого сайта показываем сохранённые логины
          }
          if (tab.id != _activeId || mailCtl == null || !mailCtl.hasAccounts) return;
          final mx = m['x'];
          final my = m['y'];
          final mw = m['w'];
          if (mx is! num || my is! num || mw is! num) return;
          mailPrompt = MailPrompt(
            tabId: tab.id,
            x: mx.toDouble() * tab.zoom,
            y: my.toDouble() * tab.zoom,
            width: mw.toDouble() * tab.zoom,
          );
          notifyListeners();
        case 'zembo-mail-hide':
          hideMailPrompt();
        case 'zembo-dl-data':
          final b64 = m['data'];
          final fileName = m['name'];
          if (b64 is! String || b64.length > 100 * 1024 * 1024) return;
          downloads.saveData(fileName is String ? fileName : 'download', b64);
      }
    } catch (_) {}
  }

  Future<void> _loadSponsorSegments(
      BrowserTab tab, String videoId, String prefix) async {
    List<List<double>> segments = [];
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final categories =
          jsonEncode(['sponsor', 'selfpromo', 'interaction', 'intro', 'outro']);
      final uri = Uri.parse(
        'https://sponsor.ajay.app/api/skipSegments/$prefix'
        '?categories=${Uri.encodeQueryComponent(categories)}'
        '&actionTypes=${Uri.encodeQueryComponent(jsonEncode(['skip']))}',
      );
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is List) {
          for (final item in data) {
            if (item is Map && item['videoID'] == videoId) {
              for (final seg in (item['segments'] as List)) {
                final range = (seg as Map)['segment'] as List;
                segments.add([
                  (range[0] as num).toDouble(),
                  (range[1] as num).toDouble(),
                ]);
              }
            }
          }
        }
      }
    } catch (_) {
      // Нет сети или нет данных — просто ничего не пропускаем.
    } finally {
      client.close(force: true);
    }

    if (tab.closed) return;
    await _runNow(
      tab,
      'window.__zemboSB && window.__zemboSB.set('
      '${jsonEncode(videoId)}, ${jsonEncode(segments)});',
    );
  }
}

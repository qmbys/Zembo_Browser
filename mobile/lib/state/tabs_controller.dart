import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/browser_tab.dart';
import 'ad_blocklist.dart';
import 'app_keys.dart';
import 'app_settings.dart';
import 'brave_scraper.dart';
import 'brave_search.dart';
import 'ddg_search.dart';
import 'filter_lists.dart';
import 'downloads_controller.dart';
import 'history_controller.dart';
import 'network_controller.dart';
import 'password_script.dart';
import 'passwords_controller.dart';
import 'youtube_scripts.dart';
import 'safe_browsing.dart';
import 'site_reputation.dart';

/// Вкладки, навигация и блокировка рекламы (через перехват запросов WebView).
class TabsController extends ChangeNotifier {
  TabsController({
    required this.settings,
    required this.lists,
    required this.history,
    required this.downloads,
    required this.passwords,
  }) {
    _lastDark = settings.darkSites;
    _lastAds = settings.adBlock;
    _lastScale = settings.uiScale;
    _lastPw = settings.offerPasswords || settings.autofillPasswords;
    settings.addListener(_onSettings);
    network.addListener(_applyWebSettings);
    newTab();
  }

  final AppSettings settings;
  final FilterLists lists;
  final HistoryController history;
  final DownloadsController downloads;
  final PasswordsController passwords;

  /// DNS-сервер и блокировка рекламы на уровне соединений (через локальный прокси).
  late final NetworkController network = NetworkController(
    settings,
    lists,
    onBlocked: () => blocked.value++,
  );

  late final BraveSearchApi _brave = BraveSearchApi(settings);
  late final BraveScraper scraper = BraveScraper(settings);

  final List<BrowserTab> tabs = [];
  int _nextId = 1;
  int activeIndex = 0;

  BrowserTab get active => tabs[activeIndex];

  /// Счётчик заблокированных запросов — отдельно, чтобы не перерисовывать весь экран.
  final ValueNotifier<int> blocked = ValueNotifier(0);
  int get blockedCount => blocked.value;

  bool _fullscreen = false;
  bool get fullscreen => _fullscreen;

  bool _lastDark = false;
  bool _lastAds = false;
  double _lastScale = 1.0;
  bool _lastPw = false;
  bool _disposed = false;

  // ---------- вкладки ----------

  BrowserTab newTab({String? url, bool activate = true}) {
    final t = BrowserTab(id: _nextId++);
    tabs.add(t);
    if (activate) activeIndex = tabs.length - 1;
    if (url != null) t.url = resolve(url);
    notifyListeners();
    return t;
  }

  void select(BrowserTab t) {
    final i = tabs.indexOf(t);
    if (i < 0 || i == activeIndex) return;
    activeIndex = i;
    notifyListeners();
  }

  void closeTab(BrowserTab t) {
    final i = tabs.indexOf(t);
    if (i < 0) return;
    tabs.removeAt(i);
    if (tabs.isEmpty) {
      newTab();
      return;
    }
    if (i < activeIndex) {
      activeIndex--;
    } else if (activeIndex >= tabs.length) {
      activeIndex = tabs.length - 1;
    }
    notifyListeners();
  }

  // ---------- навигация ----------

  static final _scheme = RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false);

  bool _looksLikeAddress(String v) {
    if (_scheme.hasMatch(v) || v.startsWith('about:')) return true;
    final isLocal =
        v.startsWith('localhost') || RegExp(r'^\d{1,3}(\.\d{1,3}){3}').hasMatch(v);
    return !v.contains(' ') && (v.contains('.') || isLocal);
  }

  /// Адрес или поисковый запрос -> адрес страницы.
  String resolve(String input) {
    final v = input.trim();
    if (_scheme.hasMatch(v) || v.startsWith('about:')) return v;
    if (_looksLikeAddress(v)) {
      final isLocal = v.startsWith('localhost') ||
          RegExp(r'^\d{1,3}(\.\d{1,3}){3}').hasMatch(v);
      return (isLocal ? 'http://' : 'https://') + v;
    }
    return settings.searchUrl(v);
  }

  bool get _useSearchShell =>
      settings.searchEngine == AppSettings.zemboSearch && settings.searchShell;

  /// Открывает адрес или поисковый запрос во вкладке.
  void open(String input, {BrowserTab? tab}) {
    final v = input.trim();
    if (v.isEmpty) return;
    final t = tab ?? active;
    if (!_looksLikeAddress(v) && _useSearchShell) {
      _openSearch(t, v);
      return;
    }
    _openUrl(t, resolve(v));
  }

  void _openUrl(BrowserTab t, String url) {
    // Уходим со страницы результатов — запоминаем её для кнопки «назад».
    if (t.search != null) {
      t.prevSearch = t.search;
      t.search = null;
    }
    t.url = url;
    t.error = null;
    t.pageTitle = null;
    t.loading = true;
    t.progress = 0;
    final web = t.web;
    if (web != null) {
      web.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
    // Если WebView ещё нет, его создаст виджет страницы с адресом t.url.
    notifyListeners();
  }

  // ---------- страница результатов Zembo Search ----------

  void _openSearch(BrowserTab t, String query) {
    t.url = null;
    t.pageTitle = null;
    t.web = null;
    t.loading = false;
    t.prevSearch = null;
    t.search = SearchSession(query);
    notifyListeners();
    _loadSearch(t, 'web');
  }

  void setSearchCategory(BrowserTab t, String category) {
    final s = t.search;
    if (s == null || s.category == category) return;
    s.category = category;
    notifyListeners();
    if (!s.results.containsKey(category)) _loadSearch(t, category);
  }

  void loadMoreWeb(BrowserTab t) => _loadSearch(t, 'web', more: true);
  void loadMoreVideos(BrowserTab t) => _loadSearch(t, 'videos', more: true);

  void showMoreImages(BrowserTab t) {
    final s = t.search;
    if (s == null) return;
    s.imagesShown += 40;
    notifyListeners();
  }

  /// Если ключ/скрапер не работают — те же результаты на сайте Brave Search.
  void openSearchOnBrave(BrowserTab t) {
    final q = t.search?.query;
    if (q == null) return;
    _openUrl(t, settings.searchUrl(q));
  }

  /// Источник обычной выдачи: Brave (ключ API или скрытая страница). Если Brave не
  /// ответил, берём DuckDuckGo и переключаемся на него насовсем.
  Future<List<SearchResult>> _search(String kind, String q, int page) async {
    if (kind == 'web' && settings.searchSource == 'duckduckgo') {
      try {
        return await DdgSearch.web(q, page: page);
      } on BraveError {
        // DuckDuckGo не ответил — на этот раз пробуем Brave.
      }
    }
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
    try {
      return await scraper.fetch(kind, q, page: page);
    } on BraveError {
      if (kind != 'web' || settings.searchSource == 'duckduckgo') rethrow;
      // Переключаемся, только если запасной источник реально ответил.
      final r = await DdgSearch.web(q, page: page);
      settings.searchSource = 'duckduckgo';
      _sourceSwitched();
      return r;
    }
  }

  void _sourceSwitched() {
    toast('Brave Search не ответил — результаты теперь берутся из DuckDuckGo. '
        'Вернуть Brave можно в настройках.');
  }

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

  Future<void> _loadSearch(BrowserTab t, String category,
      {bool more = false}) async {
    final s = t.search;
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
            final have = {
              for (final r in s.results['videos'] ?? const <SearchResult>[]) r.url
            };
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
          final unique = SiteReputation.uniqueHosts(
            ranked,
            existing: more ? (s.results['web'] ?? const <SearchResult>[]) : const [],
          );
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
      s.error[category] =
          'Не удалось загрузить результаты. Проверьте подключение к интернету.';
    } finally {
      s.loading[category] = false;
      if (!_disposed) notifyListeners();
    }
  }

  void goHome(BrowserTab t) {
    t.url = null;
    t.search = null;
    t.prevSearch = null;
    t.pageTitle = null;
    t.web = null;
    t.loading = false;
    t.canGoBack = false;
    t.canGoForward = false;
    notifyListeners();
  }

  /// Назад: по истории сайта → к результатам поиска → на стартовую.
  bool canBack(BrowserTab t) => !t.isHome;

  Future<void> back(BrowserTab t) async {
    final web = t.web;
    if (t.url != null && web != null && await web.canGoBack()) {
      await web.goBack();
      return;
    }
    if (t.url != null && t.prevSearch != null) {
      t.search = t.prevSearch;
      t.prevSearch = null;
      t.url = null;
      t.web = null;
      t.pageTitle = null;
      t.loading = false;
      t.canGoBack = false;
      notifyListeners();
      return;
    }
    if (!t.isHome) goHome(t);
  }
  Future<void> forward(BrowserTab t) async => t.web?.goForward();
  Future<void> reload(BrowserTab t) async => t.web?.reload();
  Future<void> stop(BrowserTab t) async => t.web?.stopLoading();

  // ---------- события WebView ----------

  void pageError(BrowserTab t, String text) {
    t.error = text;
    t.loading = false;
    notifyListeners();
  }

  void pageStarted(BrowserTab t, String? url) {
    t.error = null;
    if (url != null) t.url = url;
    t.loading = true;
    t.progress = 0;
    notifyListeners();
  }

  void pageProgress(BrowserTab t, double p) {
    // Не перерисовываем весь экран на каждый процент загрузки.
    final big = p >= 1 || (p - t.progress) >= 0.15;
    if (!big) return;
    t.progress = p;
    if (p >= 1) t.loading = false;
    notifyListeners();
  }

  Future<void> pageFinished(BrowserTab t, String? url) async {
    if (url != null) t.url = url;
    t.loading = false;
    await _refreshNav(t);
    final title = await t.web?.getTitle();
    if (title != null && title.isNotEmpty) t.pageTitle = title;
    if (t.url != null && t.url!.startsWith('http')) {
      history.record(t.url!, t.pageTitle ?? '');
    }
    notifyListeners();
  }

  void pageTitle(BrowserTab t, String? title) {
    if (title == null || title.isEmpty || title == t.pageTitle) return;
    t.pageTitle = title;
    notifyListeners();
  }

  Future<void> pageVisited(BrowserTab t, String? url) async {
    if (url != null) t.url = url;
    await _refreshNav(t);
    notifyListeners();
  }

  Future<void> _refreshNav(BrowserTab t) async {
    final w = t.web;
    if (w == null) return;
    t.canGoBack = await w.canGoBack();
    t.canGoForward = await w.canGoForward();
  }

  // ---------- блокировка рекламы ----------

  /// true — запрос нужно заблокировать.
  bool shouldBlock(BrowserTab t, Uri uri) {
    if (!settings.adBlock) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    final pageHost = Uri.tryParse(t.url ?? '')?.host.toLowerCase() ?? '';
    if (pageHost.isNotEmpty && settings.adAllowHosts.contains(pageHost)) {
      return false;
    }
    if (!lists.blocks(host)) return false;
    blocked.value++;
    return true;
  }

  // ---------- версия для ПК ----------

  static const desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  Future<void> toggleDesktop(BrowserTab t) async {
    t.desktop = !t.desktop;
    notifyListeners();
    final web = t.web;
    if (web == null) return;
    await _patch(t, (st) {
      st.preferredContentMode = t.desktop
          ? UserPreferredContentMode.DESKTOP
          : UserPreferredContentMode.MOBILE;
      st.userAgent = t.desktop ? desktopUa : '';
    });
    await web.reload();
  }

  // ---------- полноэкранное видео ----------

  void setFullscreen(bool v) {
    if (_fullscreen == v) return;
    _fullscreen = v;
    SystemChrome.setEnabledSystemUIMode(
        v ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (!v) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    notifyListeners();
  }

  Future<void> exitFullscreen() async {
    await active.web?.evaluateJavascript(
        source: 'document.exitFullscreen && document.exitFullscreen();');
    setFullscreen(false);
  }

  // ---------- тёмная тема сайтов ----------

  /// Меняет настройки уже открытого WebView, не трогая остальные.
  Future<void> _patch(
      BrowserTab t, void Function(InAppWebViewSettings st) change) async {
    final w = t.web;
    if (w == null) return;
    try {
      final st = await w.getSettings() ?? InAppWebViewSettings();
      change(st);
      await w.setSettings(settings: st);
    } catch (_) {}
  }

  /// Настройки, которые зависят от общих параметров браузера.
  void _applyWebSettings() {
    for (final t in tabs) {
      _patch(t, (st) {
        st.algorithmicDarkeningAllowed = settings.darkSites;
        st.textZoom = (settings.uiScale * 100).round();
        // Когда рекламу режет локальный прокси, перехват запросов не нужен.
        st.useShouldInterceptRequest = settings.adBlock && !network.active;
      });
    }
  }

  /// Скрипты, которые вставляются в каждую страницу (блокировщик рекламы YouTube
  /// и пропуск спонсорских вставок).
  List<UserScript> userScripts() {
    final list = <UserScript>[];
    if (settings.adBlock) {
      list.add(UserScript(
        source: AdBlock.script(settings.adAllowHosts, settings.hiddenSelectors),
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
        groupName: 'zembo-ads',
      ));
      list.add(UserScript(
        source: YoutubeScripts.sponsorBlockFor(settings.adAllowHosts),
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
        groupName: 'zembo-sb',
      ));
    }
    if (settings.offerPasswords || settings.autofillPasswords) {
      list.add(UserScript(
        source: PasswordScript.support,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
        groupName: 'zembo-pw',
      ));
    }
    return list;
  }

  Future<void> _applyUserScripts() async {
    final ads = settings.adBlock;
    for (final t in tabs) {
      final w = t.web;
      if (w == null) continue;
      try {
        for (final g in const ['zembo-ads', 'zembo-sb', 'zembo-pw']) {
          await w.removeUserScriptsByGroupName(groupName: g);
        }
        final list = userScripts();
        if (list.isNotEmpty) await w.addUserScripts(userScripts: list);
        if (ads) {
          // На уже открытой странице включаем сразу.
          await w.evaluateJavascript(
              source: AdBlock.script(
                  settings.adAllowHosts, settings.hiddenSelectors));
          await w.evaluateJavascript(
              source: YoutubeScripts.sponsorBlockFor(settings.adAllowHosts));
        } else {
          await w.evaluateJavascript(source: AdBlock.scriptOff);
          await w.evaluateJavascript(source: YoutubeScripts.sponsorBlockOff);
        }
      } catch (_) {}
    }
  }

  void _onSettings() {
    var web = false;
    if (settings.darkSites != _lastDark) {
      _lastDark = settings.darkSites;
      web = true;
    }
    if (settings.uiScale != _lastScale) {
      _lastScale = settings.uiScale;
      web = true;
    }
    final pw = settings.offerPasswords || settings.autofillPasswords;
    if (settings.adBlock != _lastAds || pw != _lastPw) {
      _lastAds = settings.adBlock;
      _lastPw = pw;
      web = true;
      _applyUserScripts();
    }
    if (web) _applyWebSettings();
  }

  // ---------- менеджер паролей ----------

  /// Подсказка сохранённых логинов под полем входа.
  PasswordPrompt? fieldPrompt;

  /// Предложение сохранить пароль после входа.
  PasswordSavePrompt? savePrompt;
  Timer? _saveTimer;

  Future<void> passwordMessage(BrowserTab tab, List<dynamic> args) async {
    if (args.isEmpty) return;
    dynamic m = args.first;
    try {
      if (m is String) m = jsonDecode(m);
    } catch (_) {
      return;
    }
    if (m is! Map) return;

    switch (m['type']) {
      case 'zembo-pw-field':
        if (!settings.autofillPasswords) return;
        final host = Uri.tryParse(tab.url ?? '')?.host ?? '';
        if (!passwords.hasForHost(host)) {
          if (fieldPrompt != null) {
            fieldPrompt = null;
            notifyListeners();
          }
          return;
        }
        fieldPrompt = PasswordPrompt(
          tabId: tab.id,
          x: 0,
          y: 0,
          width: 0,
          hasPassword: m['hasPw'] == true,
        );
        notifyListeners();
      case 'zembo-pw-hide':
        if (fieldPrompt != null) {
          fieldPrompt = null;
          notifyListeners();
        }
      case 'zembo-pw-submit':
        if (!settings.offerPasswords) return;
        final site = (m['host'] as String?) ?? '';
        final user = (m['user'] as String?) ?? '';
        final pass = (m['pass'] as String?) ?? '';
        if (site.isEmpty || pass.isEmpty || passwords.isNever(site)) return;
        final kind = await passwords.classify(site, user, pass);
        if (kind == SaveKind.none) return;
        savePrompt = PasswordSavePrompt(
          tabId: tab.id,
          host: PasswordsController.hostKey(site),
          username: user,
          password: pass,
          update: kind == SaveKind.update,
        );
        _saveTimer?.cancel();
        _saveTimer = Timer(const Duration(seconds: 45), dismissSavePrompt);
        notifyListeners();
    }
  }

  void dismissSavePrompt() {
    _saveTimer?.cancel();
    if (savePrompt == null) return;
    savePrompt = null;
    notifyListeners();
  }

  Future<void> confirmSavePassword() async {
    final p = savePrompt;
    if (p == null) return;
    dismissSavePrompt();
    final ok = await passwords.save(p.host, p.username, p.password);
    toast(ok ? 'Пароль сохранён' : 'Не удалось сохранить пароль');
  }

  void neverSavePassword() {
    final p = savePrompt;
    if (p == null) return;
    passwords.addNever(p.host);
    dismissSavePrompt();
  }

  /// Подставляет выбранный логин (и пароль, если на странице есть его поле).
  Future<void> fillLogin(BrowserTab tab, SavedLogin login) async {
    final withPass = fieldPrompt?.hasPassword == true;
    fieldPrompt = null;
    notifyListeners();
    String? pass;
    if (withPass) pass = await passwords.reveal(login.id);
    try {
      await tab.web?.evaluateJavascript(
        source: PasswordScript.fill(
            jsonEncode(login.username), jsonEncode(pass ?? '')),
      );
    } catch (_) {}
  }

  // ---------- SponsorBlock ----------

  /// Страница YouTube просит отрезки для видео (сообщение от скрипта).
  void sponsorMessage(BrowserTab tab, List<dynamic> args) {
    if (!settings.adBlock || args.isEmpty) return;
    try {
      dynamic m = args.first;
      if (m is String) m = jsonDecode(m);
      if (m is! Map) return;
      final id = m['videoId'], prefix = m['prefix'];
      if (id is String && prefix is String && id.length == 11) {
        _loadSponsorSegments(tab, id, prefix);
      }
    } catch (_) {}
  }

  Future<void> _loadSponsorSegments(
      BrowserTab tab, String videoId, String prefix) async {
    final segments = <List<double>>[];
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

    if (!tabs.contains(tab)) return;
    try {
      await tab.web?.evaluateJavascript(
        source: 'window.__zemboSB && window.__zemboSB.set('
            '${jsonEncode(videoId)}, ${jsonEncode(segments)});',
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    scraper.dispose();
    _saveTimer?.cancel();
    network.removeListener(_applyWebSettings);
    network.dispose();
    blocked.dispose();
    settings.removeListener(_onSettings);
    super.dispose();
  }
}

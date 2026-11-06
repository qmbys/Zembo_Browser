import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ad_blocklist.dart';
import 'languages.dart';

/// Настройки браузера. Сохраняются в %APPDATA%\ZemboBrowser\settings.json.
class AppSettings extends ChangeNotifier {
  AppSettings();

  /// Поисковые системы: название -> адрес, куда дописывается запрос.
  /// Кнопки справа от адресной строки (порядок по умолчанию).
  static const toolbarDefaults = [
    'sites',
    'pip',
    'extensions',
    'downloads',
    'mail',
    'shield',
    'menu',
  ];

  /// Название собственной поисковой системы браузера (работает на основе Brave Search).
  static const zemboSearch = 'Zembo Search';

  static const searchLabels = {
    zemboSearch: 'Zembo Search (на основе Brave)',
  };

  static const searchUrls = {
    zemboSearch: 'https://search.brave.com/search?q=',
    'DuckDuckGo': 'https://duckduckgo.com/?q=',
    'Google': 'https://www.google.com/search?q=',
    'Bing': 'https://www.bing.com/search?q=',
    'Яндекс': 'https://yandex.ru/search/?text=',
  };
  static List<String> get searchEngines => searchUrls.keys.toList();

  /// DNS-серверы (DNS-over-HTTPS): ключ -> название.
  static const dnsLabels = {
    'cloudflare': 'Cloudflare (1.1.1.1)',
    'google': 'Google (8.8.8.8)',
    'quad9': 'Quad9 (9.9.9.9)',
    'adguard': 'AdGuard',
    'system': 'Системный',
  };

  static const dnsTemplates = {
    'cloudflare': 'https://cloudflare-dns.com/dns-query',
    'google': 'https://dns.google/dns-query',
    'quad9': 'https://dns.quad9.net/dns-query',
    'adguard': 'https://dns.adguard-dns.com/dns-query',
  };

  String _searchEngine = zemboSearch;
  bool _showShortcuts = true;
  bool _doNotTrack = true;
  String _dns = 'cloudflare';
  bool _rejectCookies = false;
  bool _darkSites = false;
  bool _googleDark = true;
  bool _offerPasswords = true;
  bool _autofillPasswords = true;
  // Язык интерфейса и сайтов. Пока пользователь сам не выбрал язык, интерфейс
  // остаётся русским, а сайты получают язык системы (как раньше).
  String _language = 'ru';
  bool _languageChosen = false;
  String? _siteLangAtStart;
  double _uiScale = 0.85;
  bool _smoothScroll = true;
  String _braveApiKey = '';
  String _safeBrowsingKey = '';
  String _googleClientId = '';
  String _googleClientSecret = '';
  double _searchZoom = 1.0;
  final Map<String, double> _siteZoom = {};
  bool _searchShell = true;
  List<String> _toolbarOrder = List.of(toolbarDefaults);
  Set<String> _toolbarHidden = {};
  bool _showCopy = true;
  bool _showStar = true;
  double _scrollSpeed = 1.0;
  bool _adBlock = true;
  List<String> _adAllowHosts = [];
  // Сайт -> CSS-селекторы элементов, скрытых пользователем.
  final Map<String, List<String>> _hidden = {};
  // Включённые готовые списки фильтров (по умолчанию — списки против казино).
  Set<String> _enabledLists = {'hagezi-gambling', 'arkynx-gambling'};

  String get searchEngine => _searchEngine;
  bool get showShortcuts => _showShortcuts;
  /// «Блокировать трекеры» = включён большой список HaGeZi Pro.
  bool get blockTrackers => isListEnabled('hagezi-pro');

  /// Уровень защиты: 0 — отключена, 1 — стандартная, 2 — строгая.
  int get protectionLevel => !_adBlock ? 0 : (isListEnabled('hagezi-pro') ? 2 : 1);
  bool get doNotTrack => _doNotTrack;
  String get dns => _dns;
  bool get rejectCookies => _rejectCookies;
  bool get darkSites => _darkSites;

  /// Сайты Google (поиск, YouTube, Gmail, Диск и т.д.) сразу открываются тёмными.
  bool get googleDark => _googleDark;
  set googleDark(bool v) => _update(() => _googleDark = v);

  /// Предлагать сохранять пароли после входа на сайте.
  bool get offerPasswords => _offerPasswords;
  set offerPasswords(bool v) => _update(() => _offerPasswords = v);

  /// Показывать сохранённые логины под полями входа.
  bool get autofillPasswords => _autofillPasswords;
  set autofillPasswords(bool v) => _update(() => _autofillPasswords = v);

  /// Язык сайтов: код (ru, en-US …) или «system».
  String get language => _language;
  set language(String v) {
    if (!Languages.isKnown(v)) return;
    _update(() {
      _language = v;
      _languageChosen = true;
    });
  }

  /// Язык при запуске: заголовок Accept-Language меняется только после перезапуска.
  /// Язык для сайтов (null — язык системы, пока язык не выбирали или выбран «как в системе»).
  String? get siteLanguage =>
      (_languageChosen && _language != Languages.system) ? _language : null;

  bool get languageNeedsRestart => siteLanguage != _siteLangAtStart;
  double get uiScale => _uiScale;
  bool get smoothScroll => _smoothScroll;

  /// Личный ключ Brave Search API: с ним результаты показываются в оформлении Zembo.
  /// Показывать результаты Zembo Search в оформлении браузера.
  bool get searchShell => _searchShell;
  set searchShell(bool v) => _update(() => _searchShell = v);

  String get braveApiKey => _braveApiKey;
  set braveApiKey(String v) => _update(() => _braveApiKey = v.trim());

  /// Ключ Google Safe Browsing: проверка ссылок в результатах на вредоносность.
  /// Данные приложения Google для входа в почту без пароля (OAuth).
  String get googleClientId => _googleClientId;
  set googleClientId(String v) => _update(() => _googleClientId = v.trim());
  String get googleClientSecret => _googleClientSecret;
  set googleClientSecret(String v) =>
      _update(() => _googleClientSecret = v.trim());

  String get safeBrowsingKey => _safeBrowsingKey;
  set safeBrowsingKey(String v) => _update(() => _safeBrowsingKey = v.trim());

  /// Масштаб страницы результатов поиска (сохраняется между запусками).
  double get searchZoom => _searchZoom;
  set searchZoom(double v) => _update(() => _searchZoom = v);

  static String _zoomKey(String host) =>
      host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

  /// Масштаб для сайта (как в Chrome: свой у каждого сайта).
  double zoomForHost(String host) => _siteZoom[_zoomKey(host)] ?? 1.0;

  void setZoomForHost(String host, double z) {
    final k = _zoomKey(host);
    if (k.isEmpty) return;
    _update(() {
      if ((z - 1.0).abs() < 0.001) {
        _siteZoom.remove(k);
      } else {
        _siteZoom[k] = z;
      }
    });
  }

  /// Порядок кнопок: неизвестные убираются, недостающие добавляются в конец.
  List<String> get toolbarOrder {
    final out = <String>[];
    for (final id in _toolbarOrder) {
      if (toolbarDefaults.contains(id) && !out.contains(id)) out.add(id);
    }
    for (final id in toolbarDefaults) {
      if (out.contains(id)) continue;
      // Новые кнопки добавляем перед меню, чтобы оно оставалось последним.
      final menuAt = out.indexOf('menu');
      if (menuAt >= 0) {
        out.insert(menuAt, id);
      } else {
        out.add(id);
      }
    }
    return out;
  }

  /// Кнопка меню (три точки) скрыть нельзя: через неё открываются настройки.
  bool toolbarVisible(String id) => id == 'menu' || !_toolbarHidden.contains(id);

  bool get showCopyButton => _showCopy;
  bool get showStarButton => _showStar;
  set showCopyButton(bool v) => _update(() => _showCopy = v);
  set showStarButton(bool v) => _update(() => _showStar = v);

  void moveToolbarItem(int oldIndex, int newIndex) => _update(() {
        final list = toolbarOrder;
        if (newIndex > oldIndex) newIndex -= 1;
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        _toolbarOrder = list;
      });

  void setToolbarVisible(String id, bool visible) {
    if (id == 'menu') return;
    _update(() {
      if (visible) {
        _toolbarHidden.remove(id);
      } else {
        _toolbarHidden.add(id);
      }
    });
  }

  void resetToolbar() => _update(() {
        _toolbarOrder = List.of(toolbarDefaults);
        _toolbarHidden = {};
        _showCopy = true;
        _showStar = true;
      });
  double get scrollSpeed => _scrollSpeed;
  bool get adBlock => _adBlock;
  List<String> get adAllowHosts => List.unmodifiable(_adAllowHosts);
  bool isAdAllowed(String host) => _adAllowHosts.contains(host);

  static String _key(String host) =>
      host.startsWith('www.') ? host.substring(4) : host;

  Map<String, List<String>> get hiddenSelectors => {
        for (final e in _hidden.entries) e.key: List<String>.unmodifiable(e.value),
      };
  bool isListEnabled(String id) => _enabledLists.contains(id);
  void setListEnabled(String id, bool on) => _update(() {
        if (on) {
          _enabledLists.add(id);
        } else {
          _enabledLists.remove(id);
        }
      });

  int hiddenCount(String host) => _hidden[_key(host)]?.length ?? 0;

  void addHidden(String host, String selector) {
    final k = _key(host);
    if (k.isEmpty || selector.isEmpty) return;
    final list = _hidden.putIfAbsent(k, () => []);
    if (list.contains(selector) || list.length >= 200) return;
    _update(() => list.add(selector));
  }

  void clearHidden(String host) {
    final k = _key(host);
    if (!_hidden.containsKey(k)) return;
    _update(() => _hidden.remove(k));
  }

  set searchEngine(String v) => _update(() => _searchEngine = v);
  set showShortcuts(bool v) => _update(() => _showShortcuts = v);
  set blockTrackers(bool v) => setListEnabled('hagezi-pro', v);

  set protectionLevel(int v) => _update(() {
        switch (v) {
          case 0:
            _adBlock = false;
          case 1:
            _adBlock = true;
            _enabledLists.remove('hagezi-pro');
          default:
            _adBlock = true;
            _enabledLists.add('hagezi-pro');
            _doNotTrack = true;
        }
      });

  set smoothScroll(bool v) => _update(() => _smoothScroll = v);
  set scrollSpeed(double v) =>
      _update(() => _scrollSpeed = v.clamp(0.25, 4.0).toDouble());
  set doNotTrack(bool v) => _update(() => _doNotTrack = v);
  set dns(String v) => _update(() => _dns = v);
  set rejectCookies(bool v) => _update(() => _rejectCookies = v);
  set darkSites(bool v) => _update(() => _darkSites = v);
  set uiScale(double v) => _update(() => _uiScale = v.clamp(0.6, 1.25).toDouble());
  set adBlock(bool v) => _update(() => _adBlock = v);

  void setAdAllowed(String host, bool allowed) {
    if (host.isEmpty) return;
    _update(() {
      _adAllowHosts.remove(host);
      if (allowed) _adAllowHosts.add(host);
    });
  }

  void _update(VoidCallback change) {
    change();
    notifyListeners();
    _save();
  }

  /// Адрес поиска для запроса.
  String searchUrl(String query) {
    final base = searchUrls[_searchEngine] ?? searchUrls['DuckDuckGo']!;
    return base + Uri.encodeQueryComponent(query);
  }

  /// Аргументы Chromium для WebView2 (читаются при запуске браузера).
  /// Если запущен фильтрующий прокси ([proxyPort]), блокировка и DNS работают через него.
  String browserArgumentsFor({int? proxyPort}) {
    final parts = <String>[];
    final siteLang = siteLanguage;
    if (siteLang != null) parts.add('--lang=$siteLang');
    if (proxyPort != null) {
      parts.add('--proxy-server=127.0.0.1:$proxyPort');
      return parts.join(' ');
    }

    // Запасной вариант без прокси.
    final template = dnsTemplates[_dns];
    if (template != null) {
      final t = Uri.encodeComponent(template);
      parts.add('--enable-features=DnsOverHttps:'
          'Templates/$t/DnsOverHttpsTemplates/$t/'
          'Fallback/false/DnsOverHttpsFallback/false');
    }
    if (_adBlock) {
      parts.add('--host-resolver-rules="${AdBlock.hostResolverRules}"');
    }
    return parts.join(' ');
  }

  // ---------- хранение ----------

  static Directory get dataDir {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    return Directory('$base${Platform.pathSeparator}ZemboBrowser');
  }

  String get webviewDataPath =>
      '${dataDir.path}${Platform.pathSeparator}webview';

  static File get _file =>
      File('${dataDir.path}${Platform.pathSeparator}settings.json');

  static Future<AppSettings> load() async {
    final s = AppSettings();
    try {
      final f = _file;
      if (await f.exists()) {
        final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final engine = map['searchEngine'];
        // Zembo Search теперь поиск по умолчанию: при первом запуске новой версии
        // выбираем его, дальше уважаем выбор пользователя.
        if (map['zemboSearchDefault'] == true &&
            engine is String &&
            searchUrls.containsKey(engine)) {
          s._searchEngine = engine;
        }
        final dns = map['dns'];
        if (dns is String && dnsLabels.containsKey(dns)) s._dns = dns;
        s._showShortcuts = map['showShortcuts'] as bool? ?? s._showShortcuts;
        s._smoothScroll = map['smoothScroll'] as bool? ?? s._smoothScroll;
        s._braveApiKey = (map['braveApiKey'] as String?)?.trim() ?? '';
        s._safeBrowsingKey = (map['safeBrowsingKey'] as String?)?.trim() ?? '';
        s._googleClientId = (map['googleClientId'] as String?)?.trim() ?? '';
        s._googleClientSecret =
            (map['googleClientSecret'] as String?)?.trim() ?? '';
        final sz = map['searchZoom'];
        if (sz is num) s._searchZoom = sz.toDouble().clamp(0.5, 3.0).toDouble();
        final siteZoom = map['siteZoom'];
        if (siteZoom is Map) {
          for (final e in siteZoom.entries) {
            final v = e.value;
            if (e.key is String && v is num) {
              s._siteZoom[e.key as String] = v.toDouble().clamp(0.5, 3.0).toDouble();
            }
          }
        }
        s._searchShell = map['searchShell'] as bool? ?? s._searchShell;
        s._showCopy = map['showCopy'] as bool? ?? s._showCopy;
        s._showStar = map['showStar'] as bool? ?? s._showStar;
        final order = map['toolbarOrder'];
        if (order is List) s._toolbarOrder = order.whereType<String>().toList();
        final hiddenTb = map['toolbarHidden'];
        if (hiddenTb is List) s._toolbarHidden = hiddenTb.whereType<String>().toSet();
        final sp = map['scrollSpeed'];
        if (sp is num) s._scrollSpeed = sp.toDouble().clamp(0.25, 4.0).toDouble();
        s._doNotTrack = map['doNotTrack'] as bool? ?? s._doNotTrack;
        s._rejectCookies = map['rejectCookies'] as bool? ?? s._rejectCookies;
        s._darkSites = map['darkSites'] as bool? ?? s._darkSites;
        s._googleDark = map['googleDark'] as bool? ?? s._googleDark;
        s._offerPasswords = map['offerPasswords'] as bool? ?? s._offerPasswords;
        s._autofillPasswords =
            map['autofillPasswords'] as bool? ?? s._autofillPasswords;
        final lang = map['language'];
        if (lang is String && Languages.isKnown(lang)) {
          s._language = lang;
        }
        s._languageChosen = map['languageChosen'] as bool? ?? false;
        final sc = map['uiScale'];
        if (sc is num) s._uiScale = sc.toDouble().clamp(0.6, 1.25).toDouble();
        s._adBlock = map['adBlock'] as bool? ?? s._adBlock;
        final allow = map['adAllowHosts'];
        if (allow is List) {
          s._adAllowHosts = allow.whereType<String>().toList();
        }
        final lists = map['lists'];
        if (lists is List) s._enabledLists = lists.whereType<String>().toSet();
        final hidden = map['hidden'];
        if (hidden is Map) {
          for (final e in hidden.entries) {
            final v = e.value;
            if (e.key is String && v is List) {
              s._hidden[e.key as String] = v.whereType<String>().toList();
            }
          }
        }
      }
    } catch (_) {
      // Битый файл — используем значения по умолчанию.
    }
    s._siteLangAtStart = s.siteLanguage;
    return s;
  }

  Future<void> _save() async {
    try {
      await dataDir.create(recursive: true);
      await _file.writeAsString(jsonEncode({
        'searchEngine': _searchEngine,
        'zemboSearchDefault': true,
        'dns': _dns,
        'showShortcuts': _showShortcuts,
        'smoothScroll': _smoothScroll,
        'braveApiKey': _braveApiKey,
        'safeBrowsingKey': _safeBrowsingKey,
        'googleClientId': _googleClientId,
        'googleClientSecret': _googleClientSecret,
        'searchZoom': _searchZoom,
        'siteZoom': _siteZoom,
        'searchShell': _searchShell,
        'showCopy': _showCopy,
        'showStar': _showStar,
        'toolbarOrder': _toolbarOrder,
        'toolbarHidden': _toolbarHidden.toList(),
        'scrollSpeed': _scrollSpeed,
        'doNotTrack': _doNotTrack,
        'rejectCookies': _rejectCookies,
        'darkSites': _darkSites,
        'googleDark': _googleDark,
        'offerPasswords': _offerPasswords,
        'autofillPasswords': _autofillPasswords,
        'language': _language,
        'languageChosen': _languageChosen,
        'uiScale': _uiScale,
        'adBlock': _adBlock,
        'adAllowHosts': _adAllowHosts,
        'hidden': _hidden,
        'lists': _enabledLists.toList(),
      }));
    } catch (_) {}
  }
}

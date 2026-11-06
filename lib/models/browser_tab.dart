import 'dart:async';

import 'package:webview_windows/webview_windows.dart';

import '../state/brave_search.dart';

class BrowserTab {
  BrowserTab({required this.id, this.isSettings = false});

  final int id;

  /// true — вкладка с настройками браузера.
  bool isSettings;

  /// Адрес открытой страницы. null — стартовая страница.
  String? url;
  String? pageTitle;
  bool loading = false;

  /// Страница результатов поиска в оформлении Zembo (если открыта).
  SearchSession? search;

  /// Результаты, из которых перешли на сайт — чтобы кнопка «назад» вернула их.
  SearchSession? prevSearch;
  bool canGoBack = false;
  bool canGoForward = false;

  /// Масштаб страницы сайта и страницы результатов поиска (1.0 = 100%).
  double zoom = 1.0;
  double searchZoom = 1.0;

  /// Страница развернула видео на весь экран.
  bool fullscreen = false;

  /// Видео вынесено в окошко «картинка в картинке».
  bool pip = false;

  /// На странице (или во вложенном плеере) есть видео.
  bool hasVideo = false;

  /// Настоящая иконка сайта, найденная на странице (адрес картинки).
  String? iconUrl;

  // WebView
  WebviewController? web;
  Future<void>? webInit;
  bool webReady = false;
  bool closed = false;
  final List<String> scriptIds = [];
  final List<StreamSubscription<dynamic>> subs = [];

  bool get isBrowsing => !isSettings && url != null;
  bool get isSearch => !isSettings && search != null;
  bool get isHome => !isSettings && url == null && search == null;

  String get title {
    if (isSettings) return 'Настройки';
    if (search != null && url == null) return '${search!.query} — Zembo Search';
    if (url == null) return 'Zembo Browser';
    final t = pageTitle;
    return (t != null && t.trim().isNotEmpty) ? t : url!;
  }

  /// Иконка сайта (favicon). null — для стартовой страницы, настроек и локальных адресов.
  String? get faviconUrl {
    if (!isBrowsing) return null;
    final host = Uri.tryParse(url!)?.host ?? '';
    if (host.isEmpty || host == 'localhost' || !host.contains('.')) return null;
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) return null;
    return 'https://www.google.com/s2/favicons?sz=64&domain=$host';
  }

  /// Что показывать в адресной строке.
  String get address =>
      isSettings ? 'zembo://settings' : (url ?? search?.query ?? '');
}

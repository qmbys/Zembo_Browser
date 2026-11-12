import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../state/brave_search.dart';

class BrowserTab {
  BrowserTab({required this.id});

  final int id;

  /// Адрес открытой страницы. null — стартовая страница.
  String? url;
  String? pageTitle;
  bool loading = false;
  double progress = 0;
  bool canGoBack = false;
  bool canGoForward = false;

  /// Включена «версия для ПК».
  bool desktop = false;

  /// Ошибка загрузки страницы (показывается вместо пустого экрана).
  String? error;

  /// Контроллер WebView (появляется, когда вкладка открыла сайт).
  InAppWebViewController? web;

  /// Страница результатов Zembo Search (своя оболочка поиска).
  SearchSession? search;

  /// Результаты, с которых человек ушёл на сайт (для кнопки «назад»).
  SearchSession? prevSearch;

  bool get isHome => url == null && search == null;
  bool get isSearch => url == null && search != null;

  String get title {
    if (search != null && url == null) return search!.query;
    if (url == null) return 'Zembo Browser';
    final t = pageTitle;
    return (t != null && t.trim().isNotEmpty) ? t : url!;
  }

  /// Иконка сайта (favicon). null — для стартовой страницы и локальных адресов.
  String? get faviconUrl {
    if (url == null) return null;
    final host = Uri.tryParse(url!)?.host ?? '';
    if (host.isEmpty || host == 'localhost' || !host.contains('.')) return null;
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) return null;
    return 'https://www.google.com/s2/favicons?sz=64&domain=$host';
  }

  String get address => url ?? (search?.query ?? '');
}

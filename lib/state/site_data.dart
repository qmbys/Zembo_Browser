import 'dart:io';

import 'app_settings.dart';

/// Очистка данных сайтов, которые не умеет удалять плагин webview_windows.
class SiteData {
  SiteData._();

  static File get _flag => File(
      '${AppSettings.dataDir.path}${Platform.pathSeparator}wipe_webview.flag');

  /// Полная очистка данных WebView (cookie, хранилища, кэш) при следующем запуске:
  /// пока браузер работает, Windows не даёт удалить папку с данными.
  static Future<void> scheduleFullWipe() async {
    try {
      await AppSettings.dataDir.create(recursive: true);
      await _flag.writeAsString('1');
    } catch (_) {}
  }

  /// Вызывается при запуске до создания первой страницы.
  static Future<void> applyPendingWipe(String? webviewDir) async {
    try {
      if (webviewDir == null || !await _flag.exists()) return;
      final d = Directory(webviewDir);
      if (await d.exists()) await d.delete(recursive: true);
      await _flag.delete();
    } catch (_) {}
  }

  /// Стирает всё, что сайт хранит у себя, как будто его открывают впервые:
  /// localStorage, sessionStorage, IndexedDB, Cache Storage, service worker и
  /// cookie, которые доступны скрипту (закрытые httpOnly так удалить нельзя).
  static const wipeScript = r'''
(function () {
  try { localStorage.clear(); } catch (e) {}
  try { sessionStorage.clear(); } catch (e) {}
  try {
    if (indexedDB.databases) indexedDB.databases().then(function (l) {
      l.forEach(function (d) { try { indexedDB.deleteDatabase(d.name); } catch (e) {} });
    });
  } catch (e) {}
  try {
    caches.keys().then(function (k) { k.forEach(function (n) { caches.delete(n); }); });
  } catch (e) {}
  try {
    navigator.serviceWorker.getRegistrations().then(function (r) {
      r.forEach(function (x) { x.unregister(); });
    });
  } catch (e) {}
  try {
    var parts = location.hostname.split('.'), doms = [''];
    for (var i = 0; i < parts.length - 1; i++) {
      var d = parts.slice(i).join('.');
      doms.push(d); doms.push('.' + d);
    }
    document.cookie.split(';').forEach(function (c) {
      var n = c.split('=')[0].trim();
      if (!n) return;
      doms.forEach(function (dom) {
        document.cookie = n + '=; expires=Thu, 01 Jan 1970 00:00:00 GMT; max-age=0; path=/' +
            (dom ? '; domain=' + dom : '');
      });
    });
  } catch (e) {}
})();
''';
}

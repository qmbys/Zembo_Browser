import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Сохранённые правки одного сайта: свои стили и свой скрипт.
class SiteEdit {
  SiteEdit({this.css = '', this.js = ''});

  String css;
  String js;

  bool get isEmpty => css.trim().isEmpty && js.trim().isEmpty;

  Map<String, dynamic> toJson() => {'css': css, 'js': js};

  factory SiteEdit.fromJson(Map<String, dynamic> m) => SiteEdit(
        css: (m['css'] as String?) ?? '',
        js: (m['js'] as String?) ?? '',
      );
}

/// Правки страниц, сохранённые навсегда. Применяются при каждом открытии сайта.
/// Хранятся в файле page_edits.json в папке ZemboBrowser (рядом с данными пользователя).
class PageEdits extends ChangeNotifier {
  final Map<String, SiteEdit> _sites = {};
  File? _file;

  /// Адрес сайта без «www.» — по нему хранятся правки.
  static String hostKey(String? url) {
    final h = Uri.tryParse(url ?? '')?.host.toLowerCase() ?? '';
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  SiteEdit? forHost(String host) => _sites[host];

  File _resolveFile() {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final dir = Directory('$base${Platform.pathSeparator}ZemboBrowser');
    return File('${dir.path}${Platform.pathSeparator}page_edits.json');
  }

  Future<void> load() async {
    try {
      final f = _file ??= _resolveFile();
      if (!await f.exists()) return;
      final data = jsonDecode(await f.readAsString());
      if (data is! Map) return;
      _sites.clear();
      data.forEach((k, v) {
        if (k is String && v is Map<String, dynamic>) {
          final e = SiteEdit.fromJson(v);
          if (!e.isEmpty) _sites[k] = e;
        }
      });
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final f = _file ??= _resolveFile();
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({
        for (final e in _sites.entries) e.key: e.value.toJson(),
      }));
    } catch (_) {}
  }

  /// Сохранить правки сайта навсегда. Пустые стили и скрипт удаляют запись.
  Future<void> set(String host, String css, String js) async {
    if (host.isEmpty) return;
    final e = SiteEdit(css: css, js: js);
    if (e.isEmpty) {
      _sites.remove(host);
    } else {
      _sites[host] = e;
    }
    notifyListeners();
    await _save();
  }

  /// Удалить сохранённые правки сайта.
  Future<void> remove(String host) async {
    if (_sites.remove(host) != null) {
      notifyListeners();
      await _save();
    }
  }

  // ---------- скрипты ----------

  /// Скрипты для установки в каждую страницу (по одному на сайт: ошибка в одном
  /// скрипте не ломает остальные).
  List<String> scripts() => [
        for (final e in _sites.entries)
          if (!e.value.isEmpty) _siteScript(e.key, e.value),
      ];

  static String _siteScript(String host, SiteEdit e) {
    final b = StringBuffer()
      ..write('(function () {')
      ..write(' if (window.top !== window) return;')
      ..write(' var h = location.hostname.toLowerCase().replace(/^www\\./, "");')
      ..write(' var k = ${jsonEncode(host)};')
      ..write(' if (h !== k && !h.endsWith("." + k)) return;');
    if (e.css.trim().isNotEmpty) {
      b.write(' ${cssApply(e.css)}');
    }
    if (e.js.trim().isNotEmpty) {
      b
        ..write(' function run() { try {\n${e.js}\n} catch (err) { console.error("[Zembo]", err); } }')
        ..write(' if (document.readyState === "loading") {')
        ..write(' document.addEventListener("DOMContentLoaded", run); } else { run(); }');
    }
    b.write(' })();');
    return b.toString();
  }

  /// Применить стили. Сначала через constructable stylesheet (его не блокирует
  /// политика безопасности сайта), запасной вариант — тег <style>.
  static String cssApply(String css) => '''
(function (css) {
  try {
    var old = window.__zUserSheet;
    var sheet = new CSSStyleSheet();
    sheet.replaceSync(css);
    var list = Array.prototype.slice.call(document.adoptedStyleSheets)
      .filter(function (s) { return s !== old; });
    list.push(sheet);
    document.adoptedStyleSheets = list;
    window.__zUserSheet = sheet;
    return 'ok';
  } catch (e) {
    try {
      var st = document.getElementById('zembo-user-css');
      if (!st) {
        st = document.createElement('style');
        st.id = 'zembo-user-css';
        (document.head || document.documentElement).appendChild(st);
      }
      st.textContent = css;
      return 'ok';
    } catch (e2) { return 'err: ' + e2; }
  }
})(${jsonEncode(css)});''';

  /// Выполнить свой скрипт на открытой странице.
  static String jsRun(String js) =>
      '(function () { try {\n$js\n} catch (e) { return "err: " + e; } return "ok"; })()';

  /// Заменить код страницы целиком (только на этой странице).
  static String htmlApply(String html) =>
      '(function (h) { document.open(); document.write(h); document.close(); return "ok"; })(${jsonEncode(html)})';

  static const getHtml =
      '"<!DOCTYPE html>\\n" + document.documentElement.outerHTML';

  /// F12 на странице открывает редактор кода.
  static const f12Script = r'''
(function () {
  if (window.top !== window || window.__zf12) return;
  window.__zf12 = true;
  window.addEventListener('keydown', function (e) {
    if (e.key === 'F12' && !e.ctrlKey && !e.shiftKey && !e.altKey) {
      e.preventDefault();
      e.stopPropagation();
      try { window.chrome.webview.postMessage(JSON.stringify({ type: 'zembo-f12' })); } catch (err) {}
    }
  }, true);
})();
''';
}

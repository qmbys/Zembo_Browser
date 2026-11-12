import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'dart:ui' show Size;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'app_settings.dart';
import 'brave_search.dart';

/// Получает результаты Brave Search без API-ключа: страница результатов загружается
/// в скрытом WebView (его не видно), а скрипт достаёт заголовки, ссылки и описания.
/// Интерфейс поиска рисует сам браузер.
class BraveScraper extends ChangeNotifier {
  BraveScraper(this.settings);

  final AppSettings settings;

  HeadlessInAppWebView? _headless;
  InAppWebViewController? _web;
  Future<void>? _init;
  Completer<List<SearchResult>>? _pending;
  String _kind = 'web';
  int _tries = 0;
  Timer? _retry;
  bool _disposed = false;
  Future<void> _tail = Future.value();

  static const _maxTries = 10;

  // Настольный вид страницы Brave: на нём работают те же селекторы, что и на десктопе.
  static const _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _headless?.dispose();
    super.dispose();
  }

  /// Запросы выполняются по очереди: страница у нас одна.
  Future<List<SearchResult>> fetch(String kind, String query, {int page = 0}) {
    final run = _tail.then((_) => _fetch(kind, query, page));
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _create() async {
    final ready = Completer<void>();
    final h = HeadlessInAppWebView(
      initialSize: const Size(1280, 900),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: _desktopUa,
        preferredContentMode: UserPreferredContentMode.DESKTOP,
      ),
      onWebViewCreated: (c) {
        _web = c;
        c.addJavaScriptHandler(
          handlerName: 'zemboScrape',
          callback: (args) {
            if (args.isNotEmpty) _onMessage(args.first);
            return null;
          },
        );
        if (!ready.isCompleted) ready.complete();
      },
      onLoadStop: (c, url) {
        if (_pending != null) {
          _tries = 0;
          _extract();
        }
      },
    );
    _headless = h;
    await h.run();
    await ready.future.timeout(const Duration(seconds: 10));
  }

  String _url(String kind, String q, int page) {
    final e = Uri.encodeQueryComponent(q);
    switch (kind) {
      case 'news':
        return 'https://search.brave.com/news?q=$e';
      case 'images':
        return 'https://search.brave.com/images?q=$e';
      case 'videos':
        return 'https://search.brave.com/videos?q=$e';
      default:
        return 'https://search.brave.com/search?q=$e&source=web&offset=$page';
    }
  }

  Future<List<SearchResult>> _fetch(String kind, String query, int page) async {
    try {
      _init ??= _create();
      await _init;
    } catch (e) {
      _init = null;
      _headless?.dispose();
      _headless = null;
      throw BraveError('Не удалось запустить фоновую страницу поиска.\n$e');
    }

    final done = Completer<List<SearchResult>>();
    _pending = done;
    _kind = kind;
    _tries = 0;
    _retry?.cancel();

    try {
      await _web!.loadUrl(
          urlRequest: URLRequest(url: WebUri(_url(kind, query, page))));
    } catch (_) {
      _pending = null;
      throw BraveError('Не удалось открыть Brave Search.');
    }

    return done.future.timeout(const Duration(seconds: 25), onTimeout: () {
      _pending = null;
      _retry?.cancel();
      throw BraveError('Brave Search слишком долго отвечает.');
    });
  }

  Future<void> _extract() async {
    if (_pending == null || _web == null) return;
    _tries++;
    try {
      await _web!.evaluateJavascript(source: _script(_kind));
    } catch (_) {}

    // Страница может ещё дорисовываться: если ответа нет, пробуем снова.
    _retry?.cancel();
    _retry = Timer(const Duration(milliseconds: 900), () async {
      final p = _pending;
      if (p == null) return;
      if (_tries >= _maxTries) {
        _pending = null;
        // Что видит скрытая страница: помогает отличить проверку «вы не робот»
        // от изменения вёрстки.
        var info = '';
        try {
          final r = await _web?.evaluateJavascript(
              source: "document.title + ' | ' + location.href + ' | ' + "
                  "(document.body ? document.body.innerText.replace(/\\s+/g,' ').slice(0,160) : '')");
          info = '$r';
        } catch (_) {}
        p.completeError(BraveError(
            'Не удалось получить результаты со страницы Brave Search '
            '(возможно, сайт просит подтвердить, что вы не робот).'
            '${info.isEmpty ? '' : '\n[$info]'}'));
      } else {
        _extract();
      }
    });
  }

  void _onMessage(dynamic msg) {
    try {
      dynamic m = msg;
      for (var i = 0; i < 2 && m is String; i++) {
        m = jsonDecode(m);
      }
      if (m is! Map || m['type'] != 'zembo-scrape') return;
      if (m['kind'] != _kind) return;
      final p = _pending;
      if (p == null) return;

      final list = _parse(m['results'], _kind);
      if (list.isEmpty) return; // подождём: таймер повторит попытку
      _retry?.cancel();
      _pending = null;
      p.complete(list);
    } catch (_) {}
  }

  static String _s(dynamic v, int max) {
    if (v is! String) return '';
    final t = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > max ? t.substring(0, max) : t;
  }

  static String? _http(dynamic v) {
    if (v is! String) return null;
    return (v.startsWith('http://') || v.startsWith('https://')) && v.length < 2500
        ? v
        : null;
  }

  List<SearchResult> _parse(dynamic raw, String kind) {
    final out = <SearchResult>[];
    if (raw is! List) return out;
    for (final e in raw) {
      if (e is! Map) continue;
      final url = _http(e['url']) ?? '';
      final thumb = _http(e['thumb']);
      final host = _s(e['host'], 120);

      if (kind == 'images') {
        if (thumb == null) continue;
        out.add(SearchResult(
          title: _s(e['title'], 200),
          url: url,
          host: host,
          crumbs: host,
          thumb: thumb,
        ));
        continue;
      }

      final title = _s(e['title'], 300);
      if (url.isEmpty || title.isEmpty) continue;
      out.add(SearchResult(
        title: title,
        url: url,
        description: _s(e['description'], 600),
        host: host,
        crumbs: host,
        favicon: _http(e['favicon']),
        thumb: thumb,
      ));
    }
    return out;
  }

  String _script(String kind) => _template.replaceFirst('__KIND__', kind);

  static const _template = r'''
(function () {
  var KIND = '__KIND__';

  function abs(u) { try { return new URL(u, location.href).href; } catch (e) { return ''; } }
  function txt(el) {
    return el ? String(el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim() : '';
  }
  function hostOf(u) {
    try { return new URL(u).hostname.replace(/^www\./, ''); } catch (e) { return ''; }
  }
  function isBrave(h) { return h === '' || /(^|\.)brave\.com$/.test(h); }
  // У картинок Brave размер зашит в адрес: .../rs:fit:200:200:...
  function imgSize(src) {
    var m = /rs:fit:(\d+):(\d+)/.exec(src);
    return m ? parseInt(m[1], 10) : 0;
  }
  function srcOf(im) {
    return im.currentSrc || im.getAttribute('src') || im.getAttribute('data-src') || '';
  }

  function collect() {
  var out = [];

  if (KIND === 'images') {
    var seen = {};
    var imgs = document.querySelectorAll('img');
    for (var i = 0; i < imgs.length; i++) {
      var im = imgs[i];
      if (im.closest('header,footer,nav')) continue;
      var src = srcOf(im);
      if (!src || /^data:/.test(src) || seen[src]) continue;
      var w = imgSize(src);
      var dim = im.naturalWidth || parseInt(im.getAttribute('width') || '0', 10);
      if ((w && w < 90) || (!w && dim && dim < 90)) continue;
      var a = im.closest('a[href]');
      var page = a ? abs(a.getAttribute('href')) : '';
      seen[src] = 1;
      out.push({ title: im.getAttribute('alt') || '', url: page, thumb: abs(src), host: hostOf(page) });
    }
  } else {
    var blocks = [].slice.call(document.querySelectorAll(
      '#results .snippet, [data-type="web"], [data-type="news"], [data-type="videos"], [data-type="video"]'));
    blocks = blocks.filter(function (b) {
      for (var j = 0; j < blocks.length; j++) {
        if (blocks[j] !== b && blocks[j].contains(b)) return false;
      }
      return true;
    });

    if (!blocks.length) {
      // Запасной вариант: ищем заголовки со ссылками.
      var hs = document.querySelectorAll('main h2, main h3, #results h2, #results h3');
      for (var h = 0; h < hs.length; h++) {
        var link0 = hs[h].closest('a[href]') || hs[h].querySelector('a[href]');
        var box = (link0 || hs[h]).parentElement;
        for (var up = 0; box && up < 3 && txt(box).length < 80; up++) box = box.parentElement;
        if (box) blocks.push(box);
      }
    }

    var seenUrl = {};
    blocks.forEach(function (b) {
      var link = null;
      var links = b.querySelectorAll('a[href]');
      for (var k = 0; k < links.length; k++) {
        var u = abs(links[k].getAttribute('href'));
        if (/^https?:/.test(u) && !isBrave(hostOf(u))) { link = links[k]; break; }
      }
      if (!link) return;
      var url = abs(link.getAttribute('href'));
      if (seenUrl[url]) return;
      seenUrl[url] = 1;

      var tEl = b.querySelector('.title, .snippet-title, [class*="title" i], h2, h3');
      var title = txt(tEl) || txt(link);
      if (title.length < 2) return;
      var dEl = b.querySelector('.snippet-description, .generic-snippet, [class*="description" i], .content');
      var desc = txt(dEl);

      var thumb = '', fav = '';
      var ims = b.querySelectorAll('img');
      for (var n = 0; n < ims.length; n++) {
        var s = srcOf(ims[n]);
        if (!s || /^data:/.test(s)) continue;
        var size = imgSize(s);
        if (size >= 90) { if (!thumb) thumb = abs(s); }
        else if (!fav) fav = abs(s);
      }
      out.push({ title: title, url: url, description: desc, host: hostOf(url), favicon: fav, thumb: thumb });
    });
  }

  return out;
  }

  function send(list) {
    try {
      window.flutter_inappwebview.callHandler('zemboScrape', JSON.stringify(
        { type: 'zembo-scrape', kind: KIND, results: list.slice(0, 200) }));
    } catch (e) {}
  }

  // Картинки и видео подгружаются при прокрутке — прокручиваем, чтобы набрать больше.
  if (KIND === 'images' || KIND === 'videos') {
    if (window.__zScraping) return;
    window.__zScraping = true;
    var rounds = 0;
    (function step() {
      window.scrollTo(0, document.body.scrollHeight);
      rounds++;
      if (rounds < 7) { setTimeout(step, 550); return; }
      var list = collect();
      window.__zScraping = false;
      window.scrollTo(0, 0);
      send(list);
    })();
  } else {
    send(collect());
  }
})();
''';
}

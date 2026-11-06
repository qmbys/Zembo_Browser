/// Контекстное меню страницы (правая кнопка мыши): скрипт и описание места клика.
class PageContext {
  PageContext({
    required this.tabId,
    required this.x,
    required this.y,
    required this.page,
    this.img = '',
    this.link = '',
    this.video = '',
    this.text = '',
    this.editable = false,
  });

  final int tabId;
  final double x;
  final double y;
  final String page;
  final String img;
  final String link;
  final String video;
  final String text;
  final bool editable;

  static bool isHttp(String u) =>
      u.startsWith('http://') || u.startsWith('https://');

  static String _s(dynamic v, int max) {
    if (v is! String) return '';
    return v.length > max ? v.substring(0, max) : v;
  }

  /// Разбор сообщения от страницы. Возвращает null, если данные неверные.
  static PageContext? fromMap(int tabId, dynamic m) {
    if (m is! Map) return null;
    final x = m['x'];
    final y = m['y'];
    if (x is! num || y is! num) return null;
    return PageContext(
      tabId: tabId,
      x: x.toDouble(),
      y: y.toDouble(),
      page: _s(m['page'], 2000),
      img: _s(m['img'], 2000),
      link: _s(m['link'], 2000),
      video: _s(m['video'], 2000),
      text: _s(m['text'], 1000),
      editable: m['editable'] == true,
    );
  }
}

class PageMenuScript {
  PageMenuScript._();

  static const support = r'''
(function () {
  if (window.__zctxInit) return;
  window.__zctxInit = true;
  var isTop = window === window.top;

  function post(o) {
    try { window.chrome.webview.postMessage(JSON.stringify(o)); } catch (e) {}
  }
  function abs(u) {
    try { return new URL(u, location.href).href; } catch (e) { return ''; }
  }
  function bgUrl(el) {
    var n = 0;
    while (el && el.nodeType === 1 && n < 4) {
      var bg = getComputedStyle(el).backgroundImage;
      var m = bg && bg.match(/url\((["']?)(.*?)\1\)/);
      if (m && m[2]) return abs(m[2]);
      el = el.parentElement;
      n++;
    }
    return '';
  }

  function info(e) {
    var t = e.target;
    if (!t || !t.closest) return null;
    var inf = { x: e.clientX, y: e.clientY, page: location.href,
                img: '', link: '', video: '', text: '', editable: false };

    var a = t.closest('a[href]');
    if (a) inf.link = abs(a.getAttribute('href'));

    var im = t.closest('img');
    if (im) inf.img = im.currentSrc || im.src || '';
    else inf.img = bgUrl(t);

    var v = t.closest('video');
    if (v) inf.video = v.currentSrc || v.src || '';

    var ed = t.closest('input,textarea,[contenteditable=""],[contenteditable="true"]');
    var isPassword = false;
    if (ed) {
      var type = (ed.type || '').toLowerCase();
      if (ed.tagName !== 'INPUT' ||
          ['', 'text', 'search', 'url', 'email', 'tel', 'password', 'number'].indexOf(type) >= 0) {
        inf.editable = true;
        isPassword = type === 'password';
      }
    }

    var sel = '';
    try { sel = String(window.getSelection ? window.getSelection() : ''); } catch (err) {}
    if (!sel && ed && typeof ed.selectionStart === 'number' && ed.selectionEnd > ed.selectionStart) {
      sel = String(ed.value).substring(ed.selectionStart, ed.selectionEnd);
    }
    inf.text = isPassword ? '' : sel.slice(0, 1000);
    return inf;
  }

  function deliver(inf) {
    if (isTop) post({ type: 'zembo-ctx', info: inf });
    else { try { window.parent.postMessage({ __zctx: 1, info: inf }, '*'); } catch (e) {} }
  }

  // Иконка сайта: берём лучшую картинку из <link rel="icon"> и сообщаем браузеру.
  if (isTop) {
    var lastIcon = null;
    var findIcon = function () {
      var links = document.querySelectorAll('link[rel*="icon" i]');
      var best = '', bestScore = -1;
      for (var i = 0; i < links.length; i++) {
        var l = links[i];
        var rel = (l.getAttribute('rel') || '').toLowerCase();
        if (rel.indexOf('mask-icon') >= 0) continue;
        var href = l.href;
        if (!href) continue;
        var path = href.split('?')[0].toLowerCase();
        var type = (l.getAttribute('type') || '').toLowerCase();
        if (/\.svg$/.test(path) || type.indexOf('svg') >= 0) continue;
        var ico = /\.ico$/.test(path) || type.indexOf('icon') >= 0 && type.indexOf('png') < 0;
        var size = 0;
        var m = (l.getAttribute('sizes') || '').match(/(\d+)x(\d+)/);
        if (m) size = parseInt(m[1], 10);
        else if (rel.indexOf('apple-touch') >= 0) size = 180;
        else size = 32;
        var score = (ico ? 0 : 1000) + Math.min(size, 256);
        if (score > bestScore) { bestScore = score; best = href; }
      }
      if (best !== lastIcon) {
        lastIcon = best;
        post({ type: 'zembo-icon', url: best });
      }
    };
    setInterval(findIcon, 2000);
    window.addEventListener('load', function () { setTimeout(findIcon, 300); });
  }

  // Если сайт сам показывает своё меню (отменил событие) — своё не показываем.
  window.addEventListener('contextmenu', function (e) {
    if (e.defaultPrevented) return;
    var inf = info(e);
    if (!inf) return;
    e.preventDefault();
    deliver(inf);
  }, false);

  // Вложенные плееры и баннеры: координаты пересчитываем в координаты страницы.
  window.addEventListener('message', function (e) {
    var d = e.data;
    if (!d || typeof d !== 'object' || !d.__zctx || !d.info) return;
    var frames = document.querySelectorAll('iframe');
    for (var i = 0; i < frames.length; i++) {
      if (frames[i].contentWindow === e.source) {
        var r = frames[i].getBoundingClientRect();
        d.info.x += r.left;
        d.info.y += r.top;
        deliver(d.info);
        return;
      }
    }
  });
})();
''';

  /// Команды для редактируемых полей.
  static String insertText(String text) =>
      "document.execCommand('insertText', false, ${_js(text)});";
  static const selectAll = "document.execCommand('selectAll');";
  static const deleteSelection = "document.execCommand('delete');";

  static String _js(String s) => _jsonString(s);

  static String _jsonString(String s) {
    final b = StringBuffer("'");
    for (final c in s.runes) {
      switch (c) {
        case 0x27:
          b.write(r"\'");
        case 0x5C:
          b.write(r'\\');
        case 0x0A:
          b.write(r'\n');
        case 0x0D:
          b.write(r'\r');
        case 0x2028:
          b.write(r'\u2028');
        case 0x2029:
          b.write(r'\u2029');
        default:
          b.writeCharCode(c);
      }
    }
    b.write("'");
    return b.toString();
  }
}

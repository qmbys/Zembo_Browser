import 'dart:convert';

/// Встроенные «расширения» — скрипты, которые подставляются в каждую страницу.
class BuiltinScripts {
  BuiltinScripts._();

  // ---------- блокировка записи cookie из JS ----------

  static const rejectCookies = '''
(function () {
  try {
    Object.defineProperty(Document.prototype, 'cookie', {
      get: function () { return ''; },
      set: function (v) {},
      configurable: true
    });
  } catch (e) {}
})();
''';

  /// Cookie с учётом настроек отдельных сайтов.
  /// [global] — «отклонять cookie» в общих настройках, [allow] / [block] — сайты
  /// с явным разрешением или запретом (действуют и на поддомены).
  static String cookiesFor({
    required bool global,
    required List<String> allow,
    required List<String> block,
  }) =>
      '(function () {'
      ' var h = location.hostname.toLowerCase().replace(/^www\\./, "");'
      ' var allow = ${jsonEncode(allow)}; var block = ${jsonEncode(block)};'
      ' function inList(l) { for (var i = 0; i < l.length; i++) {'
      ' if (h === l[i] || h.endsWith("." + l[i])) return true; } return false; }'
      ' var reject = inList(block) || (${global ? 'true' : 'false'} && !inList(allow));'
      ' if (!reject) return;'
      ' var d = Object.getOwnPropertyDescriptor(Document.prototype, "cookie");'
      ' function clean() { try {'
      ' var list = d.get.call(document).split(";");'
      ' for (var i = 0; i < list.length; i++) {'
      ' var n = list[i].split("=")[0].trim(); if (!n) continue;'
      ' d.set.call(document, n + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/");'
      ' } } catch (e) {} }'
      ' clean();'
      ' try { Object.defineProperty(Document.prototype, "cookie", {'
      ' get: function () { return ""; }, set: function (v) {}, configurable: true }); } catch (e) {}'
      ' window.addEventListener("load", clean);'
      ' window.addEventListener("pagehide", clean);'
      '})();';

  // ---------- тёмная тема сайтов (упрощённый аналог Dark Reader) ----------
  // Если сайт сам тёмный, инверсия не включается.

  static const darkMode = r'''
(function () {
  if (window.top !== window) return;
  if (window.__zemboDark) { window.__zemboDark.enable(); return; }

  var D = window.__zemboDark = { off: false, attached: false, siteDark: false };
  var KEY = '__zembo_site_dark';

  var st = document.createElement('style');
  st.id = 'zembo-dark';
  st.textContent =
    'html{filter:invert(1) hue-rotate(180deg)!important}' +
    'img,picture,video,canvas,svg image,iframe,[style*="background-image"]' +
    '{filter:invert(1) hue-rotate(180deg)!important}';

  function attach() {
    if (D.off || D.attached) return;
    var r = document.head || document.documentElement;
    if (!r) return;
    r.appendChild(st);
    D.attached = true;
  }
  function detach() {
    if (!D.attached) return;
    st.remove();
    D.attached = false;
  }

  function parse(c) {
    var m = String(c).match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    var p = m[1].split(/[ ,\/]+/).filter(Boolean).map(parseFloat);
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  }
  function lum(c) { return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) / 255; }
  function bgOf(el) {
    while (el) {
      var c = parse(getComputedStyle(el).backgroundColor);
      if (c && c.a > 0.5) return c;
      el = el.parentElement;
    }
    return null; // фона нет — страница белая
  }

  function check() {
    if (D.off || !document.documentElement || !document.body) return;
    var pts = [[0.5, 0.5], [0.5, 0.2], [0.15, 0.6]];
    var dark = 0, n = 0;
    for (var i = 0; i < pts.length; i++) {
      var el = document.elementFromPoint(innerWidth * pts[i][0], innerHeight * pts[i][1]);
      if (!el) continue;
      n++;
      var c = bgOf(el);
      if (c && lum(c) < 0.45) dark++;
    }
    if (!n) return;
    D.siteDark = dark * 2 > n;
    try { localStorage.setItem(KEY, D.siteDark ? '1' : '0'); } catch (e) {}
    if (D.siteDark) detach(); else attach();
  }

  D.enable = function () {
    D.off = false;
    if (!D.siteDark) attach();
    check();
  };
  D.disable = function () {
    D.off = true;
    detach();
  };

  // Если раньше этот сайт определился как тёмный — не включаем инверсию сразу.
  try { D.siteDark = localStorage.getItem(KEY) === '1'; } catch (e) {}

  function start() {
    if (!D.siteDark) attach();
    if (!D.siteDark && !D.attached) {
      var mo = new MutationObserver(function () {
        if (D.siteDark || D.off) { mo.disconnect(); return; }
        attach();
        if (D.attached) mo.disconnect();
      });
      mo.observe(document, { childList: true, subtree: true });
    }
  }
  start();

  document.addEventListener('DOMContentLoaded', check);
  window.addEventListener('load', check);
  setInterval(check, 1500);

  // Смена темы на самом сайте (класс или атрибут у <html>).
  var timer = null;
  function watch() {
    if (!document.documentElement) { setTimeout(watch, 200); return; }
    new MutationObserver(function () {
      clearTimeout(timer);
      timer = setTimeout(check, 250);
    }).observe(document.documentElement, { attributes: true });
  }
  watch();
})();
''';

  /// Сайты Google: поиск, YouTube, Gmail, Диск и т.д.
  static const _googleHostRe =
      r'/(^|\.)(google\.[a-z]{2,3}(\.[a-z]{2})?|youtube\.com|youtu\.be|gmail\.com|blogger\.com|android\.com|withgoogle\.com)$/';

  /// Тёмная тема: [all] — на всех сайтах, [google] — только на сайтах Google.
  /// Скрипт ставится на старт страницы, поэтому белой вспышки нет.
  static String darkModeFor({required bool all, required bool google}) =>
      '(function () {'
      ' var g = ${google ? 'true' : 'false'} && $_googleHostRe.test(location.hostname);'
      ' if (!${all ? 'true' : 'false'} && !g) return;'
      '$darkMode'
      '})();';

  /// Язык сайтов: меняет navigator.language(s) сразу, заголовок — после перезапуска.
  static String languageOverride(String code) {
    final base = code.split('-').first;
    final list = base == code ? [code] : [code, base];
    return '(function () { try {'
        ' var l = ${jsonEncode(code)}; var ls = ${jsonEncode(list)};'
        " Object.defineProperty(Navigator.prototype, 'language', { get: function () { return l; }, configurable: true });"
        " Object.defineProperty(Navigator.prototype, 'languages', { get: function () { return ls.slice(); }, configurable: true });"
        ' } catch (e) {} })();';
  }

  static const darkModeOff = r'''
(function () {
  if (window.__zemboDark) window.__zemboDark.disable();
})();
''';

  // ---------- SponsorBlock для YouTube ----------
  // Страница шлёт запрос в браузер (postMessage), Dart ходит на sponsor.ajay.app
  // и возвращает отрезки через window.__zemboSB.set(...).

  static String sponsorBlockFor(List<String> allowHosts) =>
      _sponsorBlock.replaceFirst('__ALLOW__', jsonEncode(allowHosts));

  static const _sponsorBlock = '''
(function () {
  if (window.top !== window) return;
  var allow = __ALLOW__;
  for (var k = 0; k < allow.length; k++) {
    if (location.hostname === allow[k] || location.hostname.endsWith('.' + allow[k])) return;
  }
  if (!/(^|\\.)youtube\\.com\$/.test(location.hostname)) return;
  if (window.__zemboSB) return;
  if (!(window.chrome && window.chrome.webview)) return;

  var state = { videoId: null, segs: [], stopped: false, timer: null };
  window.__zemboSB = state;

  state.set = function (id, segs) {
    if (state.videoId === id) state.segs = segs || [];
  };

  function getId() {
    var u = new URL(location.href);
    if (u.pathname === '/watch') return u.searchParams.get('v');
    var m = u.pathname.match(/^\\/(shorts|embed|live)\\/([\\w-]{11})/);
    return m ? m[2] : null;
  }

  async function prefixOf(id) {
    var buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(id));
    var hex = Array.from(new Uint8Array(buf))
      .map(function (b) { return b.toString(16).padStart(2, '0'); }).join('');
    return hex.slice(0, 4);
  }

  async function load(id) {
    state.videoId = id;
    state.segs = [];
    if (!id) return;
    try {
      var p = await prefixOf(id);
      window.chrome.webview.postMessage(
        JSON.stringify({ type: 'zembo-sb', videoId: id, prefix: p }));
    } catch (e) {}
  }

  function tick() {
    if (state.stopped) return;
    var id = getId();
    if (id !== state.videoId) load(id);
    var v = document.querySelector('video');
    if (v && state.segs.length) {
      var t = v.currentTime;
      for (var i = 0; i < state.segs.length; i++) {
        var s = state.segs[i];
        if (t >= s[0] && t < s[1] - 0.3) { v.currentTime = s[1]; break; }
      }
    }
  }

  state.timer = setInterval(tick, 250);
})();
''';

  static const sponsorBlockOff = '''
(function () {
  var s = window.__zemboSB;
  if (s) { clearInterval(s.timer); s.stopped = true; delete window.__zemboSB; }
})();
''';

  // ---------- оформление Zembo Search (страница результатов Brave Search) ----------

  static const zemboSearchSkin = r'''
(function () {
  if (window.top !== window) return;
  if (location.hostname !== 'search.brave.com') return;

  var css =
    ':root{accent-color:#ff5a1f}' +
    '::selection{background:rgba(255,90,31,.35)}' +
    '::-webkit-scrollbar{width:10px;height:10px}' +
    '::-webkit-scrollbar-track{background:transparent}' +
    '::-webkit-scrollbar-thumb{background:#2a3036;border-radius:8px;border:2px solid transparent;background-clip:content-box}' +
    '::-webkit-scrollbar-thumb:hover{background:#3a424a;border:2px solid transparent;background-clip:content-box}';

  function addStyle() {
    if (document.getElementById('zembo-skin')) return true;
    var r = document.head || document.documentElement;
    if (!r) return false;
    var st = document.createElement('style');
    st.id = 'zembo-skin';
    st.textContent = css;
    r.appendChild(st);
    return true;
  }
  if (!addStyle()) {
    var mo = new MutationObserver(function () { if (addStyle()) mo.disconnect(); });
    mo.observe(document, { childList: true, subtree: true });
  }

  // В заголовке вкладки вместо «Brave Search» — «Zembo Search».
  function fixTitle() {
    var t = document.title;
    var n = t.replace(/\s*[-–—]\s*Brave Search\s*$/i, ' — Zembo Search');
    if (n === t && /^Brave Search$/i.test(t)) n = 'Zembo Search';
    if (n !== t) document.title = n;
  }
  function watchTitle() {
    var el = document.querySelector('title');
    if (!el) { setTimeout(watchTitle, 100); return; }
    fixTitle();
    new MutationObserver(fixTitle).observe(el, { childList: true, characterData: true, subtree: true });
  }
  watchTitle();
})();
''';
}

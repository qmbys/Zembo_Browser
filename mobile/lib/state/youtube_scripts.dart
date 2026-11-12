import 'dart:convert';

/// Скрипты для YouTube. Блокировка рекламы лежит в AdBlock.script (ad_blocklist.dart),
/// здесь — пропуск спонсорских вставок (SponsorBlock).
class YoutubeScripts {
  /// [allowHosts] — сайты, где блокировщик выключен.
  static String sponsorBlockFor(List<String> allowHosts) =>
      _sponsorBlock.replaceFirst('__ALLOW__', jsonEncode(allowHosts));

  // Страница шлёт запрос браузеру через мост WebView (callHandler), Dart ходит на
  // sponsor.ajay.app и возвращает отрезки через window.__zemboSB.set(...).
  static const _sponsorBlock = r'''
(function () {
  if (window.top !== window) return;
  var allow = __ALLOW__;
  for (var k = 0; k < allow.length; k++) {
    if (location.hostname === allow[k] || location.hostname.endsWith('.' + allow[k])) return;
  }
  if (!/(^|\.)youtube\.com$/.test(location.hostname)) return;
  if (window.__zemboSB) return;

  var state = { videoId: null, segs: [], stopped: false, timer: null };
  window.__zemboSB = state;

  state.set = function (id, segs) {
    if (state.videoId === id) state.segs = segs || [];
  };

  function getId() {
    var u = new URL(location.href);
    if (u.pathname === '/watch') return u.searchParams.get('v');
    var m = u.pathname.match(/^\/(shorts|embed|live)\/([\w-]{11})/);
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
      var bridge = window.flutter_inappwebview;
      if (bridge && bridge.callHandler) {
        bridge.callHandler('zemboSB', JSON.stringify({ videoId: id, prefix: p }));
      } else {
        // Мост ещё не готов — попробуем на следующем такте.
        state.videoId = null;
      }
    } catch (e) { state.videoId = null; }
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

  static const sponsorBlockOff = r'''
(function () {
  var s = window.__zemboSB;
  if (s) { clearInterval(s.timer); s.stopped = true; delete window.__zemboSB; }
})();
''';
}

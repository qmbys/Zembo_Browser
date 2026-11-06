import 'dart:convert';

/// Плавная прокрутка и скорость колеса мыши. Работает во всех фреймах страницы.
class ScrollScript {
  ScrollScript._();

  static String support(bool smooth, double speed) => _template.replaceFirst(
      '__CFG__', jsonEncode({'smooth': smooth, 'sens': speed}));

  /// Применить настройки на уже открытой странице.
  static String live(bool smooth, double speed) =>
      'window.__zscrollApi && window.__zscrollApi.set('
      '${jsonEncode({'smooth': smooth, 'sens': speed})});';

  static const _template = r'''
(function () {
  if (window.__zscroll) return;
  var S = window.__zscroll = { cfg: __CFG__ };
  var raf = 0, st = null;

  function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

  function canScroll(el, vertical, d) {
    if (vertical) {
      return d > 0 ? el.scrollTop + el.clientHeight < el.scrollHeight - 1 : el.scrollTop > 0;
    }
    return d > 0 ? el.scrollLeft + el.clientWidth < el.scrollWidth - 1 : el.scrollLeft > 0;
  }

  // Ищем элемент под курсором, который реально можно прокрутить.
  function pick(el, dx, dy) {
    var root = document.scrollingElement || document.documentElement;
    while (el && el.nodeType === 1) {
      if (el === document.body || el === document.documentElement) break;
      var cs = getComputedStyle(el);
      if (dy !== 0 && /(auto|scroll)/.test(cs.overflowY) &&
          el.scrollHeight > el.clientHeight + 1 && canScroll(el, true, dy)) return el;
      if (dx !== 0 && /(auto|scroll)/.test(cs.overflowX) &&
          el.scrollWidth > el.clientWidth + 1 && canScroll(el, false, dx)) return el;
      el = el.parentElement;
    }
    if (dy !== 0 && root.scrollHeight > root.clientHeight + 1 && canScroll(root, true, dy)) return root;
    if (dx !== 0 && root.scrollWidth > root.clientWidth + 1 && canScroll(root, false, dx)) return root;
    return null;
  }

  function loop() {
    raf = 0;
    if (!st) return;
    var el = st.el, moving = false;
    if (st.gy !== st.py) {
      var dy = st.gy - st.py;
      st.py = Math.abs(dy) < 0.5 ? st.gy : st.py + dy * 0.2;
      el.scrollTop = st.py;
      if (st.py !== st.gy) moving = true;
    }
    if (st.gx !== st.px) {
      var dx = st.gx - st.px;
      st.px = Math.abs(dx) < 0.5 ? st.gx : st.px + dx * 0.2;
      el.scrollLeft = st.px;
      if (st.px !== st.gx) moving = true;
    }
    if (moving) raf = requestAnimationFrame(loop);
    else st = null;
  }

  window.addEventListener('wheel', function (e) {
    if (e.ctrlKey || e.metaKey) return;
    var c = S.cfg;
    // Стандартные настройки — браузер прокручивает сам.
    if (c.smooth && Math.abs(c.sens - 1) < 0.01) return;

    var unit = e.deltaMode === 1 ? 40 : (e.deltaMode === 2 ? window.innerHeight : 1);
    var dx = e.deltaX * unit * c.sens;
    var dy = e.deltaY * unit * c.sens;
    if (e.shiftKey && dx === 0) { dx = dy; dy = 0; }
    if (!dx && !dy) return;

    var el = pick(e.target, dx, dy);
    if (!el) return;
    e.preventDefault();

    if (!c.smooth) {
      st = null;
      if (dy) el.scrollTop += dy;
      if (dx) el.scrollLeft += dx;
      return;
    }

    if (!st || st.el !== el) {
      st = { el: el, px: el.scrollLeft, py: el.scrollTop, gx: el.scrollLeft, gy: el.scrollTop };
    }
    st.gy = clamp(st.gy + dy, 0, el.scrollHeight - el.clientHeight);
    st.gx = clamp(st.gx + dx, 0, el.scrollWidth - el.clientWidth);
    if (!raf) raf = requestAnimationFrame(loop);
  }, { passive: false, capture: true });

  // Новые настройки приходят сверху вниз по всем вложенным фреймам.
  function apply(cfg) {
    S.cfg = cfg;
    var fr = document.querySelectorAll('iframe');
    for (var i = 0; i < fr.length; i++) {
      try { fr[i].contentWindow.postMessage({ __zscfg: 1, cfg: cfg }, '*'); } catch (e) {}
    }
  }
  window.addEventListener('message', function (e) {
    var d = e.data;
    if (d && typeof d === 'object' && d.__zscfg && d.cfg) apply(d.cfg);
  });
  if (window === window.top) window.__zscrollApi = { set: apply };
})();
''';
}

/// Сигналы «Не отслеживать» и Global Privacy Control для сайтов.
class PrivacyScript {
  PrivacyScript._();

  static const signals = r'''
(function () {
  try {
    Object.defineProperty(Navigator.prototype, 'doNotTrack', {
      get: function () { return '1'; }, configurable: true
    });
    Object.defineProperty(Navigator.prototype, 'globalPrivacyControl', {
      get: function () { return true; }, configurable: true
    });
  } catch (e) {}
})();
''';
}

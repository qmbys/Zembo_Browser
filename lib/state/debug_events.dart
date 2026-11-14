/// Диагностика кликов. Включается в режиме отладки (flutter run) или переменной окружения ZEMBO_DEBUG_EVENTS=1:
/// в левом нижнем углу страницы показываются последние события мыши и фокуса.
class DebugEvents {
  DebugEvents._();

  static const script = r'''
(function () {
  if (window.top !== window || window.__zdbg) return;
  window.__zdbg = 1;
  var box, lines = [];
  function ensure() {
    if (box || !document.documentElement) return;
    box = document.createElement('div');
    box.style.cssText = 'position:fixed;left:6px;bottom:6px;z-index:2147483647;background:rgba(0,0,0,.85);' +
      'color:#0f0;font:11px/1.3 monospace;padding:6px 8px;border:1px solid #0f0;pointer-events:none;max-width:60vw;white-space:pre';
    document.documentElement.appendChild(box);
  }
  function log(s) {
    ensure();
    lines.push(s); if (lines.length > 12) lines.shift();
    if (box) box.textContent = lines.join('\n');
  }
  function desc(e) {
    var t = e.target, n = t && t.tagName ? t.tagName.toLowerCase() : '?';
    var c = t && typeof t.className === 'string' ? '.' + t.className.split(' ')[0] : '';
    return n + c + ' @' + Math.round(e.clientX) + ',' + Math.round(e.clientY) + (e.isTrusted ? '' : ' UNTRUSTED');
  }
  ['pointerdown', 'pointerup', 'mousedown', 'mouseup', 'click'].forEach(function (t) {
    window.addEventListener(t, function (e) {
      log(t + ' ' + desc(e) + (t === 'click' ? ' focus=' + document.hasFocus() : ''));
      setTimeout(function () { if (e.defaultPrevented) log('  ^ ' + t + ' defaultPrevented'); }, 0);
    }, true);
  });
  ['blur', 'focus'].forEach(function (t) {
    window.addEventListener(t, function () { log('WINDOW ' + t); });
  });
  function hello() { log('debug on: ' + location.host); }
  document.addEventListener('DOMContentLoaded', hello);
  window.addEventListener('load', hello);
  document.addEventListener('visibilitychange', function () { log('visibility ' + document.visibilityState); });
  window.addEventListener('resize', function () { log('resize ' + innerWidth + 'x' + innerHeight); });
})();
''';
}

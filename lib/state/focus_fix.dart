/// Встроенный WebView2 время от времени присылает странице пару blur/focus окна
/// (после клика по меню и т.п.). Сайты принимают это за «фокус ушёл мимо» и сразу
/// закрывают меню и окна. Скрипт гасит такие всплески и сообщает, что у страницы есть фокус.
class FocusFix {
  FocusFix._();

  static const script = r'''
(function () {
  if (window.__zfocus) return;
  window.__zfocus = 1;
  try { Document.prototype.hasFocus = function () { return true; }; } catch (e) {}
  var quiet = 0;
  function swallow(e) { e.stopImmediatePropagation(); }
  ['blur', 'focus'].forEach(function (t) {
    window.addEventListener(t, function (e) {
      if (e.target === window) { quiet = Date.now() + 100; swallow(e); }
    }, true);
  });
  ['focusin', 'focusout', 'focus', 'blur'].forEach(function (t) {
    window.addEventListener(t, function (e) {
      if (e.target !== window && Date.now() < quiet) swallow(e);
    }, true);
  });
})();
''';
}

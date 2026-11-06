/// Положение поля ввода почты на странице (для подсказки привязанных адресов).
class MailPrompt {
  const MailPrompt({
    required this.tabId,
    required this.x,
    required this.y,
    required this.width,
  });

  final int tabId;
  final double x;
  final double y;
  final double width;
}

/// Скрипт страниц: замечает поля «e-mail / логин» и сообщает браузеру, где они.
///
/// Список адресов в страницу НЕ передаётся — сайт его не видит. Адрес
/// подставляется только после того, как пользователь выбрал его в подсказке.
class MailScript {
  MailScript._();

  static const support = r'''
(function () {
  if (window.top !== window || window.__zmailInit) return;
  window.__zmailInit = true;

  function post(o) {
    try { window.chrome.webview.postMessage(JSON.stringify(o)); } catch (e) {}
  }

  function isMailField(el) {
    if (!el || el.tagName !== 'INPUT') return false;
    if (el.readOnly || el.disabled) return false;
    var t = (el.type || 'text').toLowerCase();
    if (t !== 'text' && t !== 'email' && t !== '') return false;
    if (t === 'email') return true;
    var ac = (el.getAttribute('autocomplete') || '').toLowerCase();
    if (ac === 'email' || ac === 'username') return true;
    var h = ((el.name || '') + ' ' + (el.id || '') + ' ' +
      (el.placeholder || '') + ' ' + (el.getAttribute('aria-label') || '')).toLowerCase();
    if (/search|query|поиск|найти/.test(h)) return false;
    return /e-?mail|почт|логин|login|username/.test(h);
  }

  function show(el) {
    if (!isMailField(el) || el.value) return;
    window.__zmailEl = el;
    var r = el.getBoundingClientRect();
    post({ type: 'zembo-mail-field', x: r.left, y: r.bottom, w: r.width });
  }

  function hide() { post({ type: 'zembo-mail-hide' }); }

  document.addEventListener('focusin', function (e) { show(e.target); }, true);
  document.addEventListener('click', function (e) {
    if (e.target === document.activeElement) show(e.target);
  }, true);
  document.addEventListener('mousedown', function (e) {
    if (e.target !== window.__zmailEl) hide();
  }, true);
  document.addEventListener('keydown', hide, true);
  window.addEventListener('scroll', hide, true);
  window.addEventListener('resize', hide);
})();
''';

  /// Скрипт подстановки адреса в последнее поле, где показали подсказку.
  static String fill(String jsonEncodedEmail) => '''
(function (v) {
  var el = window.__zmailEl;
  if (!el || !document.contains(el)) el = document.activeElement;
  if (!el || el.tagName !== 'INPUT') return;
  try {
    el.focus();
    var d = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
    d.set.call(el, v);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  } catch (e) {}
})($jsonEncodedEmail);
''';
}

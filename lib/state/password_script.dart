/// Где показать подсказку сохранённых логинов (под полем входа на сайте).
class PasswordPrompt {
  const PasswordPrompt({
    required this.tabId,
    required this.x,
    required this.y,
    required this.width,
    required this.hasPassword,
  });

  final int tabId;
  final double x;
  final double y;
  final double width;

  /// На странице есть видимое поле пароля (можно подставить и его).
  final bool hasPassword;
}

/// Предложение сохранить пароль после входа на сайте.
class PasswordSavePrompt {
  const PasswordSavePrompt({
    required this.tabId,
    required this.host,
    required this.username,
    required this.password,
    required this.update,
  });

  final int tabId;
  final String host;
  final String username;
  final String password;

  /// true — пароль для этого логина уже есть, но он изменился.
  final bool update;
}

/// Скрипт страниц для менеджера паролей.
///
/// Список сохранённых логинов в страницу НЕ передаётся: сайт его не видит.
/// Логин и пароль подставляются только после того, как пользователь выбрал
/// запись в подсказке браузера.
class PasswordScript {
  PasswordScript._();

  static const support = r'''
(function () {
  if (window.top !== window || window.__zpwInit) return;
  window.__zpwInit = true;

  function post(o) {
    try { window.chrome.webview.postMessage(JSON.stringify(o)); } catch (e) {}
  }
  function vis(el) {
    if (!el || !el.getBoundingClientRect) return false;
    var r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    var s = getComputedStyle(el);
    return s.visibility !== 'hidden' && s.display !== 'none';
  }
  function pwIn(scope) {
    var a = (scope || document).querySelectorAll('input[type=password]');
    var out = [];
    for (var i = 0; i < a.length; i++) {
      if (!a[i].disabled && !a[i].readOnly && vis(a[i])) out.push(a[i]);
    }
    return out;
  }
  function isUserType(el) {
    if (!el || el.tagName !== 'INPUT') return false;
    if (el.readOnly || el.disabled) return false;
    var t = (el.type || 'text').toLowerCase();
    return t === 'text' || t === 'email' || t === 'tel' || t === '';
  }
  function hint(el) {
    return ((el.name || '') + ' ' + (el.id || '') + ' ' + (el.placeholder || '') +
      ' ' + (el.getAttribute('aria-label') || '')).toLowerCase();
  }
  function looksSearch(el) {
    return /search|query|поиск|найти|captcha|капча/.test(hint(el));
  }
  function isUserField(el) {
    if (!isUserType(el) || looksSearch(el) || !vis(el)) return false;
    var ac = (el.getAttribute('autocomplete') || '').toLowerCase();
    if (/username|email/.test(ac)) return true;
    if ((el.type || '').toLowerCase() === 'email') return true;
    if (/e-?mail|почт|логин|login|user|имя пользователя|телефон|phone|account|аккаунт/.test(hint(el))) return true;
    return pwIn(el.form || document).length > 0;
  }
  function findUser(pw) {
    var scope = pw.form || document;
    var all = scope.querySelectorAll('input');
    var best = null;
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      if (el === pw) break;
      if (isUserType(el) && !looksSearch(el) && vis(el)) best = el;
    }
    return best;
  }

  // Запоминаем введённый логин на время вкладки: у некоторых сайтов
  // (например, у Google) логин и пароль вводятся на разных страницах.
  function rememberUser(el) {
    try {
      if (el && el.value && isUserField(el)) sessionStorage.setItem('__zpw_u', el.value);
    } catch (e) {}
  }
  function savedUser() {
    try { return sessionStorage.getItem('__zpw_u') || ''; } catch (e) { return ''; }
  }

  // ----- подсказка сохранённых логинов -----
  function show(el) {
    if (!el || el.tagName !== 'INPUT') return;
    var isPw = (el.type || '').toLowerCase() === 'password';
    if (!isPw && !isUserField(el)) return;
    if (el.value) return;
    window.__zpwEl = el;
    var r = el.getBoundingClientRect();
    post({
      type: 'zembo-pw-field',
      x: r.left, y: r.bottom, w: r.width,
      hasPw: isPw || pwIn(el.form || document).length > 0
    });
  }
  function hide() { post({ type: 'zembo-pw-hide' }); }

  document.addEventListener('focusin', function (e) { show(e.target); }, true);
  document.addEventListener('click', function (e) {
    if (e.target === document.activeElement) show(e.target);
  }, true);
  document.addEventListener('mousedown', function (e) {
    if (e.target !== window.__zpwEl) hide();
  }, true);
  document.addEventListener('keydown', hide, true);
  document.addEventListener('change', function (e) { rememberUser(e.target); }, true);
  document.addEventListener('focusout', function (e) { rememberUser(e.target); }, true);
  window.addEventListener('scroll', hide, true);
  window.addEventListener('resize', hide);

  // ----- вход: предложить сохранить пароль -----
  function send(scopeEl) {
    var scope = null;
    if (scopeEl && scopeEl.tagName === 'FORM') scope = scopeEl;
    else if (scopeEl && scopeEl.closest) scope = scopeEl.closest('form');
    var filled = pwIn(scope || document).filter(function (e) { return e.value; });
    if (!filled.length && scope) {
      filled = pwIn(document).filter(function (e) { return e.value; });
    }
    if (!filled.length) return;
    // Форма смены пароля: старый, новый, повтор — берём новый.
    var pw = filled.length >= 3 ? filled[1] : filled[0];
    var u = findUser(pw);
    var uv = u ? u.value : '';
    if (u && uv) rememberUser(u);
    if (!uv) uv = savedUser();
    var key = uv + '\u0000' + pw.value;
    var now = Date.now();
    if (window.__zpwSent === key && now - (window.__zpwT || 0) < 4000) return;
    window.__zpwSent = key;
    window.__zpwT = now;
    post({ type: 'zembo-pw-submit', host: location.hostname, user: uv, pass: pw.value });
  }

  var SUBMIT_RE = /sign|log\s?in|войти|вход|продолж|далее|next|continue|submit|register|создать|зарегистр|отправ|подтверд|готово/i;
  var SKIP_RE = /show|hide|eye|visib|показ|скрыт|забыл|forgot|reset|recover|google|facebook|apple|vk\b|qr/i;

  document.addEventListener('submit', function (e) { send(e.target); }, true);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && e.target && e.target.tagName === 'INPUT') send(e.target);
  }, true);
  document.addEventListener('click', function (e) {
    var t = e.target;
    if (!t || !t.closest) return;
    var b = t.closest('button,input[type=submit],input[type=button],[role=button],a');
    if (!b) return;
    var label = (String(b.innerText || b.value || '') + ' ' +
      (b.getAttribute('aria-label') || '') + ' ' + String(b.className || '') + ' ' +
      (b.id || '') + ' ' + (b.getAttribute('title') || '')).toLowerCase();
    if (SKIP_RE.test(label)) return;
    var type = (b.getAttribute('type') || '').toLowerCase();
    var isSubmit = (b.tagName === 'INPUT' && type === 'submit') ||
      (b.tagName === 'BUTTON' && (type === 'submit' || (!type && !!b.form)));
    if (isSubmit || SUBMIT_RE.test(label)) send(b);
  }, true);
})();
''';

  static const _fillBody = r'''
  function vis(el) {
    if (!el || !el.getBoundingClientRect) return false;
    var r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    var s = getComputedStyle(el);
    return s.visibility !== 'hidden' && s.display !== 'none';
  }
  function setv(el, v) {
    try {
      el.focus();
      var d = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
      d.set.call(el, v);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    } catch (e) {}
  }
  var el = window.__zpwEl;
  if (!el || !document.contains(el)) el = document.activeElement;
  if (!el || el.tagName !== 'INPUT') return;
  var scope = el.form || document;
  var isPw = (el.type || '').toLowerCase() === 'password';
  var pw = isPw ? el : null;
  var us = isPw ? null : el;
  if (!pw && p) {
    var a = scope.querySelectorAll('input[type=password]');
    for (var i = 0; i < a.length; i++) {
      if (vis(a[i]) && !a[i].disabled && !a[i].readOnly) { pw = a[i]; break; }
    }
  }
  if (isPw && u) {
    var all = scope.querySelectorAll('input');
    for (var j = 0; j < all.length; j++) {
      if (all[j] === pw) break;
      var t = (all[j].type || 'text').toLowerCase();
      if ((t === 'text' || t === 'email' || t === 'tel') && vis(all[j]) &&
          !all[j].disabled && !all[j].readOnly) us = all[j];
    }
  }
  if (us && u) setv(us, u);
  if (pw && p) setv(pw, p);
''';

  /// Подставляет выбранный логин и пароль. [passJson] — пустая строка JSON (`""`),
  /// если пароль на странице подставлять не нужно.
  static String fill(String userJson, String passJson) =>
      '(function (u, p) {$_fillBody})($userJson, $passJson);';
}

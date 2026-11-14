import 'dart:io';

/// Внешние протоколы (tg:, discord:, steam:, mailto: и любые свои схемы приложений):
/// страница просит открыть ссылку, браузер спрашивает пользователя и передаёт её
/// программе, зарегистрированной в Windows.
class ExternalLinks {
  ExternalLinks._();

  /// Схемы, которые никогда не открываем: они выполняют код или читают файлы.
  static const _denied = <String>{
    'javascript', 'data', 'vbscript', 'file', 'about', 'blob', 'view-source',
    'chrome', 'edge', 'devtools', 'ms-msdt', 'search-ms', 'search',
    'ms-officecmd', 'ms-appinstaller', 'shell', 'ie.http', 'jar', 'ftp',
    'ws', 'wss', 'http', 'https',
  };

  static final _scheme = RegExp(r'^([a-z][a-z0-9+.\-]{1,40}):', caseSensitive: false);

  /// Схема ссылки (в нижнем регистре) или null, если ссылка не похожа на внешнюю.
  static String? schemeOf(String url) {
    if (url.length > 2000 || RegExp(r'[\x00-\x1f]').hasMatch(url)) return null;
    return _scheme.firstMatch(url)?.group(1)?.toLowerCase();
  }

  /// Можно ли предложить пользователю открыть эту ссылку в приложении.
  static bool canOffer(String url) {
    final s = schemeOf(url);
    return s != null && !_denied.contains(s);
  }

  /// Понятное название приложения для окна подтверждения.
  static String appName(String url) {
    final s = schemeOf(url) ?? '';
    const names = {
      'tg': 'Telegram', 'telegram': 'Telegram', 'discord': 'Discord',
      'steam': 'Steam', 'spotify': 'Spotify', 'mailto': 'Почта',
      'tel': 'Телефон', 'skype': 'Skype', 'zoommtg': 'Zoom', 'zoomus': 'Zoom',
      'msteams': 'Microsoft Teams', 'slack': 'Slack', 'viber': 'Viber',
      'whatsapp': 'WhatsApp', 'vscode': 'VS Code', 'minecraft': 'Minecraft',
      'magnet': 'торрент-клиент',
    };
    return names[s] ?? s;
  }

  /// Открывает ссылку без командной оболочки, чтобы в адрес нельзя было подставить команду.
  static Future<bool> open(String url) async {
    if (!Platform.isWindows || !canOffer(url)) return false;
    try {
      await Process.start('rundll32', ['url.dll,FileProtocolHandler', url],
          mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Скрипт страницы: перехватывает клики по ссылкам с «чужими» схемами и window.open.
  static const script = r'''
(function () {
  if (window.__zextlinks) return;
  window.__zextlinks = 1;
  var INTERNAL = /^(https?|about|blob|data|javascript|file|ws|wss|view-source|chrome|edge|devtools):/i;
  function isExt(u) {
    return typeof u === 'string' && /^[a-z][a-z0-9+.\-]*:/i.test(u) && !INTERNAL.test(u);
  }
  function post(o) {
    try { window.chrome.webview.postMessage(JSON.stringify(o)); } catch (e) {}
  }
  document.addEventListener('click', function (e) {
    if (!e.isTrusted && !e.__zok) return;
    var el = e.target;
    while (el && el.nodeType === 1 && el.tagName !== 'A') el = el.parentElement;
    if (!el || !el.getAttribute) return;
    var href = el.getAttribute('href');
    if (isExt(href)) {
      e.preventDefault();
      post({ type: 'zembo-ext', url: href });
    }
  }, true);
  var oldOpen = window.open;
  window.open = function (u) {
    if (isExt(String(u || ''))) {
      post({ type: 'zembo-ext', url: String(u) });
      return null;
    }
    return oldOpen.apply(this, arguments);
  };

  // Автоматические попытки сайта открыть приложение (например, t.me при загрузке страницы)
  // без клика пользователя гасим молча: иначе WebView2 показывает своё окно «Этот веб-сайт
  // пытается открыть ...». Если пользователь кликнул — спрашиваем через нашу плашку.
  function gesture() {
    try { return !!(navigator.userActivation && navigator.userActivation.isActive); }
    catch (e) { return true; }
  }
  function offer(u) { if (gesture()) post({ type: 'zembo-ext', url: u }); }
  try {
    if (window.navigation && window.navigation.addEventListener) {
      window.navigation.addEventListener('navigate', function (e) {
        var u = e.destination && e.destination.url;
        if (isExt(u) && e.cancelable) { e.preventDefault(); offer(u); }
      });
    }
  } catch (err) {}
  try {
    var d = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, 'src');
    if (d && d.set) {
      Object.defineProperty(HTMLIFrameElement.prototype, 'src', {
        configurable: true, enumerable: d.enumerable, get: d.get,
        set: function (v) {
          if (isExt(String(v))) { offer(String(v)); return; }
          d.set.call(this, v);
        }
      });
    }
    var oldSet = Element.prototype.setAttribute;
    Element.prototype.setAttribute = function (n, v) {
      if (this instanceof HTMLIFrameElement && String(n).toLowerCase() === 'src' && isExt(String(v))) {
        offer(String(v)); return;
      }
      return oldSet.apply(this, arguments);
    };
  } catch (err) {}
})();
''';
}

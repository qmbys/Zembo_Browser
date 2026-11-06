import 'package:flutter/services.dart';

import 'panels_controller.dart';
import 'tabs_controller.dart';

/// Скрипт для страниц сайтов: когда фокус внутри страницы, Flutter не получает
/// нажатия клавиш, поэтому страница сама пересылает нужные сочетания браузеру.
class KeyScript {
  KeyScript._();

  static const support = r'''
(function () {
  if (window.__zkeyInit) return;
  window.__zkeyInit = true;

  var CODES = {
    Tab: 1, PageUp: 1, PageDown: 1, Minus: 1, Equal: 1,
    NumpadAdd: 1, NumpadSubtract: 1, KeyT: 1, KeyW: 1, KeyL: 1,
    KeyR: 1, KeyJ: 1, Digit0: 1, Digit1: 1, Digit2: 1, Digit3: 1,
    Digit4: 1, Digit5: 1, Digit6: 1, Digit7: 1, Digit8: 1, Digit9: 1
  };

  window.addEventListener('keydown', function (e) {
    var ctrl = e.ctrlKey || e.metaKey;
    var hit = false;
    if (ctrl && !e.altKey && CODES[e.code]) hit = true;
    if (e.altKey && !ctrl && !e.shiftKey &&
        (e.code === 'ArrowLeft' || e.code === 'ArrowRight')) hit = true;
    if (e.code === 'F5' && !ctrl && !e.altKey) hit = true;
    if (!hit) return;
    // Ctrl+Shift+W и подобное оставляем системе.
    if (ctrl && e.shiftKey && e.code === 'KeyW') return;
    e.preventDefault();
    e.stopPropagation();
    try {
      window.chrome.webview.postMessage(JSON.stringify({
        type: 'zembo-key', code: e.code,
        ctrl: ctrl, shift: e.shiftKey, alt: e.altKey,
        repeat: e.repeat === true
      }));
    } catch (err) {}
  }, true);
})();
''';
}

/// Горячие клавиши браузера (как в Chrome / Brave).
///
///  Ctrl+T — новая вкладка            Ctrl+Shift+T — вернуть закрытую вкладку
///  Ctrl+W — закрыть вкладку          Ctrl+Tab / Ctrl+Shift+Tab — следующая / предыдущая
///  Ctrl+1…8 — вкладка по номеру      Ctrl+9 — последняя вкладка
///  Ctrl+L — адресная строка          Ctrl+R / F5 — обновить
///  Alt+← / Alt+→ — назад / вперёд    Ctrl+J — загрузки
///  Ctrl++ / Ctrl+- / Ctrl+0 — масштаб страницы
///  Esc — закрыть контекстное меню
class KeyboardShortcuts {
  KeyboardShortcuts({required this.tabs, required this.panels});

  final TabsController tabs;
  final PanelsController panels;

  // Физические клавиши — чтобы работало и на русской раскладке.
  static final Map<PhysicalKeyboardKey, String> _physical = {
    PhysicalKeyboardKey.keyT: 't',
    PhysicalKeyboardKey.keyW: 'w',
    PhysicalKeyboardKey.keyL: 'l',
    PhysicalKeyboardKey.keyR: 'r',
    PhysicalKeyboardKey.keyJ: 'j',
    PhysicalKeyboardKey.digit0: '0',
    PhysicalKeyboardKey.digit1: '1',
    PhysicalKeyboardKey.digit2: '2',
    PhysicalKeyboardKey.digit3: '3',
    PhysicalKeyboardKey.digit4: '4',
    PhysicalKeyboardKey.digit5: '5',
    PhysicalKeyboardKey.digit6: '6',
    PhysicalKeyboardKey.digit7: '7',
    PhysicalKeyboardKey.digit8: '8',
    PhysicalKeyboardKey.digit9: '9',
    PhysicalKeyboardKey.minus: 'minus',
    PhysicalKeyboardKey.numpadSubtract: 'minus',
    PhysicalKeyboardKey.equal: 'plus',
    PhysicalKeyboardKey.numpadAdd: 'plus',
    PhysicalKeyboardKey.tab: 'tab',
    PhysicalKeyboardKey.pageUp: 'pageup',
    PhysicalKeyboardKey.pageDown: 'pagedown',
    PhysicalKeyboardKey.arrowLeft: 'left',
    PhysicalKeyboardKey.arrowRight: 'right',
    PhysicalKeyboardKey.f5: 'f5',
    PhysicalKeyboardKey.escape: 'escape',
  };

  /// То же для кодов клавиш из браузерной страницы (KeyboardEvent.code).
  static String? nameFromCode(String code) {
    if (code.startsWith('Key') && code.length == 4) {
      return code.substring(3).toLowerCase();
    }
    if (code.startsWith('Digit') && code.length == 6) return code.substring(5);
    switch (code) {
      case 'Minus':
      case 'NumpadSubtract':
        return 'minus';
      case 'Equal':
      case 'NumpadAdd':
        return 'plus';
      case 'Tab':
        return 'tab';
      case 'PageUp':
        return 'pageup';
      case 'PageDown':
        return 'pagedown';
      case 'ArrowLeft':
        return 'left';
      case 'ArrowRight':
        return 'right';
      case 'F5':
        return 'f5';
    }
    return null;
  }

  void attach() {
    HardwareKeyboard.instance.addHandler(_onKey);
    tabs.onWebKey = (code, ctrl, shift, alt, repeat) {
      final name = nameFromCode(code);
      if (name != null) handle(name, ctrl, shift, alt, repeat: repeat);
    };
  }

  void detach() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    tabs.onWebKey = null;
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyUpEvent) return false;
    final name = _physical[e.physicalKey];
    if (name == null) return false;
    final hk = HardwareKeyboard.instance;
    return handle(
      name,
      hk.isControlPressed,
      hk.isShiftPressed,
      hk.isAltPressed,
      repeat: e is KeyRepeatEvent,
    );
  }

  /// Выполняет сочетание. Возвращает true, если оно известно браузеру
  /// (тогда нажатие дальше не передаётся).
  bool handle(String k, bool ctrl, bool shift, bool alt, {bool repeat = false}) {
    if (k == 'escape') {
      if (ctrl || shift || alt) return false;
      if (tabs.ctx != null) {
        if (!repeat) tabs.closeContext();
        return true;
      }
      if (tabs.mailPrompt != null) {
        if (!repeat) tabs.hideMailPrompt();
        return true;
      }
      return false;
    }

    if (alt && !ctrl && !shift) {
      if (k == 'left') {
        if (!repeat) tabs.back();
        return true;
      }
      if (k == 'right') {
        if (!repeat) tabs.forward();
        return true;
      }
      return false;
    }

    if (k == 'f5' && !ctrl && !alt) {
      if (!repeat) tabs.reload();
      return true;
    }

    if (!ctrl || alt) return false;

    switch (k) {
      case 'plus':
        tabs.zoomIn();
        return true;
      case 'minus':
        tabs.zoomOut();
        return true;
      case '0':
        tabs.zoomReset();
        return true;
      case 't':
        if (!repeat) {
          if (shift) {
            tabs.reopenClosed();
          } else {
            tabs.addTab();
            tabs.requestAddressFocus();
          }
        }
        return true;
      case 'w':
        if (shift) return false;
        if (!repeat) tabs.close(tabs.activeId);
        return true;
      case 'tab':
      case 'pagedown':
      case 'pageup':
        if (!repeat) {
          final back = k == 'pageup' || (k == 'tab' && shift);
          tabs.selectRelative(back ? -1 : 1);
        }
        return true;
      case 'r':
        if (!repeat) tabs.reload();
        return true;
      case 'l':
        if (!repeat) tabs.requestAddressFocus();
        return true;
      case 'j':
        if (!repeat) panels.toggle(PanelKind.downloads);
        return true;
    }

    final n = int.tryParse(k);
    if (n != null && n >= 1 && n <= 9) {
      if (!repeat) tabs.selectIndex(n == 9 ? -1 : n - 1);
      return true;
    }
    return false;
  }
}

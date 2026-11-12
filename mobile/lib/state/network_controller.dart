import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'app_settings.dart';
import 'filter_lists.dart';
import 'filter_proxy.dart';

/// Выбор DNS-сервера (DNS-over-HTTPS). Если выбран не «Системный», весь трафик
/// страниц идёт через локальный прокси браузера: он сам запрашивает адреса у
/// выбранного DNS и заодно блокирует рекламные домены, не дёргая интерфейс на
/// каждый запрос.
class NetworkController extends ChangeNotifier {
  NetworkController(this.settings, this.lists, {required this.onBlocked}) {
    settings.addListener(apply);
  }

  final AppSettings settings;
  final FilterLists lists;
  final VoidCallback onBlocked;

  FilterProxy? _proxy;
  bool _active = false;
  bool _busy = false;
  bool _again = false;
  bool _disposed = false;

  /// Прокси включён, трафик идёт через него.
  bool get active => _active;

  Future<void> apply() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        final want = settings.dns != 'system';
        if (want && !_active) {
          await _enable();
        } else if (!want && _active) {
          await _disable();
        }
      } while (_again && !_disposed);
    } finally {
      _busy = false;
    }
  }

  Future<void> _enable() async {
    try {
      final ok = await WebViewFeature.isFeatureSupported(
          WebViewFeature.PROXY_OVERRIDE);
      if (!ok) return;
      final p = FilterProxy(settings, lists, onBlocked: onBlocked);
      if (!await p.start()) {
        p.dispose();
        return;
      }
      await ProxyController.instance().setProxyOverride(
        settings: ProxySettings(
          proxyRules: [ProxyRule(url: '127.0.0.1:${p.port}')],
        ),
      );
      _proxy = p;
      _active = true;
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Не вышло — остаёмся на системном DNS.
    }
  }

  Future<void> _disable() async {
    try {
      await ProxyController.instance().clearProxyOverride();
    } catch (_) {}
    _proxy?.dispose();
    _proxy = null;
    _active = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    settings.removeListener(apply);
    _proxy?.dispose();
    super.dispose();
  }
}

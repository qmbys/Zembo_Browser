import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_settings.dart';

/// Что сайт может делать. Для cookie `ask` значит «как в общих настройках».
enum PermKind { cookies, location, microphone, camera, notifications, clipboard, sensors }

enum PermValue { ask, allow, block }

/// Настройки отдельных сайтов: cookie, местоположение, микрофон, камера и т.д.
/// Хранятся в %APPDATA%\ZemboBrowser\site_permissions.json.
class SitePermissions extends ChangeNotifier {
  final Map<String, Map<String, int>> _data = {};
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static File get _file => File(
      '${AppSettings.dataDir.path}${Platform.pathSeparator}site_permissions.json');

  /// Сайт без «www.» в нижнем регистре.
  static String hostKey(String host) =>
      host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

  Future<void> init() async {
    try {
      final f = _file;
      if (!await f.exists()) return;
      final map = jsonDecode(await f.readAsString());
      if (map is! Map) return;
      map.forEach((host, v) {
        if (host is! String || v is! Map) return;
        final m = <String, int>{};
        v.forEach((k, val) {
          if (k is String && val is int && val >= 1 && val <= 2) m[k] = val;
        });
        if (m.isNotEmpty) _data[host] = m;
      });
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await AppSettings.dataDir.create(recursive: true);
      await _file.writeAsString(jsonEncode(_data));
    } catch (_) {}
  }

  /// Ищет настройку для сайта, затем для его родительских доменов
  /// (настройка для youtube.com действует и на m.youtube.com).
  PermValue get(String host, PermKind kind) {
    var h = hostKey(host);
    while (h.isNotEmpty) {
      final v = _data[h]?[kind.name];
      if (v != null) return PermValue.values[v];
      final i = h.indexOf('.');
      if (i < 0 || h.indexOf('.', i + 1) < 0) break;
      h = h.substring(i + 1);
    }
    return PermValue.ask;
  }

  void set(String host, PermKind kind, PermValue value) {
    final h = hostKey(host);
    if (h.isEmpty) return;
    final m = _data.putIfAbsent(h, () => {});
    if (value == PermValue.ask) {
      m.remove(kind.name);
      if (m.isEmpty) _data.remove(h);
    } else {
      m[kind.name] = value.index;
    }
    notifyListeners();
    _save();
  }

  bool hasAny(String host) => _data.containsKey(hostKey(host));

  void reset(String host) {
    if (_data.remove(hostKey(host)) != null) {
      notifyListeners();
      _save();
    }
  }

  /// Сайты, для которых cookie явно разрешены или запрещены.
  List<String> cookieHosts(PermValue value) => [
        for (final e in _data.entries)
          if (e.value[PermKind.cookies.name] == value.index) e.key,
      ];

  /// Подпись настроек cookie — чтобы понять, что скрипты нужно переустановить.
  String get cookieSignature =>
      '${cookieHosts(PermValue.allow).join(',')}|${cookieHosts(PermValue.block).join(',')}';
}

/// Запрос сайта на доступ (местоположение, микрофон и т.д.), ожидающий ответа.
class PermissionAsk {
  PermissionAsk(this.tabId, this.host, this.kind);

  final int tabId;
  final String host;
  final PermKind kind;
  final Completer<bool> result = Completer<bool>();
}

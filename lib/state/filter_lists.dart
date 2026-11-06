import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'ad_blocklist.dart';
import 'app_settings.dart';

class FilterListDef {
  const FilterListDef({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
  });

  final String id;
  final String name;
  final String description;
  final String url;
}

/// Достаёт домены из текста списка: «||domain^», «0.0.0.0 domain» или просто «domain».
Set<String> parseDomainList(String text) {
  final out = <String>{};
  final domainRe = RegExp(r'^[a-z0-9][a-z0-9._-]*\.[a-z0-9-]{2,}$');
  final hostsRe = RegExp(r'^(?:0\.0\.0\.0|127\.0\.0\.1)\s+(\S+)');
  final endRe = RegExp(r'[\^$/*]');

  for (var line in const LineSplitter().convert(text)) {
    line = line.trim();
    if (line.isEmpty) continue;
    final c = line.codeUnitAt(0);
    // Комментарии, заголовки и исключения пропускаем.
    if (c == 0x21 || c == 0x23 || c == 0x5B) continue; // ! # [
    if (line.startsWith('@@')) continue;

    String? d;
    if (line.startsWith('||')) {
      final rest = line.substring(2);
      final m = endRe.firstMatch(rest);
      if (m == null) {
        d = rest;
      } else {
        final ch = rest[m.start];
        // Правила с путём или маской — не про весь домен.
        if (ch == '/' || ch == '*') continue;
        d = rest.substring(0, m.start);
      }
    } else {
      final h = hostsRe.firstMatch(line);
      if (h != null) {
        d = h.group(1);
      } else {
        final hash = line.indexOf(' #');
        d = (hash > 0 ? line.substring(0, hash) : line).trim();
      }
    }
    if (d == null) continue;
    d = d.toLowerCase();
    if (domainRe.hasMatch(d)) out.add(d);
  }
  return out;
}

/// Готовые списки фильтров: скачиваются, хранятся на диске и обновляются.
class FilterLists extends ChangeNotifier {
  FilterLists(this.settings) {
    settings.addListener(_onSettings);
  }

  final AppSettings settings;

  static const presets = <FilterListDef>[
    FilterListDef(
      id: 'hagezi-gambling',
      name: 'HaGeZi Gambling',
      description: 'Казино и букмекеры',
      url:
          'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/gambling.txt',
    ),
    FilterListDef(
      id: 'arkynx-gambling',
      name: 'Arkynx Gambling',
      description: 'Казино и букмекеры (зеркала)',
      url:
          'https://raw.githubusercontent.com/arkynx/blocklists/main/gambling-domains.txt',
    ),
    FilterListDef(
      id: 'hagezi-pro',
      name: 'HaGeZi Pro',
      description: 'Реклама, трекеры, вредоносные сайты (большой список)',
      url:
          'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt',
    ),
  ];

  static const _staleAfter = Duration(days: 3);

  final Set<String> _builtin = AdBlock.allDomains.toSet();
  final Map<String, Set<String>> _sets = {};
  final Map<String, DateTime> _updated = {};
  final Map<String, String> _status = {};
  final Set<String> _busy = {};
  bool _disposed = false;

  int count(String id) => _sets[id]?.length ?? 0;
  DateTime? updated(String id) => _updated[id];
  String status(String id) => _status[id] ?? '';
  bool isBusy(String id) => _busy.contains(id);
  bool get anyBusy => _busy.isNotEmpty;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    settings.removeListener(_onSettings);
    super.dispose();
  }

  File _file(String id) => File(
      '${AppSettings.dataDir.path}${Platform.pathSeparator}lists${Platform.pathSeparator}$id.txt');

  /// Загружает списки с диска, затем обновляет устаревшие в фоне.
  Future<void> init() async {
    for (final def in presets) {
      if (!settings.isListEnabled(def.id)) continue;
      await _loadCache(def);
    }
    await updateAll();
  }

  Future<void> _loadCache(FilterListDef def) async {
    try {
      final f = _file(def.id);
      if (!await f.exists()) return;
      final text = await f.readAsString();
      _sets[def.id] = await Isolate.run(() => parseDomainList(text));
      _updated[def.id] = await f.lastModified();
      notifyListeners();
    } catch (_) {}
  }

  /// Обновляет включённые списки. [force] — игнорировать срок давности.
  Future<void> updateAll({bool force = false}) async {
    for (final def in presets) {
      if (!settings.isListEnabled(def.id)) continue;
      final u = _updated[def.id];
      final fresh =
          u != null && DateTime.now().difference(u) < _staleAfter && _sets.containsKey(def.id);
      if (force || !fresh) await _update(def);
    }
  }

  Future<void> _update(FilterListDef def) async {
    if (_busy.contains(def.id)) return;
    _busy.add(def.id);
    _status[def.id] = 'Загрузка…';
    notifyListeners();

    final client = HttpClient()
      ..findProxy = ((_) => 'DIRECT') // напрямую, мимо нашего прокси
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(def.url));
      final res = await req.close().timeout(const Duration(seconds: 90));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final text = await res.transform(utf8.decoder).join();

      final parsed = await Isolate.run(() => parseDomainList(text));
      if (parsed.isEmpty) throw const FormatException('empty');

      final f = _file(def.id);
      await f.parent.create(recursive: true);
      await f.writeAsString(text);

      _sets[def.id] = parsed;
      _updated[def.id] = DateTime.now();
      _status[def.id] = '';
    } catch (_) {
      _status[def.id] =
          _sets.containsKey(def.id) ? 'Не удалось обновить' : 'Не удалось скачать';
    } finally {
      client.close(force: true);
      _busy.remove(def.id);
      notifyListeners();
    }
  }

  /// Включили список, которого ещё нет, — скачиваем.
  void _onSettings() {
    for (final def in presets) {
      if (settings.isListEnabled(def.id) &&
          !_sets.containsKey(def.id) &&
          !_busy.contains(def.id)) {
        _loadCache(def).then((_) {
          if (!_sets.containsKey(def.id)) _update(def);
        });
      }
    }
  }

  // ---------- проверка домена ----------

  static bool _inSet(Set<String> set, String host) {
    var h = host;
    while (true) {
      if (set.contains(h)) return true;
      final i = h.indexOf('.');
      if (i < 0) return false;
      h = h.substring(i + 1);
    }
  }

  /// true, если домен (или его родительский домен) есть в списках.
  bool blocks(String host) {
    if (_inSet(_builtin, host)) return true;
    for (final def in presets) {
      final set = _sets[def.id];
      if (set != null && settings.isListEnabled(def.id) && _inSet(set, host)) {
        return true;
      }
    }
    return false;
  }
}

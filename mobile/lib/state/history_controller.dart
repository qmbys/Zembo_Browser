import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_settings.dart';

class HistoryEntry {
  HistoryEntry({required this.url, required this.title, required this.time});

  final String url;
  String title;
  DateTime time;

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        't': time.millisecondsSinceEpoch,
      };
}

/// История посещений. Хранится в %APPDATA%\ZemboBrowser\history.json.
class HistoryController extends ChangeNotifier {
  HistoryController();

  static const _maxItems = 3000;

  final List<HistoryEntry> _items = []; // новые — в начале
  Timer? _saveTimer;
  bool _disposed = false;

  List<HistoryEntry> get items => List.unmodifiable(_items);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }

  static File get _file => File(
      '${AppSettings.dataDir.path}${Platform.pathSeparator}history.json');

  static Future<HistoryController> load() async {
    final h = HistoryController();
    try {
      final f = _file;
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is List) {
          for (final e in data) {
            if (e is! Map) continue;
            final url = e['url'];
            final title = e['title'];
            final t = e['t'];
            if (url is! String || t is! int) continue;
            h._items.add(HistoryEntry(
              url: url,
              title: title is String ? title : '',
              time: DateTime.fromMillisecondsSinceEpoch(t),
            ));
          }
        }
      }
    } catch (_) {}
    return h;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  Future<void> _save() async {
    try {
      await AppSettings.dataDir.create(recursive: true);
      await _file.writeAsString(
          jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  // ---------- запись ----------

  void record(String url, String title) {
    if (!(url.startsWith('http://') || url.startsWith('https://'))) return;
    final now = DateTime.now();

    // Тот же адрес уже есть — поднимаем наверх.
    final i = _items.indexWhere((e) => e.url == url);
    if (i >= 0) {
      final e = _items.removeAt(i);
      e.time = now;
      if (title.trim().isNotEmpty) e.title = title.trim();
      _items.insert(0, e);
    } else {
      _items.insert(0, HistoryEntry(url: url, title: title.trim(), time: now));
      if (_items.length > _maxItems) _items.removeRange(_maxItems, _items.length);
    }
    notifyListeners();
    _scheduleSave();
  }

  void updateTitle(String url, String title) {
    final t = title.trim();
    if (t.isEmpty) return;
    for (final e in _items) {
      if (e.url == url) {
        if (e.title != t) {
          e.title = t;
          notifyListeners();
          _scheduleSave();
        }
        return;
      }
    }
  }

  // ---------- удаление ----------

  void remove(HistoryEntry e) {
    _items.remove(e);
    notifyListeners();
    _scheduleSave();
  }

  /// Очистка: за последний [period] или полностью, если период не указан.
  void clear({Duration? period}) {
    if (period == null) {
      _items.clear();
    } else {
      final from = DateTime.now().subtract(period);
      _items.removeWhere((e) => e.time.isAfter(from));
    }
    notifyListeners();
    _scheduleSave();
  }

  // ---------- поиск для подсказок ----------

  List<HistoryEntry> search(String query, {int limit = 3}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final out = <HistoryEntry>[];
    for (final e in _items) {
      final host = (Uri.tryParse(e.url)?.host ?? '').toLowerCase();
      if (e.title.toLowerCase().contains(q) || host.contains(q) ||
          e.url.toLowerCase().contains(q)) {
        out.add(e);
        if (out.length >= limit) break;
      }
    }
    return out;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app_settings.dart';

class Shortcut {
  Shortcut({
    required this.id,
    required this.label,
    required this.url,
    this.iconKey,
    this.iconUrl,
    this.color = const Color(0xFFE7EAEE),
  });

  final int id;
  final String label;
  final String url;

  /// Ключ встроенной иконки. null — вместо иконки показывается первая буква названия.
  final String? iconKey;

  /// Настоящая иконка сайта (адрес картинки), если удалось её получить.
  final String? iconUrl;
  final Color color;

  IconData? get icon => ShortcutsController.icons[iconKey];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'url': url,
        'icon': iconKey,
        'iconUrl': iconUrl,
        'color': color.toARGB32(),
      };
}

/// Ярлыки на стартовой странице. Сохраняются в %APPDATA%\ZemboBrowser\shortcuts.json.
class ShortcutsController extends ChangeNotifier {
  ShortcutsController({this.fileName = 'shortcuts.json', bool defaults = true}) {
    if (defaults) _loadDefaults();
  }

  ShortcutsController._loaded(List<Shortcut> items, this.fileName) {
    _items.addAll(items);
    _nextId = items.fold<int>(-1, (m, s) => s.id > m ? s.id : m) + 1;
  }

  static const icons = <String, IconData>{
    'youtube': Icons.smart_display,
    'discord': Icons.gamepad,
    'github': Icons.code,
    'reddit': Icons.forum,
    'wikipedia': Icons.menu_book,
  };

  /// Имя файла в %APPDATA%\\ZemboBrowser (у меню «Мои сайты» свой файл).
  final String fileName;
  final List<Shortcut> _items = [];
  int _nextId = 0;

  List<Shortcut> get items => List.unmodifiable(_items);

  void _loadDefaults() {
    _add('YouTube', 'https://youtube.com', 'youtube', const Color(0xFFFF1717));
    _add('Discord', 'https://discord.com', 'discord', const Color(0xFF7289DA));
    _add('GitHub', 'https://github.com', 'github', const Color(0xFFE7EAEE));
    _add('Reddit', 'https://reddit.com', 'reddit', const Color(0xFFFF5418));
    _add('Wikipedia', 'https://wikipedia.org', 'wikipedia', const Color(0xFFE7EAEE));
  }

  void _add(String label, String url, String? iconKey, Color color,
      {String? iconUrl}) {
    _items.add(Shortcut(
        id: _nextId++,
        label: label,
        url: url,
        iconKey: iconKey,
        iconUrl: iconUrl,
        color: color));
  }

  // ---------- хранение ----------

  static File _fileFor(String name) =>
      File('${AppSettings.dataDir.path}${Platform.pathSeparator}$name');

  /// Читает ярлыки с диска. Если файла нет — стандартный набор.
  static Future<ShortcutsController> load(
      {String fileName = 'shortcuts.json', bool defaults = true}) async {
    try {
      final f = _fileFor(fileName);
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is List) {
          final items = <Shortcut>[];
          for (final e in data) {
            if (e is! Map) continue;
            final id = e['id'];
            final label = e['label'];
            final url = e['url'];
            if (id is! int || label is! String || url is! String) continue;
            final key = e['icon'];
            final color = e['color'];
            final iconUrl = e['iconUrl'];
            items.add(Shortcut(
              id: id,
              label: label,
              url: url,
              iconKey: key is String && icons.containsKey(key) ? key : null,
              iconUrl: iconUrl is String && iconUrl.isNotEmpty ? iconUrl : null,
              color: color is int ? Color(color) : const Color(0xFFE7EAEE),
            ));
          }
          return ShortcutsController._loaded(items, fileName);
        }
      }
    } catch (_) {
      // Битый файл — используем стандартный набор.
    }
    return ShortcutsController(fileName: fileName, defaults: defaults);
  }

  Future<void> _save() async {
    try {
      await AppSettings.dataDir.create(recursive: true);
      await _fileFor(fileName)
          .writeAsString(jsonEncode(_items.map((s) => s.toJson()).toList()));
    } catch (_) {}
  }

  // ---------- изменения ----------

  /// Добавляет ярлык. Пустое название берётся из адреса.
  void add({required String label, required String url, String? iconUrl}) {
    var u = url.trim();
    if (u.isEmpty) return;
    if (!u.contains('://')) u = 'https://$u';

    var name = label.trim();
    if (name.isEmpty) {
      name = (Uri.tryParse(u)?.host ?? u).replaceFirst('www.', '');
    }
    _add(name, u, null, const Color(0xFFE7EAEE), iconUrl: iconUrl);
    notifyListeners();
    _save();
  }

  static String _key(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return url.toLowerCase();
    var path = u.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '${u.host.replaceFirst('www.', '').toLowerCase()}$path';
  }

  bool containsUrl(String url) => _items.any((s) => _key(s.url) == _key(url));

  void removeByUrl(String url) {
    _items.removeWhere((s) => _key(s.url) == _key(url));
    notifyListeners();
    _save();
  }

  void remove(int id) {
    _items.removeWhere((s) => s.id == id);
    notifyListeners();
    _save();
  }
}

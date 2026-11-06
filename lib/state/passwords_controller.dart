import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'secret_store.dart';

/// Что делать с логином, который ввёл пользователь.
enum SaveKind { none, add, update }

/// Сохранённый логин. Пароль хранится только в зашифрованном виде (DPAPI).
class SavedLogin {
  SavedLogin({
    required this.id,
    required this.host,
    required this.username,
    required this.encPassword,
    required this.created,
  });

  final String id;
  final String host;
  String username;
  String encPassword;
  final int created;

  Map<String, dynamic> toJson() => {
        'id': id,
        'host': host,
        'user': username,
        'pass': encPassword,
        't': created,
      };
}

/// Менеджер паролей. Хранится в %APPDATA%\ZemboBrowser\passwords.json,
/// сами пароли зашифрованы средствами Windows и открываются только в этой
/// учётной записи Windows.
class PasswordsController extends ChangeNotifier {
  PasswordsController(this.settings);

  final AppSettings settings;
  final List<SavedLogin> _items = [];
  final Set<String> _never = {};
  bool _disposed = false;
  int _counter = 0;

  List<SavedLogin> get items {
    final list = List<SavedLogin>.of(_items);
    list.sort((a, b) {
      final c = a.host.compareTo(b.host);
      return c != 0 ? c : a.username.compareTo(b.username);
    });
    return list;
  }

  List<String> get neverHosts => (_never.toList()..sort());
  int get count => _items.length;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Сайт без «www.» и в нижнем регистре — по нему ищутся пароли.
  static String hostKey(String host) =>
      host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

  static File get _file => File(
      '${AppSettings.dataDir.path}${Platform.pathSeparator}passwords.json');

  Future<void> init() async {
    try {
      final f = _file;
      if (!await f.exists()) return;
      final map = jsonDecode(await f.readAsString());
      if (map is! Map) return;
      final list = map['items'];
      if (list is List) {
        for (final e in list) {
          if (e is! Map) continue;
          final id = e['id'];
          final host = e['host'];
          final user = e['user'];
          final pass = e['pass'];
          if (id is String && host is String && user is String && pass is String) {
            _items.add(SavedLogin(
              id: id,
              host: host,
              username: user,
              encPassword: pass,
              created: (e['t'] as num?)?.toInt() ?? 0,
            ));
          }
        }
      }
      final never = map['never'];
      if (never is List) _never.addAll(never.whereType<String>());
      notifyListeners();
    } catch (_) {
      // Битый файл — начинаем с пустого списка.
    }
  }

  Future<void> _save() async {
    try {
      await AppSettings.dataDir.create(recursive: true);
      await _file.writeAsString(jsonEncode({
        'items': [for (final i in _items) i.toJson()],
        'never': _never.toList(),
      }));
    } catch (_) {}
  }

  List<SavedLogin> forHost(String host) {
    final k = hostKey(host);
    if (k.isEmpty) return const [];
    return [
      for (final i in items)
        if (i.host == k) i,
    ];
  }

  bool hasForHost(String host) {
    final k = hostKey(host);
    return k.isNotEmpty && _items.any((i) => i.host == k);
  }

  bool isNever(String host) => _never.contains(hostKey(host));

  SavedLogin? _find(String host, String username) {
    final k = hostKey(host);
    for (final i in _items) {
      if (i.host == k && i.username == username) return i;
    }
    return null;
  }

  /// Нужно ли предлагать сохранение: новый логин, изменённый пароль или ничего.
  Future<SaveKind> classify(String host, String username, String password) async {
    final existing = _find(host, username);
    if (existing == null) return SaveKind.add;
    try {
      final old = await SecretStore.unprotect(existing.encPassword);
      return old == password ? SaveKind.none : SaveKind.update;
    } catch (_) {
      return SaveKind.update;
    }
  }

  /// Сохраняет (или обновляет) пароль. false — не удалось зашифровать.
  Future<bool> save(String host, String username, String password) async {
    final k = hostKey(host);
    if (k.isEmpty || password.isEmpty) return false;
    String enc;
    try {
      enc = await SecretStore.protect(password);
    } catch (_) {
      return false;
    }
    final existing = _find(k, username);
    if (existing != null) {
      existing.encPassword = enc;
    } else {
      _items.add(SavedLogin(
        id: '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_counter++}',
        host: k,
        username: username,
        encPassword: enc,
        created: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    notifyListeners();
    await _save();
    return true;
  }

  /// Расшифровывает пароль. null — не получилось.
  Future<String?> reveal(String id) async {
    for (final i in _items) {
      if (i.id == id) {
        try {
          return await SecretStore.unprotect(i.encPassword);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  void delete(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    _save();
  }

  void deleteAll() {
    _items.clear();
    notifyListeners();
    _save();
  }

  void addNever(String host) {
    final k = hostKey(host);
    if (k.isEmpty) return;
    _never.add(k);
    notifyListeners();
    _save();
  }

  void removeNever(String host) {
    _never.remove(hostKey(host));
    notifyListeners();
    _save();
  }
}

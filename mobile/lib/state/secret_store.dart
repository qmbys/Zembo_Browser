import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Защищённое хранение паролей: значения лежат в хранилище Android (Keystore),
/// в файле паролей остаётся только ссылка на запись.
class SecretStore {
  SecretStore._();

  static const _storage = FlutterSecureStorage();
  static final _rng = Random.secure();

  static String _newRef() {
    final b = List<int>.generate(16, (_) => _rng.nextInt(256));
    return 'zpw_${b.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Сохраняет секрет и возвращает ссылку на него.
  static Future<String> protect(String plain) async {
    final ref = _newRef();
    await _storage.write(key: ref, value: plain);
    return ref;
  }

  static Future<String> unprotect(String ref) async {
    final v = await _storage.read(key: ref);
    if (v == null) throw StateError('Секрет не найден');
    return v;
  }

  static Future<void> remove(String ref) async {
    try {
      await _storage.delete(key: ref);
    } catch (_) {}
  }
}

import 'package:flutter/foundation.dart';

/// Ошибки приложения: показываются поверх экрана панелью с кнопкой «Скопировать».
/// Нужна, чтобы искать ошибки на телефоне без консоли.
class ErrorLog {
  static final ValueNotifier<List<String>> items = ValueNotifier(const []);

  static void add(String text) {
    // Держим первые 3 ошибки: дальше обычно идут лишь следствия первой.
    if (items.value.length >= 3) return;
    final t = text.length > 5000 ? text.substring(0, 5000) : text;
    items.value = [...items.value, t];
  }

  static void clear() => items.value = const [];
}

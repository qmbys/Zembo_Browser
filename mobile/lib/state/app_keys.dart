import 'package:flutter/material.dart';

import '../i18n/i18n_core.dart';

/// Ключ, чтобы показывать уведомления (SnackBar) из любого места приложения.
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void toast(String text) {
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(tr(text)),
    // Над нижней панелью браузера.
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 72),
  ));
}

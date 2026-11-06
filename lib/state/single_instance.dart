import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

/// Один запущенный браузер. Когда Windows открывает ссылку в браузере по
/// умолчанию, новый процесс передаёт адрес уже работающему и закрывается.
/// Обмен идёт по локальному порту 127.0.0.1 (наружу не виден).
class SingleInstance {
  SingleInstance._();

  static const int port = 47619;
  static final StreamController<String> _urls = StreamController<String>.broadcast();
  static final List<String> _pending = [];

  /// Адреса, которые просят открыть (после того как главное окно запущено).
  static Stream<String> get urls => _urls.stream;

  /// Адреса, пришедшие до того, как окно начало слушать.
  static List<String> takePending() {
    final list = List<String>.of(_pending);
    _pending.clear();
    return list;
  }

  static bool _allowed(String u) {
    final l = u.toLowerCase();
    return l.startsWith('http://') || l.startsWith('https://') || l.startsWith('file://');
  }

  /// Адреса из аргументов командной строки: ссылки и локальные html-файлы.
  static List<String> urlsFromArgs(List<String> args) {
    final out = <String>[];
    for (final a in args) {
      if (a.isEmpty || a.startsWith('--')) continue;
      if (_allowed(a)) {
        out.add(a);
        continue;
      }
      final lower = a.toLowerCase();
      if ((lower.endsWith('.html') ||
              lower.endsWith('.htm') ||
              lower.endsWith('.xhtml') ||
              lower.endsWith('.shtml')) &&
          File(a).existsSync()) {
        out.add(Uri.file(a).toString());
      }
    }
    return out;
  }

  /// Если браузер уже запущен — отдаёт ему адреса (или просто выводит окно) и
  /// возвращает true: тогда этот процесс можно закрыть.
  static Future<bool> forwardToRunning(List<String> urls) async {
    Socket? s;
    try {
      s = await Socket.connect(InternetAddress.loopbackIPv4, port,
          timeout: const Duration(milliseconds: 500));
      final hello = Completer<String>();
      s.cast<List<int>>().transform(utf8.decoder).listen(
        (d) {
          if (!hello.isCompleted) hello.complete(d);
        },
        onError: (_) {
          if (!hello.isCompleted) hello.complete('');
        },
        onDone: () {
          if (!hello.isCompleted) hello.complete('');
        },
      );
      final greeting =
          await hello.future.timeout(const Duration(milliseconds: 700), onTimeout: () => '');
      // Отвечает именно Zembo Browser, а не случайная программа на этом порту.
      if (!greeting.startsWith('ZEMBO')) {
        s.destroy();
        return false;
      }
      s.write(urls.isEmpty ? 'FOCUS\n' : urls.map((u) => 'OPEN $u\n').join());
      await s.flush();
      await s.close();
      return true;
    } catch (_) {
      s?.destroy();
      return false;
    }
  }

  /// Запускает приём адресов от других процессов; [initial] — адреса из запуска.
  static Future<void> start(List<String> initial) async {
    _pending.addAll(initial.where(_allowed));
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      server.listen(_onClient, onError: (_) {});
    } catch (_) {
      // Порт занят (например, при горячей перезагрузке) — работаем без этого.
    }
  }

  static void _onClient(Socket sock) {
    try {
      sock.write('ZEMBO\n');
    } catch (_) {}
    sock.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        if (line.startsWith('OPEN ')) {
          _emit(line.substring(5).trim());
        } else if (line.trim() == 'FOCUS') {
          _focus();
        }
      },
      onError: (_) => sock.destroy(),
      onDone: sock.destroy,
    );
  }

  static void _emit(String url) {
    if (!_allowed(url)) return;
    if (_urls.hasListener) {
      _urls.add(url);
    } else {
      _pending.add(url);
    }
    _focus();
  }

  static void _focus() {
    () async {
      try {
        if (await windowManager.isMinimized()) await windowManager.restore();
        await windowManager.show();
        await windowManager.focus();
      } catch (_) {}
    }();
  }
}

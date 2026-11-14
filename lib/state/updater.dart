import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../app_version.dart';

enum UpdatePhase { idle, available, downloading, ready, error }

/// Автообновление: при запуске смотрит последний релиз на GitHub, скачивает
/// установщик Inno Setup и запускает его в тихом режиме (без окон).
class UpdateController extends ChangeNotifier {
  static const _owner = 'qmbys';
  static const _repo = 'Zembo_Browser';
  static const _api =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  UpdatePhase phase = UpdatePhase.idle;
  String newVersion = '';
  String? error;
  int received = 0;
  int total = 0;
  double get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

  String _url = '';
  String _sha256 = '';
  File? _file;
  bool _disposed = false;
  HttpClient? _client;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _disposed = true;
    _client?.close(force: true);
    super.dispose();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  // ---------- проверка ----------

  /// Вызывается один раз при запуске. Ошибки сети молча игнорируются.
  Future<void> checkOnStart() async {
    if (!Platform.isWindows) return;
    await Future<void>.delayed(const Duration(seconds: 2));
    try {
      await _cleanOld();
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      c.userAgent = 'ZemboBrowser/$kAppVersion';
      try {
        final req = await c.getUrl(Uri.parse(_api));
        req.headers.set('accept', 'application/vnd.github+json');
        final res = await req.close().timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) {
          await res.drain<void>();
          return;
        }
        final body = await res.transform(utf8.decoder).join();
        final j = jsonDecode(body);
        if (j is! Map || j['draft'] == true || j['prerelease'] == true) return;

        final ver = _cleanVersion('${j['tag_name'] ?? ''}');
        if (ver.isEmpty || compareVersions(ver, kAppVersion) <= 0) return;

        // Ищем установщик среди файлов релиза.
        Map? pick;
        final assets = j['assets'];
        if (assets is List) {
          for (final a in assets) {
            if (a is! Map) continue;
            final name = '${a['name'] ?? ''}'.toLowerCase();
            if (!name.endsWith('.exe')) continue;
            if (name.contains('setup')) {
              pick = a;
              break;
            }
            pick ??= a;
          }
        }
        if (pick == null) return;
        final url = '${pick['browser_download_url'] ?? ''}';
        if (!_trustedUrl(url)) return;

        _url = url;
        newVersion = ver;
        total = (pick['size'] is int) ? pick['size'] as int : 0;
        final digest = '${pick['digest'] ?? ''}';
        _sha256 = digest.startsWith('sha256:')
            ? digest.substring(7).toLowerCase()
            : '';
        phase = UpdatePhase.available;
        _emit();
      } finally {
        c.close(force: true);
      }
    } catch (_) {}
  }

  /// «Обновить позже»: окно закрывается, при следующем запуске появится снова.
  void later() {
    phase = UpdatePhase.idle;
    _emit();
  }

  // ---------- скачивание ----------

  Future<void> start() async {
    if (phase == UpdatePhase.downloading) return;
    phase = UpdatePhase.downloading;
    error = null;
    received = 0;
    _emit();
    try {
      final dir = _dir;
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}'
          'ZemboBrowser-Setup-$newVersion.exe');
      if (await file.exists()) await file.delete();

      final c = _client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      c.userAgent = 'ZemboBrowser/$kAppVersion';
      final req = await c.getUrl(Uri.parse(_url));
      final res = await req.close();
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw HttpException('HTTP ${res.statusCode}');
      }
      if (res.contentLength > 0) total = res.contentLength;

      final sink = file.openWrite();
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          received += chunk.length;
          final now = DateTime.now();
          if (now.difference(_lastNotify).inMilliseconds > 80) {
            _lastNotify = now;
            _emit();
          }
        }
      } finally {
        await sink.close();
      }
      c.close();
      _client = null;

      if (total > 0 && received != total) {
        throw const HttpException('incomplete');
      }
      // Установщик будет запущен, поэтому сверяем контрольную сумму, если она есть.
      if (_sha256.isNotEmpty) {
        final d = await sha256.bind(file.openRead()).first;
        if (d.toString().toLowerCase() != _sha256) {
          await file.delete();
          throw const HttpException('checksum');
        }
      }
      _file = file;
      received = total > 0 ? total : received;
      phase = UpdatePhase.ready;
      _emit();
    } catch (e) {
      if (_disposed) return;
      error = e is SocketException || e is TimeoutException
          ? 'Нет соединения с интернетом'
          : 'Не удалось скачать обновление';
      phase = UpdatePhase.error;
      _emit();
    }
  }

  // ---------- установка ----------

  /// Тихо запускает установщик и закрывает браузер. Установщик сам заменит файлы
  /// и снова откроет Zembo Browser (параметр /UPDATE=1).
  Future<void> restart() async {
    final f = _file;
    if (f == null || !await f.exists()) {
      error = 'Файл обновления не найден';
      phase = UpdatePhase.error;
      _emit();
      return;
    }
    try {
      await Process.start(
        f.path,
        const [
          '/VERYSILENT',
          '/SUPPRESSMSGBOXES',
          '/NORESTART',
          '/SP-',
          '/CLOSEAPPLICATIONS',
          '/UPDATE=1',
        ],
        mode: ProcessStartMode.detached,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      exit(0);
    } catch (_) {
      error = 'Не удалось запустить установщик';
      phase = UpdatePhase.error;
      _emit();
    }
  }

  // ---------- вспомогательное ----------

  Directory get _dir => Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}ZemboBrowserUpdate');

  /// Убираем скачанные ранее установщики.
  Future<void> _cleanOld() async {
    try {
      final d = _dir;
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }

  /// Скачиваем только с GitHub по https.
  static bool _trustedUrl(String u) {
    final uri = Uri.tryParse(u);
    if (uri == null || uri.scheme != 'https') return false;
    final h = uri.host.toLowerCase();
    return h == 'github.com' || h.endsWith('.githubusercontent.com');
  }

  static String _cleanVersion(String tag) {
    final m = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(tag);
    return m?.group(1) ?? '';
  }

  /// 1: a новее b, 0: одинаковые, -1: a старее b.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    final x = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final y = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final n = x.length > y.length ? x.length : y.length;
    for (var i = 0; i < n; i++) {
      final p = i < x.length ? x[i] : 0;
      final q = i < y.length ? y[i] : 0;
      if (p != q) return p > q ? 1 : -1;
    }
    return 0;
  }
}

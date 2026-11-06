import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../i18n/i18n_core.dart';

import 'app_settings.dart';

enum DownloadStatus { inProgress, completed, failed, cancelled }

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.path,
    this.pageUrl,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final int id;
  final String url;
  String fileName;
  String path;

  /// Страница, с которой скачали файл (для повторной загрузки).
  String? pageUrl;
  final DateTime time;

  /// Файла больше нет на диске (удалён или перемещён).
  bool missing = false;
  int received = 0;
  int? total;
  DownloadStatus status = DownloadStatus.inProgress;
  bool cancelRequested = false;
  HttpClient? client;

  /// Загрузка идёт внутри WebView: следим за временным файлом в «Загрузках».
  bool external = false;
  String? tempPath;
  DateTime? lastSeen;

  /// Скорость, байт в секунду (сглаженная).
  double speed = 0;
  int _lastBytes = 0;
  DateTime? _lastTime;

  /// Обновляет скорость; вызывать при изменении [received].
  void sample() {
    final now = DateTime.now();
    final t = _lastTime;
    if (t == null) {
      _lastTime = now;
      _lastBytes = received;
      return;
    }
    final dt = now.difference(t).inMilliseconds;
    if (dt < 400) return;
    final inst = (received - _lastBytes) * 1000 / dt;
    speed = speed == 0 ? inst : speed * 0.6 + inst * 0.4;
    if (speed < 0) speed = 0;
    _lastBytes = received;
    _lastTime = now;
  }

  /// Сколько осталось, если известен размер.
  Duration? get eta {
    final t = total;
    if (t == null || t <= received || speed < 1) return null;
    return Duration(seconds: ((t - received) / speed).ceil());
  }

  double? get progress {
    final t = total;
    if (t == null || t <= 0) return null;
    return (received / t).clamp(0.0, 1.0).toDouble();
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'page': pageUrl,
        'name': fileName,
        'path': path,
        'size': total ?? received,
        'status': status.index,
        't': time.millisecondsSinceEpoch,
      };
}

/// Загрузки файлов в папку «Загрузки».
class DownloadsController extends ChangeNotifier {
  final List<DownloadItem> _items = [];
  int _nextId = 0;
  bool _disposed = false;
  final List<DateTime> _recentStarts = [];

  /// Вызывается, когда началась новая загрузка (чтобы показать панель).
  VoidCallback? onStarted;

  /// Открыть страницу в новой вкладке (повторная загрузка с сайта).
  void Function(String url)? onOpenPage;

  /// Адрес страницы в активной вкладке.
  String? Function()? currentPage;

  // ---------- сохранение списка ----------

  Timer? _saveTimer;
  StreamSubscription<FileSystemEvent>? _watch;
  DateTime _armedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<String> _watching = {};

  static File get _file => File(
      '${AppSettings.dataDir.path}${Platform.pathSeparator}downloads.json');

  /// Загружает сохранённый список и начинает следить за папкой «Загрузки».
  Future<void> init() async {
    try {
      final f = _file;
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is List) {
          for (final e in data) {
            if (e is! Map) continue;
            final path = e['path'];
            final name = e['name'];
            if (path is! String || name is! String) continue;
            final st = e['status'];
            final status = (st is int && st >= 0 && st < DownloadStatus.values.length)
                ? DownloadStatus.values[st]
                : DownloadStatus.completed;
            if (status == DownloadStatus.inProgress) continue;
            final t = e['t'];
            final item = DownloadItem(
              id: _nextId++,
              url: e['url'] is String ? e['url'] as String : '',
              fileName: name,
              path: path,
              pageUrl: e['page'] is String ? e['page'] as String : null,
              time: t is int ? DateTime.fromMillisecondsSinceEpoch(t) : null,
            );
            final size = e['size'];
            if (size is int) {
              item.received = size;
              item.total = size;
            }
            item.status = status;
            _items.add(item);
          }
        }
      }
    } catch (_) {
      // Битый файл — начинаем с пустого списка.
    }
    notifyListeners();
    await refreshMissing();
    _startWatching();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    try {
      await AppSettings.dataDir.create(recursive: true);
      await _file.writeAsString(jsonEncode([
        for (final d in _items)
          if (d.status != DownloadStatus.inProgress) d.toJson()
      ]));
    } catch (_) {}
  }

  /// Проверяет, остались ли файлы на диске.
  Future<void> refreshMissing() async {
    var changed = false;
    for (final d in List.of(_items)) {
      if (d.status != DownloadStatus.completed) continue;
      bool exists;
      try {
        exists = await File(d.path).exists();
      } catch (_) {
        exists = false;
      }
      if (d.missing == exists) {
        d.missing = !exists;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  // ---------- загрузки, которые сделал сам браузер (WebView) ----------

  /// Браузер что-то загружает или пользователь кликнул на странице:
  /// ближайшие 30 секунд новые файлы в «Загрузках» считаем загрузкой из браузера.
  void noteWebActivity() {
    final until = DateTime.now().add(const Duration(seconds: 30));
    if (until.isAfter(_armedUntil)) _armedUntil = until;
  }

  static const _tempExt = {
    '.crdownload', '.partial', '.tmp', '.download', '.part', '.opdownload'
  };

  void _startWatching() {
    if (_watch != null) return;
    try {
      final dir = Directory(downloadsDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _watch = dir
          .watch(
              events: FileSystemEvent.create |
                  FileSystemEvent.modify |
                  FileSystemEvent.move)
          .listen(_onFsEvent, onError: (_) {});
    } catch (_) {}
  }

  static bool _same(String a, String b) => a.toLowerCase() == b.toLowerCase();

  void _onFsEvent(FileSystemEvent e) {
    if (e.isDirectory) return;
    var path = e.path;
    if (e is FileSystemMoveEvent && e.destination != null) path = e.destination!;

    final name = path.split(Platform.pathSeparator).last.toLowerCase();
    if (name == 'desktop.ini') return;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot) : '';

    final now = DateTime.now();
    if (_tempExt.contains(ext)) {
      // Началась загрузка из браузера: даём время дождаться конца.
      if (now.isBefore(_armedUntil)) {
        _armedUntil = now.add(const Duration(minutes: 30));
        _trackTemp(path);
      }
      return;
    }
    if (now.isAfter(_armedUntil)) return;
    if (_items.any((d) => _same(d.path, path))) return;
    if (_watching.contains(path.toLowerCase())) return;
    _watching.add(path.toLowerCase());
    _registerExternal(path);
  }

  // ---------- загрузки WebView: показываем ход по временному файлу ----------

  Timer? _extTimer;

  void _trackTemp(String tempPath) {
    if (_items.any((d) => d.external && _same(d.tempPath ?? '', tempPath))) {
      return;
    }
    final raw = tempPath.split(Platform.pathSeparator).last;
    final dot = raw.lastIndexOf('.');
    var name = dot > 0 ? raw.substring(0, dot) : raw;
    if (name.toLowerCase().startsWith('unconfirmed')) name = 'Файл из браузера';
    final item = DownloadItem(
      id: _nextId++,
      url: '',
      fileName: name,
      path: tempPath,
      pageUrl: currentPage?.call(),
    );
    item.external = true;
    item.tempPath = tempPath;
    item.lastSeen = DateTime.now();
    _items.add(item);
    notifyListeners();
    onStarted?.call();
    _extTimer ??= Timer.periodic(const Duration(milliseconds: 500), (_) => _pollExternal());
  }

  Future<void> _pollExternal() async {
    final active = _items
        .where((d) => d.external && d.status == DownloadStatus.inProgress)
        .toList();
    if (active.isEmpty) {
      _extTimer?.cancel();
      _extTimer = null;
      return;
    }
    final now = DateTime.now();
    for (final d in active) {
      try {
        final f = File(d.tempPath!);
        if (await f.exists()) {
          d.received = await f.length();
          d.lastSeen = now;
          d.sample();
        } else if (now.difference(d.lastSeen ?? d.time).inSeconds > 8) {
          // Временный файл пропал, а готового так и не появилось.
          d.status = DownloadStatus.cancelled;
          d.speed = 0;
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Общая строка про загрузки в процессе (для подсказки у значка).
  String? get activeSummary {
    final act = _items.where((d) => d.status == DownloadStatus.inProgress).toList();
    if (act.isEmpty) return null;
    var speed = 0.0;
    var got = 0, all = 0;
    var allKnown = true;
    for (final d in act) {
      speed += d.speed;
      got += d.received;
      final t = d.total;
      if (t == null || t <= 0) {
        allKnown = false;
      } else {
        all += t;
      }
    }
    final parts = <String>[
      allKnown && all > 0 ? 'Загрузка: ${(got * 100 / all).floor()}%' : 'Загрузка…',
      if (speed > 0) formatSpeed(speed),
    ];
    return parts.join(' · ');
  }

  // ---------- форматирование ----------

  static String formatBytes(num bytes) {
    final units = [tr('Б'), tr('КБ'), tr('МБ'), tr('ГБ')];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  static String formatSpeed(double bytesPerSecond) =>
      '${formatBytes(bytesPerSecond)}${tr('/с')}';

  static String formatEta(Duration d) {
    final s = d.inSeconds;
    final sec = tr('с'), min = tr('мин'), hour = tr('ч');
    if (s < 60) return '$s $sec';
    if (s < 3600) return '${s ~/ 60} $min ${(s % 60).toString().padLeft(2, '0')} $sec';
    return '${s ~/ 3600} $hour ${((s % 3600) ~/ 60).toString().padLeft(2, '0')} $min';
  }

  Future<void> _registerExternal(String path) async {
    try {
      final f = File(path);
      // Ждём, пока размер файла перестанет меняться.
      var last = -1;
      var stable = 0;
      for (var i = 0; i < 300 && stable < 2; i++) {
        if (!await f.exists()) return;
        final len = await f.length();
        stable = (len == last && len > 0) ? stable + 1 : 0;
        last = len;
        if (stable < 2) await Future.delayed(const Duration(milliseconds: 700));
      }
      if (stable < 2) return;
      if (_items.any((d) => _same(d.path, path))) return;

      // Файл дозагрузился: превращаем отслеживаемую загрузку в готовую.
      DownloadItem? tracked;
      for (final d in _items) {
        if (d.external && d.status == DownloadStatus.inProgress) {
          tracked = d;
          break;
        }
      }
      if (tracked != null) {
        tracked.fileName = path.split(Platform.pathSeparator).last;
        tracked.path = path;
        tracked.received = last;
        tracked.total = last;
        tracked.speed = 0;
        tracked.status = DownloadStatus.completed;
        notifyListeners();
        _scheduleSave();
        return;
      }

      final item = DownloadItem(
        id: _nextId++,
        url: '',
        fileName: path.split(Platform.pathSeparator).last,
        path: path,
        pageUrl: currentPage?.call(),
      );
      item.received = last;
      item.total = last;
      item.status = DownloadStatus.completed;
      _items.add(item);
      notifyListeners();
      _scheduleSave();
      onStarted?.call();
    } catch (_) {
    } finally {
      _watching.remove(path.toLowerCase());
    }
  }

  List<DownloadItem> get items => List.unmodifiable(_items.reversed);
  bool get hasActive =>
      _items.any((d) => d.status == DownloadStatus.inProgress);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _extTimer?.cancel();
    _watch?.cancel();
    try {
      AppSettings.dataDir.createSync(recursive: true);
      _file.writeAsStringSync(jsonEncode([
        for (final d in _items)
          if (d.status != DownloadStatus.inProgress) d.toJson()
      ]));
    } catch (_) {}
    for (final d in _items) {
      d.client?.close(force: true);
    }
    super.dispose();
  }

  static String get downloadsDir {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    return '$home${Platform.pathSeparator}Downloads';
  }

  // ---------- запуск ----------

  /// Не даём странице засыпать пользователя загрузками.
  bool _allowNew() {
    final now = DateTime.now();
    _recentStarts.removeWhere((t) => now.difference(t).inSeconds > 5);
    if (_recentStarts.length >= 3) return false;
    _recentStarts.add(now);
    return true;
  }

  Future<void> start(String url, {String? suggestedName, String? referer}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return;
    if (!_allowNew()) return;

    await Directory(downloadsDir).create(recursive: true);

    var name = _sanitize(suggestedName ?? '');
    if (name.isEmpty) {
      name = _sanitize(
          uri.pathSegments.isNotEmpty ? Uri.decodeComponent(uri.pathSegments.last) : '');
    }
    if (name.isEmpty) name = 'download';

    final item = DownloadItem(
      id: _nextId++,
      url: url,
      fileName: name,
      path: await _uniquePath(name),
      pageUrl: referer,
    );
    _items.add(item);
    notifyListeners();
    onStarted?.call();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
    item.client = client;

    IOSink? sink;
    try {
      final req = await client.getUrl(uri);
      if (referer != null && referer.isNotEmpty) {
        req.headers.set(HttpHeaders.refererHeader, referer);
      }
      final res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('HTTP ${res.statusCode}');
      }

      item.total = res.contentLength > 0 ? res.contentLength : null;

      // Имя файла из заголовка Content-Disposition, если сервер его прислал.
      final cdName = _nameFromDisposition(
          res.headers.value('content-disposition'));
      if (cdName != null && cdName.isNotEmpty && suggestedName == null) {
        item.fileName = cdName;
        item.path = await _uniquePath(cdName);
      }

      final file = File(item.path);
      sink = file.openWrite();
      var lastNotify = DateTime.now();

      await for (final chunk in res) {
        if (item.cancelRequested) break;
        sink.add(chunk);
        item.received += chunk.length;
        item.sample();
        final now = DateTime.now();
        if (now.difference(lastNotify).inMilliseconds > 150) {
          lastNotify = now;
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      item.speed = 0;
      if (item.cancelRequested) {
        item.status = DownloadStatus.cancelled;
        await _deleteQuietly(item.path);
      } else {
        item.status = DownloadStatus.completed;
        item.total ??= item.received;
      }
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      item.status = item.cancelRequested
          ? DownloadStatus.cancelled
          : DownloadStatus.failed;
      await _deleteQuietly(item.path);
    } finally {
      client.close(force: true);
      item.client = null;
      notifyListeners();
      _scheduleSave();
    }
  }

  /// Файл, который страница сформировала сама (blob/data) и передала в base64.
  Future<void> saveData(String name, String base64Data) async {
    if (!_allowNew()) return;
    try {
      final bytes = base64Decode(base64Data);
      await Directory(downloadsDir).create(recursive: true);
      final fileName = _sanitize(name).isEmpty ? 'download' : _sanitize(name);
      final item = DownloadItem(
        id: _nextId++,
        url: 'blob:',
        fileName: fileName,
        path: await _uniquePath(fileName),
        pageUrl: currentPage?.call(),
      );
      _items.add(item);
      await File(item.path).writeAsBytes(bytes);
      item.received = bytes.length;
      item.total = bytes.length;
      item.status = DownloadStatus.completed;
      notifyListeners();
      _scheduleSave();
      onStarted?.call();
    } catch (_) {}
  }

  // ---------- действия ----------

  void cancel(int id) {
    final d = _find(id);
    if (d == null || d.status != DownloadStatus.inProgress) return;
    d.cancelRequested = true;
    d.client?.close(force: true);
  }

  void remove(int id) {
    final d = _find(id);
    if (d == null) return;
    if (d.status == DownloadStatus.inProgress) cancel(id);
    _items.remove(d);
    notifyListeners();
    _scheduleSave();
  }

  void clearFinished() {
    _items.removeWhere((d) => d.status != DownloadStatus.inProgress);
    notifyListeners();
    _scheduleSave();
  }

  /// Корзина: удаляет файл с устройства и запись из списка.
  /// Если файла уже нет — убирает только запись.
  Future<void> deleteFile(int id) async {
    final d = _find(id);
    if (d == null) return;
    if (d.status == DownloadStatus.inProgress) cancel(id);
    try {
      final f = File(d.path);
      if (await f.exists()) await f.delete();
      // Не получилось удалить (файл занят) — запись оставляем.
      if (await f.exists()) return;
    } catch (_) {
      try {
        if (await File(d.path).exists()) return;
      } catch (_) {
        return;
      }
    }
    _items.remove(d);
    notifyListeners();
    _scheduleSave();
  }

  /// Повторная загрузка: по прямой ссылке или через страницу, откуда скачали.
  Future<void> redownload(int id) async {
    final d = _find(id);
    if (d == null) return;
    final uri = Uri.tryParse(d.url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final name = d.fileName;
      final ref = d.pageUrl;
      _items.remove(d);
      notifyListeners();
      await start(d.url, suggestedName: name, referer: ref);
      return;
    }
    final page = d.pageUrl;
    if (page != null && page.isNotEmpty) onOpenPage?.call(page);
  }

  /// Можно ли скачать файл снова.
  bool canRedownload(DownloadItem d) {
    final uri = Uri.tryParse(d.url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return true;
    }
    return (d.pageUrl ?? '').isNotEmpty;
  }

  Future<void> openFile(int id) async {
    final d = _find(id);
    if (d == null || d.status != DownloadStatus.completed) return;
    try {
      await Process.run('explorer.exe', [d.path]);
    } catch (_) {}
  }

  Future<void> showInFolder(int id) async {
    final d = _find(id);
    if (d == null) return;
    try {
      await Process.run('explorer.exe', ['/select,', d.path]);
    } catch (_) {}
  }

  Future<void> openDownloadsFolder() async {
    try {
      await Directory(downloadsDir).create(recursive: true);
      await Process.run('explorer.exe', [downloadsDir]);
    } catch (_) {}
  }

  // ---------- вспомогательное ----------

  DownloadItem? _find(int id) {
    for (final d in _items) {
      if (d.id == id) return d;
    }
    return null;
  }

  static String _sanitize(String name) {
    var n = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
    while (n.endsWith('.') || n.endsWith(' ')) {
      n = n.substring(0, n.length - 1);
    }
    if (n.length > 150) n = n.substring(n.length - 150);
    return n;
  }

  static String? _nameFromDisposition(String? header) {
    if (header == null) return null;
    final star = RegExp(r"filename\*\s*=\s*[^']*'[^']*'([^;]+)",
            caseSensitive: false)
        .firstMatch(header);
    if (star != null) {
      try {
        return _sanitize(Uri.decodeComponent(star.group(1)!.trim()));
      } catch (_) {}
    }
    final plain = RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false)
        .firstMatch(header);
    return plain == null ? null : _sanitize(plain.group(1)!.trim());
  }

  Future<String> _uniquePath(String name) async {
    final sep = Platform.pathSeparator;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var candidate = '$downloadsDir$sep$name';
    var n = 1;
    while (await File(candidate).exists() ||
        _items.any((d) => d.path == candidate)) {
      candidate = '$downloadsDir$sep$base ($n)$ext';
      n++;
    }
    return candidate;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

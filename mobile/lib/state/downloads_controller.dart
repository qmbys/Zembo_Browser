import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

import 'app_keys.dart';
import 'app_settings.dart';

enum DlStatus { running, done, failed, canceled }

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.url,
    required this.name,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final String id;
  final String url;
  String name;
  final DateTime time;

  double progress = 0;
  DlStatus status = DlStatus.running;

  /// Путь к файлу в «Загрузках» после завершения.
  String? path;
  String? error;
  DownloadTask? task;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        'time': time.millisecondsSinceEpoch,
        'status': status.name,
        'path': path,
        'error': error,
      };

  static DownloadItem? fromJson(dynamic m) {
    if (m is! Map) return null;
    final id = m['id'], url = m['url'], name = m['name'];
    if (id is! String || url is! String || name is! String) return null;
    final it = DownloadItem(
      id: id,
      url: url,
      name: name,
      time: DateTime.fromMillisecondsSinceEpoch(
          (m['time'] as num?)?.toInt() ?? 0),
    );
    final st = DlStatus.values.asNameMap()[m['status']] ?? DlStatus.failed;
    // Загрузка, прерванная закрытием приложения, считается неудачной.
    it.status = st == DlStatus.running ? DlStatus.failed : st;
    if (it.status == DlStatus.failed && st == DlStatus.running) {
      it.error = 'Прервано';
    } else {
      it.error = m['error'] as String?;
    }
    it.path = m['path'] as String?;
    it.progress = it.status == DlStatus.done ? 1 : 0;
    return it;
  }
}

/// Загрузки файлов: качает фоновый загрузчик, готовый файл попадает в
/// общую папку «Загрузки» на телефоне.
class DownloadsController extends ChangeNotifier {
  DownloadsController._(this._file);

  final File _file;
  final List<DownloadItem> items = [];

  static Future<DownloadsController> load() async {
    final c = DownloadsController._(File(
        '${AppSettings.dataDir.path}${Platform.pathSeparator}downloads.json'));
    try {
      if (await c._file.exists()) {
        final data = jsonDecode(await c._file.readAsString());
        if (data is List) {
          for (final e in data) {
            final it = DownloadItem.fromJson(e);
            if (it != null) c.items.add(it);
          }
        }
      }
    } catch (_) {}
    return c;
  }

  int get activeCount =>
      items.where((e) => e.status == DlStatus.running).length;

  Future<void> _save() async {
    try {
      await _file.writeAsString(
          jsonEncode([for (final e in items.take(200)) e.toJson()]));
    } catch (_) {}
  }

  static const _mimeExt = {
    'application/pdf': '.pdf',
    'application/zip': '.zip',
    'application/vnd.android.package-archive': '.apk',
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'image/webp': '.webp',
    'video/mp4': '.mp4',
    'audio/mpeg': '.mp3',
    'text/plain': '.txt',
  };

  static String _fileName(String? suggested, String url, String? mime) {
    var n = (suggested ?? '').trim();
    if (n.isEmpty) {
      final segs = Uri.tryParse(url)?.pathSegments ?? const <String>[];
      if (segs.isNotEmpty) n = Uri.decodeComponent(segs.last);
    }
    n = n.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    if (n.isEmpty) n = 'download';
    if (!n.contains('.') && mime != null) {
      n += _mimeExt[mime.split(';').first.trim().toLowerCase()] ?? '';
    }
    return n.length > 120 ? n.substring(n.length - 120) : n;
  }

  Future<void> start({
    required String url,
    String? suggestedName,
    String? mimeType,
    String? userAgent,
    String? referer,
    String? cookies,
  }) async {
    final name = _fileName(suggestedName, url, mimeType);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final headers = <String, String>{
      if (userAgent != null && userAgent.isNotEmpty) 'User-Agent': userAgent,
      if (referer != null && referer.startsWith('http')) 'Referer': referer,
      if (cookies != null && cookies.isNotEmpty) 'Cookie': cookies,
    };
    final task = DownloadTask(
      url: url,
      filename: name,
      directory: 'zembo_dl_$id',
      baseDirectory: BaseDirectory.applicationDocuments,
      headers: headers,
      updates: Updates.statusAndProgress,
      retries: 1,
    );
    final item = DownloadItem(id: id, url: url, name: name)..task = task;
    items.insert(0, item);
    notifyListeners();
    toast('Загрузка началась: $name');
    unawaited(_run(item, task));
  }

  Future<void> _run(DownloadItem item, DownloadTask task) async {
    try {
      final result = await FileDownloader().download(
        task,
        onProgress: (p) {
          if (p >= 0 && p <= 1) {
            item.progress = p;
            notifyListeners();
          }
        },
      );
      if (result.status == TaskStatus.complete) {
        String? path;
        try {
          path = await FileDownloader()
              .moveToSharedStorage(task, SharedStorage.downloads);
        } catch (_) {}
        if (path == null) {
          item.status = DlStatus.failed;
          item.error = 'Не удалось сохранить в «Загрузки»';
          toast('Не удалось сохранить файл: ${item.name}');
        } else {
          item.status = DlStatus.done;
          item.path = path;
          item.progress = 1;
          toast('Файл сохранён в «Загрузки»: ${item.name}');
        }
      } else if (result.status == TaskStatus.canceled) {
        item.status = DlStatus.canceled;
      } else {
        item.status = DlStatus.failed;
        item.error = result.exception?.toString() ?? 'Не удалось скачать';
        toast('Не удалось скачать: ${item.name}');
      }
    } catch (e) {
      item.status = DlStatus.failed;
      item.error = '$e';
    }
    notifyListeners();
    await _save();
  }

  Future<void> cancel(DownloadItem item) async {
    final t = item.task;
    if (t != null) {
      try {
        await FileDownloader().cancelTaskWithId(t.taskId);
      } catch (_) {}
    }
  }

  Future<void> open(DownloadItem item) async {
    final p = item.path;
    if (p == null) return;
    try {
      final ok = await FileDownloader().openFile(filePath: p);
      if (!ok) toast('Не удалось открыть файл');
    } catch (_) {
      toast('Не удалось открыть файл');
    }
  }

  void remove(DownloadItem item) {
    items.remove(item);
    notifyListeners();
    _save();
  }

  void clearFinished() {
    items.removeWhere((e) => e.status != DlStatus.running);
    notifyListeners();
    _save();
  }
}

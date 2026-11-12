import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../i18n/i18n_core.dart';
import '../theme/app_theme.dart';
import 'app_keys.dart';
import 'app_settings.dart';

/// Найденная новая версия.
class UpdateInfo {
  const UpdateInfo({
    required this.tag,
    required this.version,
    required this.pageUrl,
    this.apkUrl,
  });

  final String tag;
  final String version;
  final String pageUrl;
  final String? apkUrl;
}

/// Проверка обновлений: при запуске браузер смотрит последний релиз на GitHub
/// (qmbys/Zembo_Browser) и, если версия новее, предлагает скачать APK и установить.
class UpdateController extends ChangeNotifier {
  UpdateController(this.settings, {required this.openUrl});

  final AppSettings settings;

  /// Открыть страницу релиза во вкладке браузера (если APK в релизе не нашёлся).
  final void Function(String url) openUrl;

  static const repo = 'qmbys/Zembo_Browser';

  UpdateInfo? available;
  bool checking = false;
  bool downloading = false;
  double progress = 0;
  String currentVersion = '';
  DownloadTask? _task;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Вызывается при запуске приложения.
  Future<void> checkOnStart() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
      notifyListeners();
    } catch (_) {}
    if (!settings.autoUpdate) return;
    // Даём приложению спокойно открыться.
    await Future<void>.delayed(const Duration(seconds: 4));
    await check(manual: false);
  }

  /// [manual] — проверка по кнопке: говорим и «обновлений нет», и об ошибках.
  Future<void> check({bool manual = true}) async {
    if (checking || downloading) return;
    checking = true;
    notifyListeners();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final pkg = await PackageInfo.fromPlatform();
      currentVersion = pkg.version;

      final req = await client
          .getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'ZemboBrowser');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode == 404) {
        if (manual) toast('Релизов пока нет');
        return;
      }
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final data = jsonDecode(await res.transform(utf8.decoder).join());
      if (data is! Map) throw const FormatException('bad json');

      final tag = '${data['tag_name'] ?? ''}';
      if (tag.isEmpty) {
        if (manual) toast('Релизов пока нет');
        return;
      }
      if (!_isNewer(tag, pkg.version, pkg.buildNumber)) {
        if (manual) toast('У вас последняя версия');
        return;
      }

      String? apk;
      final assets = data['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is Map &&
              '${a['name']}'.toLowerCase().endsWith('.apk') &&
              a['browser_download_url'] is String) {
            apk = a['browser_download_url'] as String;
            // Предпочитаем универсальный файл, если их несколько.
            if ('${a['name']}'.toLowerCase().contains('universal') ||
                !'${a['name']}'.toLowerCase().contains('arm')) {
              break;
            }
          }
        }
      }
      final info = UpdateInfo(
        tag: tag,
        version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
        pageUrl: '${data['html_url'] ?? 'https://github.com/$repo/releases'}',
        apkUrl: apk,
      );
      available = info;
      notifyListeners();
      // При запуске не напоминаем о версии, которую уже отложили.
      if (manual || settings.updateSkipped != tag) _showBanner();
    } catch (_) {
      if (manual) toast('Не удалось проверить обновления');
    } finally {
      client.close(force: true);
      checking = false;
      notifyListeners();
    }
  }

  /// Числа из тега ('v0.3.1+12' → [0,3,1,12]) сравниваются с текущей версией.
  static bool _isNewer(String tag, String version, String build) {
    List<int> nums(String s) => RegExp(r'\d+')
        .allMatches(s)
        .map((m) => int.tryParse(m.group(0)!) ?? 0)
        .toList();
    final a = nums(tag);
    final b = [...nums(version), int.tryParse(build) ?? 0];
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  void _showBanner() {
    final m = messengerKey.currentState;
    if (m == null || available == null) return;
    m.hideCurrentMaterialBanner();
    m.showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppColors.panel,
        leading: const Icon(Icons.system_update, color: AppColors.orange),
        content: ListenableBuilder(
          listenable: this,
          builder: (context, _) {
            final a = available;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  downloading
                      ? tr('Скачивание обновления…')
                      : tr('Доступна новая версия ${a?.version ?? ''}'),
                  style: const TextStyle(fontSize: 14.5),
                ),
                if (downloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 3,
                      color: AppColors.orange,
                      backgroundColor: const Color(0xFF2B3036),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          ListenableBuilder(
            listenable: this,
            builder: (context, _) => TextButton(
              onPressed: downloading ? cancel : later,
              child: Text(tr(downloading ? 'Отмена' : 'Позже'),
                  style: const TextStyle(color: AppColors.muted)),
            ),
          ),
          ListenableBuilder(
            listenable: this,
            builder: (context, _) => downloading
                ? const SizedBox.shrink()
                : FilledButton(
                    onPressed: install,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white),
                    child: Text(tr('Обновить')),
                  ),
          ),
        ],
      ),
    );
  }

  void later() {
    final a = available;
    if (a != null) settings.updateSkipped = a.tag;
    messengerKey.currentState?.hideCurrentMaterialBanner();
  }

  Future<void> cancel() async {
    final t = _task;
    if (t != null) {
      try {
        await FileDownloader().cancelTaskWithId(t.taskId);
      } catch (_) {}
    }
  }

  /// Скачивает APK и открывает установщик Android.
  Future<void> install() async {
    final a = available;
    if (a == null || downloading) return;
    final url = a.apkUrl;
    if (url == null) {
      // В релизе нет APK-файла — открываем страницу релиза.
      messengerKey.currentState?.hideCurrentMaterialBanner();
      openUrl(a.pageUrl);
      return;
    }
    downloading = true;
    progress = 0;
    notifyListeners();

    final task = DownloadTask(
      url: url,
      filename: 'ZemboBrowser-${a.version}.apk',
      baseDirectory: BaseDirectory.applicationSupport,
      updates: Updates.statusAndProgress,
      retries: 1,
    );
    _task = task;
    try {
      final result = await FileDownloader().download(
        task,
        onProgress: (p) {
          if (p >= 0 && p <= 1) {
            progress = p;
            notifyListeners();
          }
        },
      );
      if (result.status == TaskStatus.complete) {
        messengerKey.currentState?.hideCurrentMaterialBanner();
        final ok = await FileDownloader().openFile(task: task);
        if (!ok) toast('Не удалось открыть установщик');
      } else if (result.status != TaskStatus.canceled) {
        toast('Не удалось скачать обновление');
      }
    } catch (_) {
      toast('Не удалось скачать обновление');
    } finally {
      downloading = false;
      _task = null;
      notifyListeners();
    }
  }
}

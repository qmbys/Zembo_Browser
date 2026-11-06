import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'i18n/i18n_core.dart';
import 'state/app_settings.dart';
import 'state/filter_lists.dart';
import 'state/filter_proxy.dart';
import 'state/history_controller.dart';
import 'state/shortcuts_controller.dart';
import 'state/single_instance.dart';
import 'ui_scale.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ссылки и html-файлы, которые Windows передаёт браузеру по умолчанию.
  final openUrls = SingleInstance.urlsFromArgs(args);
  // Браузер уже запущен — отдаём ему адрес и закрываемся (в отладке не делаем).
  if (Platform.isWindows && !kDebugMode && await SingleInstance.forwardToRunning(openUrls)) {
    exit(0);
  }

  final settings = await AppSettings.load();
  // Язык интерфейса: выбранный в настройках, меняется сразу.
  I18n.setLanguage(settings.language);
  settings.addListener(() => I18n.setLanguage(settings.language));
  final shortcuts = await ShortcutsController.load();
  final history = await HistoryController.load();
  final menuSites =
      await ShortcutsController.load(fileName: 'menu.json', defaults: false);

  // Готовые списки фильтров и локальный прокси, который по ним блокирует домены.
  final filterLists = FilterLists(settings);
  final filterProxy = FilterProxy(settings, filterLists);
  final proxyOk = Platform.isWindows && await filterProxy.start();
  // Списки грузятся в фоне: страницы можно открывать сразу.
  filterLists.init();

  if (Platform.isWindows) {
    // Прокси и папка данных WebView задаются до создания первой страницы.
    try {
      await WebviewController.initializeEnvironment(
        userDataPath: settings.webviewDataPath,
        additionalArguments:
            settings.browserArgumentsFor(proxyPort: proxyOk ? filterProxy.port : null),
      );
    } catch (_) {}
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: Size(kWindowWidth, kWindowHeight),
      minimumSize: Size(650, 420),
      center: true,
      title: 'Zembo Browser',
      backgroundColor: Color(0xFF000000),
      // Убираем стандартный заголовок Windows — рисуем свой.
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await SingleInstance.start(openUrls);

  runApp(ZemboBrowserApp(
    settings: settings,
    lists: filterLists,
    shortcuts: shortcuts,
    menuSites: menuSites,
    history: history,
    proxy: proxyOk ? filterProxy : null,
  ));
}

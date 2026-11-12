import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'i18n/i18n_core.dart';
import 'state/app_settings.dart';
import 'state/downloads_controller.dart';
import 'state/filter_lists.dart';
import 'state/history_controller.dart';
import 'state/passwords_controller.dart';
import 'state/shortcuts_controller.dart';
import 'state/suggest_service.dart';
import 'state/tabs_controller.dart';
import 'state/update_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Папка данных: на Android это внутренняя папка приложения.
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}/ZemboBrowser');
  await dir.create(recursive: true);
  AppSettings.setDataDir(dir);

  final settings = await AppSettings.load();
  I18n.setLanguage(settings.language);
  settings.addListener(() => I18n.setLanguage(settings.language));

  final shortcuts = await ShortcutsController.load();
  final history = await HistoryController.load();
  final downloads = await DownloadsController.load();
  final passwords = PasswordsController(settings);
  await passwords.init();
  final lists = FilterLists(settings);
  // Списки фильтров грузятся в фоне через пару секунд после запуска,
  // чтобы не мешать первым действиям.
  Future<void>.delayed(const Duration(seconds: 2), lists.init);

  final tabs = TabsController(
    settings: settings,
    lists: lists,
    history: history,
    downloads: downloads,
    passwords: passwords,
  );
  // Если выбран свой DNS-сервер — включаем локальный прокси до открытия страниц.
  await tabs.network.apply();
  final updates = UpdateController(settings, openUrl: (u) => tabs.newTab(url: u));
  final suggest = SuggestService(settings, history);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF090A0C),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(ZemboMobileApp(
    settings: settings,
    lists: lists,
    shortcuts: shortcuts,
    history: history,
    tabs: tabs,
    suggest: suggest,
    updates: updates,
  ));
  // Проверка обновлений — после открытия окна, в фоне.
  updates.checkOnStart();
}

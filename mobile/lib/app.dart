import 'package:flutter/material.dart';

import 'pages/browser_page.dart';
import 'state/app_keys.dart';
import 'state/app_settings.dart';
import 'state/filter_lists.dart';
import 'state/history_controller.dart';
import 'state/shortcuts_controller.dart';
import 'state/suggest_service.dart';
import 'state/tabs_controller.dart';
import 'state/update_controller.dart';
import 'theme/app_theme.dart';

class ZemboMobileApp extends StatelessWidget {
  const ZemboMobileApp({
    super.key,
    required this.settings,
    required this.lists,
    required this.shortcuts,
    required this.history,
    required this.tabs,
    required this.suggest,
    required this.updates,
  });

  final AppSettings settings;
  final FilterLists lists;
  final ShortcutsController shortcuts;
  final HistoryController history;
  final TabsController tabs;
  final SuggestService suggest;
  final UpdateController updates;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zembo Browser',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scaffoldMessengerKey: messengerKey,
      // Масштаб браузера: размер текста и значков интерфейса.
      builder: (context, child) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final k = settings.uiScale;
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(mq.textScaler.scale(1) * k),
            ),
            child: IconTheme.merge(
              data: IconThemeData(size: 24 * k),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
      home: BrowserPage(
        settings: settings,
        lists: lists,
        shortcuts: shortcuts,
        history: history,
        tabs: tabs,
        suggest: suggest,
        updates: updates,
      ),
    );
  }
}


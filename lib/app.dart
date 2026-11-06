import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/browser_home_page.dart';
import 'state/app_settings.dart';
import 'state/filter_lists.dart';
import 'state/filter_proxy.dart';
import 'state/history_controller.dart';
import 'state/shortcuts_controller.dart';
import 'ui_scale.dart';

class ZemboBrowserApp extends StatelessWidget {
  final AppSettings settings;
  final FilterLists? lists;
  final FilterProxy? proxy;
  final ShortcutsController? shortcuts;
  final ShortcutsController? menuSites;
  final HistoryController? history;
  const ZemboBrowserApp({
    super.key,
    required this.settings,
    this.lists,
    this.proxy,
    this.shortcuts,
    this.menuSites,
    this.history,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zembo Browser',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      builder: (context, child) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => UiScale(
          scale: settings.uiScale,
          child: child ?? const SizedBox(),
        ),
      ),
      home: BrowserHomePage(
        settings: settings,
        lists: lists,
        proxy: proxy,
        shortcuts: shortcuts,
        menuSites: menuSites,
        history: history,
      ),
    );
  }
}

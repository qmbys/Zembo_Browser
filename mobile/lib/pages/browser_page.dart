import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';
import '../state/app_settings.dart';
import '../state/filter_lists.dart';
import '../state/history_controller.dart';
import '../state/shortcuts_controller.dart';
import '../state/suggest_service.dart';
import '../state/tabs_controller.dart';
import '../state/update_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/home_content.dart';
import '../widgets/password_bar.dart';
import '../widgets/search_results_page.dart';
import '../widgets/sheets.dart';
import '../widgets/top_bar.dart';
import '../widgets/web_page.dart';
import 'downloads_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class BrowserPage extends StatelessWidget {
  const BrowserPage({
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

  Future<void> _back() async {
    if (tabs.fullscreen) {
      await tabs.exitFullscreen();
      return;
    }
    final t = tabs.active;
    if (tabs.canBack(t)) {
      await tabs.back(t);
      return;
    }
    if (tabs.tabs.length > 1) {
      tabs.closeTab(t);
      return;
    }
    SystemNavigator.pop();
  }

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HistoryPage(
          history: history,
          onOpen: (url) => tabs.open(url),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          settings: settings,
          passwords: tabs.passwords,
          updates: updates,
          onOpen: (url) => tabs.open(url),
        ),
      ),
    );
  }

  void _openDownloads(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DownloadsPage(downloads: tabs.downloads),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([tabs, settings]),
        builder: (context, _) {
          final fs = tabs.fullscreen;
          final bar = settings.blackBars ? Colors.black : AppColors.chrome;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: bar,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            child: Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              top: !fs,
              bottom: !fs,
              child: Column(
                children: [
                  if (!fs)
                    BrowserTopBar(
                      tabs: tabs,
                      onExtensions: () => showExtensionsSheet(
                        context,
                        settings: settings,
                        lists: lists,
                        tabs: tabs,
                      ),
                      onMail: () => showMailSheet(context),
                      onMenu: () => showMainMenu(
                        context,
                        tabs: tabs,
                        onHistory: () => _openHistory(context),
                        onDownloads: () => _openDownloads(context),
                        onSettings: () => _openSettings(context),
                      ),
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: tabs.activeIndex,
                      children: [
                        for (final t in tabs.tabs)
                          KeyedSubtree(
                            key: ValueKey(t.id),
                            child: t.isSearch
                                ? SearchResultsPage(
                                    tab: t,
                                    tabs: tabs,
                                    suggest: suggest,
                                  )
                                : t.isHome
                                ? ListenableBuilder(
                                    listenable: settings,
                                    builder: (context, _) => HomeContent(
                                      shortcuts: shortcuts,
                                      suggest: suggest,
                                      showShortcuts: settings.showShortcuts,
                                      onSearch: (v) => tabs.open(v, tab: t),
                                    ),
                                  )
                                : WebPage(tab: t, tabs: tabs),
                          ),
                      ],
                    ),
                  ),
                  if (!fs) PasswordBar(tabs: tabs),
                  if (!fs)
                    BrowserBottomBar(
                      tabs: tabs,
                      onTabs: () => showTabsSheet(context, tabs),
                    ),
                ],
              ),
            ),
          ));
        },
      ),
    );
  }
}

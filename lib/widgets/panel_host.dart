import 'package:flutter/material.dart';
import '../state/app_settings.dart';
import '../state/downloads_controller.dart';
import '../state/filter_lists.dart';
import '../state/filter_proxy.dart';
import '../state/mail_controller.dart';
import '../state/panels_controller.dart';
import '../state/tabs_controller.dart';
import 'downloads_panel.dart';
import 'mail_panel.dart';
import 'extensions_panel.dart';
import 'protection_panel.dart';
import 'site_settings_panel.dart';
import 'sites_panel.dart';
import '../state/shortcuts_controller.dart';

/// Слой поверх страницы, в котором рисуется открытая панель.
class PanelHost extends StatelessWidget {
  final PanelsController panels;
  final AppSettings settings;
  final TabsController tabs;
  final DownloadsController downloads;
  final MailController mail;
  final FilterLists? lists;
  final FilterProxy? proxy;
  final ShortcutsController? menuSites;

  const PanelHost({
    super.key,
    required this.panels,
    required this.settings,
    required this.tabs,
    required this.downloads,
    required this.mail,
    this.lists,
    this.proxy,
    this.menuSites,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: panels,
      builder: (context, _) {
        if (panels.open == PanelKind.none) return const SizedBox.shrink();
        return Stack(
          children: [
            // Нажатие мимо панели закрывает её (панель верхней части не перекрываем).
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: panels.close,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: 102,
              right: 12,
              child: switch (panels.open) {
                PanelKind.extensions => ExtensionsPanel(
                      settings: settings,
                      tabs: tabs,
                      panels: panels,
                      lists: lists,
                      proxy: proxy,
                    ),
                PanelKind.sites => SitesPanel(
                    sites: menuSites ?? ShortcutsController(defaults: false),
                    onOpen: (url) {
                      panels.close();
                      tabs.navigate(url);
                    },
                  ),
                PanelKind.site => SiteSettingsPanel(tabs: tabs, panels: panels),
                PanelKind.protection =>
                  ProtectionPanel(settings: settings, proxy: proxy),
                PanelKind.mail => MailPanel(
                    mail: mail,
                    settings: settings,
                    onOpenUrl: (url) {
                      panels.close();
                      tabs.addTab();
                      tabs.navigate(url);
                    },
                  ),
                _ => DownloadsPanel(downloads: downloads),
              },
            ),
          ],
        );
      },
    );
  }
}

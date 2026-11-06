import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../models/browser_tab.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Страница сайта в активной вкладке.
class WebPage extends StatelessWidget {
  final BrowserTab tab;
  final TabsController tabs;
  const WebPage({super.key, required this.tab, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final web = tab.web;
    if (!tab.webReady || web == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.orange),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Webview(
            web,
            permissionRequested: (url, kind, user) =>
                tabs.onPermission(tab, url, kind, user),
            // Интерфейс масштабируется, поэтому сглаживаем картинку страницы.
            filterQuality: FilterQuality.medium,
          ),
        ),
        if (tab.loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.orange,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

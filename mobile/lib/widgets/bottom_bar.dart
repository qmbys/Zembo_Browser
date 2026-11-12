import 'package:flutter/material.dart';

import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Нижняя панель: назад, вперёд, домой, новая вкладка, переключатель вкладок.
class BrowserBottomBar extends StatelessWidget {
  final TabsController tabs;
  final VoidCallback onTabs;
  const BrowserBottomBar({super.key, required this.tabs, required this.onTabs});

  @override
  Widget build(BuildContext context) {
    final t = tabs.active;
    final k = tabs.settings.uiScale;
    final canBack = tabs.canBack(t);
    Color c(bool on) => on ? AppColors.foreground : const Color(0xFF4A5159);

    Widget slot(Widget child) => Expanded(child: Center(child: child));
    Widget btn(IconData icon, bool on, VoidCallback? tap) => IconButton(
          onPressed: on ? tap : null,
          icon: Icon(icon, color: c(on), size: 24 * k),
          splashRadius: 24,
        );

    return Container(
      height: 52 * k,
      decoration: BoxDecoration(
        color: tabs.settings.blackBars ? Colors.black : AppColors.chrome,
        border: const Border(top: BorderSide(color: Color(0xFF16191D))),
      ),
      child: Row(
        children: [
          slot(btn(Icons.arrow_back, canBack, () => tabs.back(t))),
          slot(btn(Icons.arrow_forward, t.canGoForward && t.url != null,
              () => tabs.forward(t))),
          slot(btn(Icons.home_outlined, !t.isHome, () => tabs.goHome(t))),
          slot(btn(Icons.add, true, () => tabs.newTab())),
          slot(
            GestureDetector(
              onTap: onTabs,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.orange, width: 1.8),
                    ),
                    child: Text(
                      '${tabs.tabs.length}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

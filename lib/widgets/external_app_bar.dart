import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../state/app_links.dart';
import '../state/external_links.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Плашка «Перейти в приложение»: появляется, когда сайт просит открыть программу
/// (tg:, discord:, steam: и т.п.), и как кнопка на страницах вроде t.me.
class ExternalAppBar extends StatelessWidget {
  final TabsController tabs;
  const ExternalAppBar({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tabs,
      builder: (context, _) {
        final url = tabs.externalUrl;
        if (url != null && tabs.externalTabId == tabs.activeId) {
          return _card(
            title: 'Сайт хочет открыть приложение',
            app: ExternalLinks.appName(url),
            primary: 'Перейти в приложение',
            onPrimary: () => tabs.openExternal(),
            onCancel: tabs.dismissExternal,
          );
        }
        final AppLink? link = tabs.activeAppLink;
        if (link == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 108, right: 14),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20)),
                    onTap: () => tabs.openExternal(link.url),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.open_in_new_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Открыть в приложении ${link.app}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white)),
                      ]),
                    ),
                  ),
                  InkWell(
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(20)),
                    onTap: () => tabs.dismissAppLink(link.app),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(6, 8, 12, 8),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card({
    required String title,
    required String app,
    required String primary,
    required VoidCallback onPrimary,
    required VoidCallback onCancel,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 108),
        child: Container(
          width: 460,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground)),
              const SizedBox(height: 2),
              Text(app,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(children: [
                FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(primary),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.foreground,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Отмена'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

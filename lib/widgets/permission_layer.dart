import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';

import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';
import 'site_settings_panel.dart';

/// Окошко «сайт запрашивает доступ» (местоположение, микрофон, камера …).
class PermissionLayer extends StatelessWidget {
  final TabsController tabs;
  const PermissionLayer({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tabs,
      builder: (context, _) {
        final a = tabs.permAsk;
        if (a == null || a.tabId != tabs.active.id || tabs.active.fullscreen) {
          return const SizedBox.shrink();
        }
        return Stack(children: [
          Positioned(
            top: 106,
            left: 90,
            child: Material(
              color: const Color(0xFF14171B),
              elevation: 10,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 340,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF252A30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Icon(permIcon(a.kind), size: 18, color: AppColors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(a.host,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground)),
                      ),
                      InkWell(
                        onTap: tabs.dismissPermission,
                        child: const Icon(Icons.close,
                            size: 17, color: AppColors.muted),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    const Text('Хочет:',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(permRequestText(a.kind),
                        style: const TextStyle(
                            fontSize: 13.5, color: AppColors.foreground)),
                    const SizedBox(height: 12),
                    Row(children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () => tabs.answerPermission(true),
                        child: const Text('Разрешить'),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => tabs.answerPermission(false),
                        child: const Text('Блокировать',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

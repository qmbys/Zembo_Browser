import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';

import '../state/mail_controller.dart';
import '../state/panels_controller.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Подсказка привязанных адресов под полем «e-mail / логин» на сайте.
class MailSuggestLayer extends StatelessWidget {
  final TabsController tabs;
  final MailController mail;
  final PanelsController panels;
  const MailSuggestLayer({
    super.key,
    required this.tabs,
    required this.mail,
    required this.panels,
  });

  static const double _topBar = 100; // высота верхней панели браузера

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tabs, mail]),
      builder: (context, _) {
        final p = tabs.mailPrompt;
        if (p == null || p.tabId != tabs.active.id || !mail.hasAccounts) {
          return const SizedBox.shrink();
        }
        final emails = mail.emails;
        final width = p.width.clamp(260.0, 380.0).toDouble();
        final height = 12.0 + emails.length * 38 + 1 + 38;

        return LayoutBuilder(
          builder: (context, box) {
            final offsetY = tabs.active.fullscreen ? 0.0 : _topBar;
            var left = p.x;
            var top = p.y + offsetY + 4;
            if (left + width > box.maxWidth - 8) left = box.maxWidth - width - 8;
            if (top + height > box.maxHeight - 8) {
              // Не помещается снизу — показываем над полем.
              top = (p.y + offsetY - height - 40).clamp(8.0, box.maxHeight).toDouble();
            }
            if (left < 8) left = 8;

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    color: const Color(0xFF14171B),
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: width,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF252A30)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final e in emails)
                            _Row(
                              icon: Icons.mail_outline,
                              label: e,
                              onTap: () => tabs.fillMail(e),
                            ),
                          const Divider(
                              height: 1,
                              indent: 10,
                              endIndent: 10,
                              color: Color(0xFF22272D)),
                          _Row(
                            icon: Icons.settings_outlined,
                            label: 'Управление почтами',
                            muted: true,
                            onTap: () {
                              tabs.hideMailPrompt();
                              panels.show(PanelKind.mail);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool muted;
  final VoidCallback onTap;
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 38,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon,
                  size: 17,
                  color: muted ? AppColors.muted : AppColors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: muted ? AppColors.muted : AppColors.foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

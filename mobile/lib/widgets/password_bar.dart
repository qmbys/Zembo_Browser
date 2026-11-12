import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Полоса над нижней панелью: предложение сохранить пароль
/// или подсказка сохранённых логинов для открытого сайта.
class PasswordBar extends StatelessWidget {
  final TabsController tabs;
  const PasswordBar({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final t = tabs.active;

    final sp = tabs.savePrompt;
    if (sp != null && sp.tabId == t.id) {
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.key, size: 20, color: AppColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sp.update ? 'Обновить пароль?' : 'Сохранить пароль?',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(
                        sp.username.isEmpty
                            ? sp.host
                            : '${sp.username} · ${sp.host}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: tabs.dismissSavePrompt,
                  child: const Text('Не сейчас',
                      style: TextStyle(color: AppColors.muted)),
                ),
                TextButton(
                  onPressed: tabs.neverSavePassword,
                  child: const Text('Никогда',
                      style: TextStyle(color: AppColors.muted)),
                ),
                FilledButton(
                  onPressed: tabs.confirmSavePassword,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white),
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final fp = tabs.fieldPrompt;
    if (fp != null && fp.tabId == t.id && tabs.settings.autofillPasswords) {
      final host = Uri.tryParse(t.url ?? '')?.host ?? '';
      final logins = tabs.passwords.forHost(host);
      if (logins.isNotEmpty) {
        return _Panel(
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.key, size: 20, color: AppColors.orange),
                ),
                for (final l in logins)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: AppColors.tile,
                      side: const BorderSide(color: AppColors.border),
                      label: Text(
                        l.username.isEmpty ? '(без логина)' : l.username,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      onPressed: () => tabs.fillLogin(t, l),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: child,
    );
  }
}

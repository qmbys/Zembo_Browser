import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';

import '../pages/settings_page.dart';
import '../state/password_script.dart';
import '../state/passwords_controller.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Подсказка сохранённых логинов под полем входа и окошко «Сохранить пароль?».
class PasswordLayer extends StatelessWidget {
  final TabsController tabs;
  final PasswordsController passwords;
  const PasswordLayer({super.key, required this.tabs, required this.passwords});

  static const double _topBar = 100;

  void _openManager() {
    tabs.hidePwPrompt();
    SettingsPage.jumpTo.value = 'passwords';
    tabs.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tabs, passwords]),
      builder: (context, _) {
        final children = <Widget>[];
        final active = tabs.active;

        final p = tabs.pwPrompt;
        if (p != null && p.tabId == active.id) {
          final host = Uri.tryParse(active.url ?? '')?.host ?? '';
          final logins = passwords.forHost(host);
          if (logins.isNotEmpty) {
            children.add(_suggest(context, p, logins, active.fullscreen));
          }
        }

        final save = tabs.pwSave;
        if (save != null && save.tabId == active.id && !active.fullscreen) {
          children.add(_savePrompt(save));
        }
        if (children.isEmpty) return const SizedBox.shrink();
        return Stack(children: children);
      },
    );
  }

  Widget _suggest(BuildContext context, PasswordPrompt p,
      List<SavedLogin> logins, bool fullscreen) {
    return LayoutBuilder(builder: (context, box) {
      final width = p.width.clamp(260.0, 380.0).toDouble();
      final height = 12.0 + logins.length * 44 + 1 + 38;
      final offsetY = fullscreen ? 0.0 : _topBar;
      var left = p.x;
      var top = p.y + offsetY + 4;
      if (left + width > box.maxWidth - 8) left = box.maxWidth - width - 8;
      if (top + height > box.maxHeight - 8) {
        top = (p.y + offsetY - height - 40).clamp(8.0, box.maxHeight).toDouble();
      }
      if (left < 8) left = 8;
      return Stack(children: [
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
                  for (final l in logins)
                    _Row(
                      icon: Icons.key_outlined,
                      title: l.username.isEmpty ? '(без логина)' : l.username,
                      subtitle: p.hasPassword ? '••••••••' : null,
                      onTap: () => tabs.fillPassword(l),
                    ),
                  const Divider(
                      height: 1,
                      indent: 10,
                      endIndent: 10,
                      color: Color(0xFF22272D)),
                  _Row(
                    icon: Icons.settings_outlined,
                    title: 'Управление паролями',
                    muted: true,
                    onTap: _openManager,
                  ),
                ],
              ),
            ),
          ),
        ),
      ]);
    });
  }

  Widget _savePrompt(PasswordSavePrompt s) {
    return Positioned(
      top: _topBar + 6,
      right: 16,
      child: Material(
        color: const Color(0xFF14171B),
        elevation: 10,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 330,
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
                const Icon(Icons.key_outlined, size: 18, color: AppColors.orange),
                const SizedBox(width: 8),
                Text(s.update ? 'Обновить пароль?' : 'Сохранить пароль?',
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground)),
                const Spacer(),
                InkWell(
                  onTap: tabs.dismissPwSave,
                  child: const Icon(Icons.close, size: 17, color: AppColors.muted),
                ),
              ]),
              const SizedBox(height: 10),
              Text(s.host,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(s.username.isEmpty ? '(без логина)' : s.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.foreground)),
              const SizedBox(height: 2),
              const Text('••••••••',
                  style: TextStyle(fontSize: 13.5, color: AppColors.foreground)),
              const SizedBox(height: 12),
              Row(children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: tabs.acceptPwSave,
                  child: Text(s.update ? 'Обновить' : 'Сохранить'),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: tabs.dismissPwSave,
                  child: const Text('Не сейчас',
                      style: TextStyle(color: AppColors.muted)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: tabs.neverPwSave,
                  child: const Text('Никогда',
                      style: TextStyle(color: AppColors.muted)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool muted;
  final VoidCallback onTap;
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: subtitle != null ? 44 : 38,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Icon(icon, size: 17, color: muted ? AppColors.muted : AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: muted ? AppColors.muted : AppColors.foreground)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

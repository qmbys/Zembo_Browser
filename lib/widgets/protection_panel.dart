import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import '../state/app_settings.dart';
import '../state/filter_proxy.dart';
import '../theme/app_theme.dart';
import 'panel_frame.dart';

/// Значок щита: уровень защиты (отключена / стандартная / строгая).
IconData shieldIconFor(int level) {
  switch (level) {
    case 0:
      return Icons.shield_outlined;
    case 1:
      return Icons.shield;
    default:
      return Icons.verified_user;
  }
}

class ProtectionPanel extends StatelessWidget {
  final AppSettings settings;
  final FilterProxy? proxy;
  const ProtectionPanel({super.key, required this.settings, this.proxy});

  static const _levels = <(String, String, IconData)>[
    (
      'Отключена',
      'Ничего не блокируется: реклама и трекеры работают как обычно.',
      Icons.shield_outlined,
    ),
    (
      'Стандартная',
      'Блокирует рекламу, казино и известные рекламные сети. Подходит для большинства сайтов.',
      Icons.shield,
    ),
    (
      'Строгая',
      'Дополнительно блокирует трекеры, сбор данных и вредоносные сайты (список HaGeZi Pro) и отправляет сигнал «Не отслеживать». Некоторые сайты могут работать неправильно.',
      Icons.verified_user,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: 'Уровень защиты',
      child: ListenableBuilder(
        listenable: Listenable.merge([settings, if (proxy != null) proxy!]),
        builder: (context, _) {
          final level = settings.protectionLevel;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: [
                for (var i = 0; i < _levels.length; i++)
                  _LevelTile(
                    title: _levels[i].$1,
                    description: _levels[i].$2,
                    icon: _levels[i].$3,
                    selected: level == i,
                    onTap: () => settings.protectionLevel = i,
                  ),
                if (proxy != null && level > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Заблокировано запросов: ${proxy!.blockedCount}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _LevelTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF181B20) : AppColors.tile,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.orange : const Color(0xFF171B20),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? AppColors.orange : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.foreground)),
                    const SizedBox(height: 3),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? AppColors.orange : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

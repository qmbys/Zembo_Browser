import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';

import '../state/panels_controller.dart';
import '../state/site_permissions.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';
import 'panel_frame.dart';

String permLabel(PermKind k) => switch (k) {
      PermKind.cookies => 'Файлы cookie',
      PermKind.location => 'Местоположение',
      PermKind.microphone => 'Микрофон',
      PermKind.camera => 'Камера',
      PermKind.notifications => 'Уведомления',
      PermKind.clipboard => 'Буфер обмена',
      PermKind.sensors => 'Датчики',
    };

IconData permIcon(PermKind k) => switch (k) {
      PermKind.cookies => Icons.cookie_outlined,
      PermKind.location => Icons.location_on_outlined,
      PermKind.microphone => Icons.mic_none,
      PermKind.camera => Icons.videocam_outlined,
      PermKind.notifications => Icons.notifications_none,
      PermKind.clipboard => Icons.content_paste,
      PermKind.sensors => Icons.sensors,
    };

/// Что именно просит сайт (для окошка запроса).
String permRequestText(PermKind k) => switch (k) {
      PermKind.cookies => 'Сохранять файлы cookie',
      PermKind.location => 'Узнать ваше местоположение',
      PermKind.microphone => 'Использовать микрофон',
      PermKind.camera => 'Использовать камеру',
      PermKind.notifications => 'Показывать уведомления',
      PermKind.clipboard => 'Читать буфер обмена',
      PermKind.sensors => 'Использовать датчики движения и света',
    };

/// Панель «Настройки сайта»: cookie, местоположение, микрофон, камера и т.д.
class SiteSettingsPanel extends StatelessWidget {
  final TabsController tabs;
  final PanelsController panels;
  const SiteSettingsPanel({super.key, required this.tabs, required this.panels});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tabs, tabs.sitePerms]),
      builder: (context, _) {
        final perms = tabs.sitePerms;
        final host = SitePermissions.hostKey(
            Uri.tryParse(tabs.active.url ?? '')?.host ?? '');
        return PanelFrame(
          title: 'Настройки сайта',
          width: 440,
          child: host.isEmpty
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(18, 4, 18, 18),
                  child: Text('Откройте сайт, чтобы настроить его',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(host,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.orange)),
                      const SizedBox(height: 10),
                      for (final k in PermKind.values)
                        _PermRow(
                          kind: k,
                          value: perms.get(host, k),
                          onChanged: (v) {
                            perms.set(host, k, v);
                            // Cookie применяются при загрузке страницы.
                            if (k == PermKind.cookies) tabs.reload();
                          },
                        ),
                      const SizedBox(height: 6),
                      const Text(
                        'Разрешения запрашиваются, когда сайт просит доступ. Настройки действуют и на поддомены.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                      if (perms.hasAny(host)) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () {
                            perms.reset(host);
                            tabs.reload();
                          },
                          child: const Text('Сбросить настройки сайта',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _PermRow extends StatelessWidget {
  final PermKind kind;
  final PermValue value;
  final ValueChanged<PermValue> onChanged;
  const _PermRow(
      {required this.kind, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cookies = kind == PermKind.cookies;
    final labels = [cookies ? 'Как везде' : 'Спросить', 'Разрешить', 'Запретить'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(permIcon(kind), size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(permLabel(kind),
                style: const TextStyle(fontSize: 13, color: AppColors.foreground)),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E1013),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF252A30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  GestureDetector(
                    onTap: () => onChanged(PermValue.values[i]),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: value.index == i
                              ? (i == 2
                                  ? const Color(0xFF5A2A2A)
                                  : i == 1
                                      ? const Color(0xFF243D2A)
                                      : const Color(0xFF2A3036))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(labels[i],
                            style: TextStyle(
                                fontSize: 11.5,
                                color: value.index == i
                                    ? AppColors.foreground
                                    : AppColors.muted)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

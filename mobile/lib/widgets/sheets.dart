import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';
import '../state/app_keys.dart';
import '../state/app_settings.dart';
import '../state/filter_lists.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';
import 'site_icon.dart';

Widget _handle() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3A4048),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

// ======================= Вкладки =======================

Future<void> showTabsSheet(BuildContext context, TabsController tabs) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.82,
    ),
    builder: (context) => ListenableBuilder(
      listenable: tabs,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('Вкладки: ${tabs.tabs.length}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: () {
                    tabs.newTab();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add, color: AppColors.orange),
                  label: const Text('Новая',
                      style: TextStyle(color: AppColors.orange)),
                ),
              ],
            ),
          ),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
              ),
              itemCount: tabs.tabs.length,
              itemBuilder: (context, i) {
                final t = tabs.tabs[i];
                final isActive = i == tabs.activeIndex;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    tabs.select(t);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    decoration: BoxDecoration(
                      color: AppColors.tile,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive ? AppColors.orange : AppColors.border,
                        width: isActive ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SiteIcon(
                              url: t.url ?? '',
                              label: t.title,
                              iconUrl: t.faviconUrl,
                              size: 22,
                            ),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => tabs.closeTab(t),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.close,
                                    size: 18, color: AppColors.muted),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          t.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

// ======================= Расширения =======================

Future<void> showExtensionsSheet(
  BuildContext context, {
  required AppSettings settings,
  required FilterLists lists,
  required TabsController tabs,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([settings, lists, tabs, tabs.blocked]),
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Text('Расширения',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            ),
            _adBlockCard(settings, lists, tabs),
            _ExtCard(
              icon: Icons.nightlight_outlined,
              iconColor: const Color(0xFF8B7CF6),
              title: 'Тёмная тема сайтов',
              trailing: Switch(
                value: settings.darkSites,
                onChanged: (v) => settings.darkSites = v,
              ),
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    'Тёмное оформление для сайтов. Сайты, у которых уже есть тёмная тема, не меняются.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
            _ExtCard(
              icon: Icons.vpn_lock_outlined,
              iconColor: const Color(0xFF6D4AFF),
              title: 'Proton VPN',
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () {
                Navigator.pop(context);
                tabs.open('https://protonvpn.com/download-android');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _adBlockCard(AppSettings settings, FilterLists lists, TabsController tabs) {
  return _ExtCard(
    icon: Icons.block,
    iconColor: AppColors.orange,
    title: 'Блокировщик рекламы',
    trailing: Switch(
      value: settings.adBlock,
      onChanged: (v) => settings.adBlock = v,
    ),
    initiallyExpanded: true,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Text(
          'Реклама на сайтах, трекеры и казино-баннеры по спискам фильтров.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text('Заблокировано запросов: ${tabs.blockedCount}',
            style: const TextStyle(fontSize: 14)),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 2),
        child: Text('Списки фильтров',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ),
      for (final def in FilterLists.presets)
        CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          value: settings.isListEnabled(def.id),
          onChanged: (v) => settings.setListEnabled(def.id, v ?? false),
          title: Text(def.name, style: const TextStyle(fontSize: 15)),
          subtitle: Text(
            lists.count(def.id) > 0
                ? '${lists.count(def.id)} доменов'
                : (lists.status(def.id).isNotEmpty
                    ? lists.status(def.id)
                    : def.description),
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        child: TextButton(
          onPressed: () => lists.updateAll(force: true),
          child: const Text('Обновить списки',
              style: TextStyle(color: AppColors.orange)),
        ),
      ),
    ],
  );
}

class _ExtCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget trailing;
  final List<Widget> children;
  final VoidCallback? onTap;
  final bool initiallyExpanded;

  const _ExtCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.trailing,
    this.children = const [],
    this.onTap,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        trailing,
      ],
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: children.isEmpty
          ? InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(padding: const EdgeInsets.all(12), child: header),
            )
          : Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: initiallyExpanded,
                tilePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                childrenPadding: EdgeInsets.zero,
                trailing: const SizedBox.shrink(),
                title: header,
                children: children,
              ),
            ),
    );
  }
}

// ======================= Почта =======================

Future<void> showMailSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          const SizedBox(height: 10),
          const Text('Почта',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const Text(
            'Встроенный почтовый клиент (как в десктопной версии) будет перенесён следующим шагом.',
            style: TextStyle(color: AppColors.muted, fontSize: 14.5),
          ),
        ],
      ),
    ),
  );
}


// ======================= Главное меню (⋮) =======================

Future<void> showMainMenu(
  BuildContext context, {
  required TabsController tabs,
  required VoidCallback onHistory,
  required VoidCallback onDownloads,
  required VoidCallback onSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      void run(VoidCallback f) {
        Navigator.pop(sheetContext);
        f();
      }

      return ListenableBuilder(
        listenable: tabs,
        builder: (context, _) {
          final t = tabs.active;
          final onPage = t.url != null;
          return Padding(
            padding: EdgeInsets.fromLTRB(
                14, 0, 14, MediaQuery.of(context).padding.bottom + 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _handle(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MenuTile(
                      icon: Icons.add,
                      label: 'Новая вкладка',
                      onTap: () => run(() => tabs.newTab()),
                    ),
                    _MenuTile(
                      icon: Icons.refresh,
                      label: 'Обновить',
                      enabled: onPage,
                      onTap: () => run(() => tabs.reload(t)),
                    ),
                    _MenuTile(
                      icon: Icons.link,
                      label: 'Копировать ссылку',
                      enabled: onPage,
                      onTap: () => run(() {
                        Clipboard.setData(ClipboardData(text: t.url ?? ''));
                        toast('Ссылка скопирована');
                      }),
                    ),
                    _MenuTile(
                      icon: Icons.desktop_windows_outlined,
                      label: 'Версия для ПК',
                      enabled: onPage,
                      active: t.desktop,
                      onTap: () => run(() => tabs.toggleDesktop(t)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MenuTile(
                      icon: Icons.history,
                      label: 'История',
                      onTap: () => run(onHistory),
                    ),
                    _MenuTile(
                      icon: Icons.download_outlined,
                      label: 'Загрузки',
                      onTap: () => run(onDownloads),
                    ),
                    _MenuTile(
                      icon: Icons.settings_outlined,
                      label: 'Настройки',
                      onTap: () => run(onSettings),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool active;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? const Color(0xFF4A5159)
        : (active ? AppColors.orange : AppColors.foreground);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.tile,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active ? AppColors.orange : AppColors.border,
                  ),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: color, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import '../state/app_settings.dart';
import '../state/filter_lists.dart';
import '../state/filter_proxy.dart';
import '../state/panels_controller.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';
import 'panel_frame.dart';

/// Панель «Расширения»: компактный список, подробности раскрываются стрелкой.
class ExtensionsPanel extends StatefulWidget {
  final AppSettings settings;
  final TabsController tabs;
  final PanelsController panels;
  final FilterLists? lists;
  final FilterProxy? proxy;
  const ExtensionsPanel({
    super.key,
    required this.settings,
    required this.tabs,
    required this.panels,
    this.lists,
    this.proxy,
  });

  @override
  State<ExtensionsPanel> createState() => _ExtensionsPanelState();
}

class _ExtensionsPanelState extends State<ExtensionsPanel> {
  final Set<String> _open = {};

  void _toggle(String id) => setState(() {
        if (!_open.remove(id)) _open.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final tabs = widget.tabs;
    final lists = widget.lists;
    final proxy = widget.proxy;

    return PanelFrame(
      title: 'Расширения',
      child: ListenableBuilder(
        listenable: Listenable.merge([
          settings,
          tabs,
          if (lists != null) lists,
          if (proxy != null) proxy,
        ]),
        builder: (context, _) {
          final tab = tabs.active;
          final host = tab.isBrowsing ? (Uri.tryParse(tab.url!)?.host ?? '') : '';
          final allowed = settings.adAllowHosts;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: [
                _ExtCard(
                  icon: Icons.block,
                  color: const Color(0xFFFF5418),
                  name: 'Блокировщик рекламы',
                  value: settings.adBlock,
                  onChanged: (v) => settings.adBlock = v,
                  expanded: _open.contains('ads'),
                  onToggle: () => _toggle('ads'),
                  description:
                      'Реклама на сайтах и в видео YouTube, трекеры и пропуск спонсорских вставок (SponsorBlock).',
                  details: [
                    if (settings.adBlock && host.isNotEmpty)
                      _InnerSwitch(
                        label: 'Отключить на $host',
                        value: settings.isAdAllowed(host),
                        onChanged: (v) => settings.setAdAllowed(host, v),
                      ),
                    if (settings.adBlock && host.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _PickerRow(
                        count: settings.hiddenCount(host),
                        onPick: () {
                          widget.panels.close();
                          tabs.startElementPicker();
                        },
                        onReset: () => settings.clearHidden(host),
                      ),
                    ],
                    if (settings.adBlock && allowed.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Сайты-исключения',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final h in allowed)
                            _HostChip(
                              host: h,
                              onRemove: () => settings.setAdAllowed(h, false),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (proxy != null && lists != null) ...[
                      Text(
                        'Заблокировано запросов: ${proxy.blockedCount}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.foreground),
                      ),
                      const SizedBox(height: 10),
                      const Text('Списки фильтров',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 4),
                      for (final def in FilterLists.presets)
                        _ListRow(def: def, settings: settings, lists: lists),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: lists.anyBusy
                            ? null
                            : () => lists.updateAll(force: true),
                        child: Text(
                          lists.anyBusy ? 'Обновление…' : 'Обновить списки',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.orange),
                        ),
                      ),
                    ] else
                      const Text(
                        'Сетевая блокировка рекламных доменов включается при запуске браузера: после изменения перезапусти его.',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.muted, height: 1.3),
                      ),
                  ],
                ),
                _ExtCard(
                  icon: Icons.dark_mode_outlined,
                  color: const Color(0xFFB59CFF),
                  name: 'Тёмная тема сайтов',
                  value: settings.darkSites,
                  onChanged: (v) => settings.darkSites = v,
                  expanded: _open.contains('dark'),
                  onToggle: () => _toggle('dark'),
                  description:
                      'Аналог Dark Reader: затемняет светлые сайты, тёмные не трогает. Сайты Google тёмные всегда (настройка в «Персонализации»).',
                ),
                _ExtCard(
                  icon: Icons.vpn_lock_outlined,
                  color: const Color(0xFF6D4AFF),
                  name: 'Proton VPN',
                  expanded: _open.contains('vpn'),
                  onToggle: () => _toggle('vpn'),
                  description:
                      'Расширением недоступно. Запусти приложение Proton VPN — браузер пойдёт через него автоматически.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Компактная строка расширения: значок, название, стрелка «подробнее», переключатель.
class _ExtCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String description;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> details;

  const _ExtCard({
    required this.icon,
    required this.color,
    required this.name,
    required this.description,
    required this.expanded,
    required this.onToggle,
    this.value,
    this.onChanged,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF171B20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withAlpha(36),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.foreground)),
                ),
                // Маленькая стрелка «подробнее».
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: onToggle,
                    tooltip: expanded ? 'Свернуть' : 'Подробнее',
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                    icon: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: const Icon(Icons.expand_more,
                          size: 18, color: AppColors.muted),
                    ),
                  ),
                ),
                if (value != null)
                  Transform.scale(
                    scale: 0.78,
                    child: Switch(
                      value: value!,
                      onChanged: onChanged,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.orange,
                      inactiveThumbColor: AppColors.muted,
                      inactiveTrackColor: AppColors.field,
                      trackOutlineColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected)
                            ? AppColors.orange
                            : AppColors.border,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 6),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted, height: 1.35)),
                  if (details.isNotEmpty && (value ?? true)) ...[
                    const SizedBox(height: 8),
                    ...details,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InnerSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _InnerSwitch(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: value ? AppColors.orange : AppColors.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostChip extends StatelessWidget {
  final String host;
  final VoidCallback onRemove;
  const _HostChip({required this.host, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(host,
              style: const TextStyle(fontSize: 12, color: AppColors.foreground)),
          const SizedBox(width: 4),
          InkResponse(
            onTap: onRemove,
            radius: 12,
            child: const Icon(Icons.close, size: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Кнопка «Скрыть элемент» и счётчик правил для сайта.
class _PickerRow extends StatelessWidget {
  final int count;
  final VoidCallback onPick;
  final VoidCallback onReset;
  const _PickerRow(
      {required this.count, required this.onPick, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.ads_click, size: 16, color: AppColors.orange),
                SizedBox(width: 8),
                Text('Скрыть элемент на странице',
                    style: TextStyle(fontSize: 12.5, color: AppColors.foreground)),
              ],
            ),
          ),
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text('Скрыто вручную на этом сайте: $count',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onReset,
                  child: const Text('Сбросить',
                      style: TextStyle(fontSize: 11.5, color: AppColors.orange)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Строка готового списка фильтров: переключатель, число доменов, дата обновления.
class _ListRow extends StatelessWidget {
  final FilterListDef def;
  final AppSettings settings;
  final FilterLists lists;
  const _ListRow(
      {required this.def, required this.settings, required this.lists});

  String _subtitle() {
    if (lists.isBusy(def.id)) return 'Загрузка…';
    final st = lists.status(def.id);
    final n = lists.count(def.id);
    if (n > 0) {
      final u = lists.updated(def.id);
      final date = u == null
          ? ''
          : ' · ${u.day.toString().padLeft(2, '0')}.${u.month.toString().padLeft(2, '0')}';
      return '$n ${tr('доменов')}$date${st.isNotEmpty ? ' · ${tr(st)}' : ''}';
    }
    return st.isNotEmpty ? tr(st) : tr(def.description);
  }

  @override
  Widget build(BuildContext context) {
    final on = settings.isListEnabled(def.id);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => settings.setListEnabled(def.id, !on),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                on ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: on ? AppColors.orange : AppColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.name,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.foreground)),
                  Text(_subtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../i18n/i18n.dart';
import '../state/app_settings.dart';
import '../state/languages.dart';
import '../state/passwords_controller.dart';
import '../state/update_controller.dart';
import '../widgets/flag_icon.dart';
import 'passwords_page.dart';
import '../theme/app_theme.dart';

const _scales = [0.75, 0.85, 0.9, 1.0, 1.1, 1.25];

/// Языки интерфейса: код, название на своём языке, флаг.
const _uiLangs = <(String, String, String)>[
  ('ru', 'Русский', 'ru'),
  ('uk', 'Українська', 'ua'),
  ('en-US', 'English', 'us'),
];

String _langValue(AppSettings s) {
  final v = s.language;
  if (v == Languages.system) return v;
  for (final e in _uiLangs) {
    if (e.$1 == v) return v;
  }
  return Languages.system;
}

double _nearest(double v) {
  var best = _scales.first;
  for (final s in _scales) {
    if ((s - v).abs() < (best - v).abs()) best = s;
  }
  return best;
}

class SettingsPage extends StatelessWidget {
  final AppSettings settings;
  final PasswordsController passwords;
  final UpdateController updates;
  final ValueChanged<String> onOpen;
  const SettingsPage({
    super.key,
    required this.settings,
    required this.passwords,
    required this.updates,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.chrome,
        title: const Text('Настройки'),
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          // Страница короткая: строим всё заранее, чтобы прокрутка не рывками.
          cacheExtent: 4000,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
          children: [
            _section('Язык'),
            _card([
              ListTile(
                title: const Text('Язык интерфейса'),
                subtitle: const Text('По умолчанию — язык системы',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                trailing: DropdownButton<String>(
                  value: _langValue(settings),
                  dropdownColor: AppColors.panel,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: Languages.system,
                      child: Row(children: [
                        const Icon(Icons.smartphone, size: 20),
                        const SizedBox(width: 10),
                        Text('Как в системе',
                            style: const TextStyle(fontSize: 14)),
                      ]),
                    ),
                    for (final e in _uiLangs)
                      DropdownMenuItem(
                        value: e.$1,
                        child: Row(children: [
                          FlagIcon(e.$3, width: 24, height: 16),
                          const SizedBox(width: 10),
                          Text(e.$2, style: const TextStyle(fontSize: 14)),
                        ]),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) settings.language = v;
                  },
                ),
              ),
            ]),
            _section('Поиск'),
            _card([
              ListTile(
                title: const Text('Поисковая система'),
                trailing: DropdownButton<String>(
                  value: settings.searchEngine,
                  dropdownColor: AppColors.panel,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final e in AppSettings.searchEngines)
                      DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) settings.searchEngine = v;
                  },
                ),
              ),
              ListTile(
                title: const Text('Источник результатов'),
                subtitle: const Text(
                    'Если Brave Search не отвечает, поиск переключается на DuckDuckGo',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                trailing: DropdownButton<String>(
                  value: settings.searchSource,
                  dropdownColor: AppColors.panel,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final e in AppSettings.searchSources.entries)
                      DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) settings.searchSource = v;
                  },
                ),
              ),
              _switch('Своя страница результатов', 'Zembo Search рисует выдачу сам',
                  settings.searchShell, (v) => settings.searchShell = v),
              _KeyField(
                label: 'Ключ Brave Search API (необязательно)',
                value: settings.braveApiKey,
                onChanged: (v) => settings.braveApiKey = v,
              ),
              _KeyField(
                label: 'Ключ Google Safe Browsing (необязательно)',
                value: settings.safeBrowsingKey,
                onChanged: (v) => settings.safeBrowsingKey = v,
              ),
              _switch('Ярлыки на стартовой странице', null,
                  settings.showShortcuts, (v) => settings.showShortcuts = v),
            ]),
            _section('Внешний вид'),
            _card([
              ListTile(
                title: const Text('Масштаб браузера'),
                subtitle: const Text('Размер интерфейса и страниц сайтов',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                trailing: DropdownButton<double>(
                  value: _nearest(settings.uiScale),
                  dropdownColor: AppColors.panel,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final v in _scales)
                      DropdownMenuItem(
                        value: v,
                        child: Text('${(v * 100).round()}%',
                            style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) settings.uiScale = v;
                  },
                ),
              ),
            ]),
            _card([
              _switch('Чёрные панели', 'Верхняя и нижняя панели — чисто чёрные',
                  settings.blackBars, (v) => settings.blackBars = v),
            ]),
            _section('Сеть'),
            _card([
              ListTile(
                title: const Text('DNS-сервер'),
                subtitle: const Text(
                    'Защищённый DNS (DoH) для сайтов. «Системный» — без изменений.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                trailing: DropdownButton<String>(
                  value: settings.dns,
                  dropdownColor: AppColors.panel,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final e in AppSettings.dnsLabels.entries)
                      DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) settings.dns = v;
                  },
                ),
              ),
            ]),
            _section('Конфиденциальность'),
            _card([
              _switch('Блокировщик рекламы', 'Реклама, трекеры и казино-баннеры',
                  settings.adBlock, (v) => settings.adBlock = v),
              _switch('Do Not Track', 'Просить сайты не отслеживать',
                  settings.doNotTrack, (v) => settings.doNotTrack = v),
              _switch('Отклонять cookie', null, settings.rejectCookies,
                  (v) => settings.rejectCookies = v),
            ]),
            _section('Тёмная тема'),
            _card([
              _switch(
                  'Сайты Google всегда тёмные',
                  'Поиск, YouTube, Gmail, Диск и другие сайты Google',
                  settings.googleDark,
                  (v) => settings.googleDark = v),
              _switch('Тёмная тема сайтов', 'Затемнять сайты без своей тёмной темы',
                  settings.darkSites, (v) => settings.darkSites = v),
            ]),
            _section('Пароли'),
            _card([
              _switch('Предлагать сохранять пароли', null,
                  settings.offerPasswords, (v) => settings.offerPasswords = v),
              _switch('Подсказывать сохранённые логины', null,
                  settings.autofillPasswords,
                  (v) => settings.autofillPasswords = v),
              ListenableBuilder(
                listenable: passwords,
                builder: (context, _) => ListTile(
                  leading: const Icon(Icons.key, color: AppColors.muted),
                  title: const Text('Управление паролями'),
                  subtitle: Text('Сохранённые пароли (${passwords.count})',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13)),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PasswordsPage(passwords: passwords),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Пароли хранятся в защищённом хранилище Android и открываются только на этом телефоне',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ),
            ]),
            _section('Диагностика'),
            _card([const _Diagnostics()]),
            _section('Обновления'),
            _card([
              _switch('Проверять обновления при запуске', null,
                  settings.autoUpdate, (v) => settings.autoUpdate = v),
              ListenableBuilder(
                listenable: updates,
                builder: (context, _) => ListTile(
                  title: const Text('Версия'),
                  subtitle: Text(
                    updates.currentVersion.isEmpty ? '—' : updates.currentVersion,
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  trailing: updates.checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.orange),
                        )
                      : TextButton(
                          onPressed: updates.check,
                          child: const Text('Проверить обновления',
                              style: TextStyle(color: AppColors.orange)),
                        ),
                ),
              ),
            ]),
            _section('О браузере'),
            _card([
              ListTile(
                leading: const Icon(Icons.code, color: AppColors.muted),
                title: const Text('GitHub'),
                subtitle: const Text('github.com/qmbys',
                    style: TextStyle(color: AppColors.muted)),
                onTap: () {
                  Navigator.pop(context);
                  onOpen('https://github.com/qmbys');
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
        child: Text(title,
            style: const TextStyle(
                color: AppColors.orange,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
      );

  Widget _card(List<Widget> children) => RepaintBoundary(
        child: Container(
        decoration: BoxDecoration(
          color: AppColors.tile,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
        ),
      );

  Widget _switch(
          String title, String? subtitle, bool value, ValueChanged<bool> on) =>
      SwitchListTile(
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        value: value,
        onChanged: on,
      );
}


class _KeyField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _KeyField(
      {required this.label, required this.value, required this.onChanged});

  @override
  State<_KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<_KeyField> {
  late final _c = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: TextField(
          controller: _c,
          cursorColor: AppColors.orange,
          obscureText: true,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: tr(widget.label),
            isDense: true,
          ),
          onSubmitted: widget.onChanged,
          onTapOutside: (_) => widget.onChanged(_c.text),
        ),
      );
}


/// Проверка WebView и сети — помогает понять, почему не открываются сайты.
class _Diagnostics extends StatefulWidget {
  const _Diagnostics();

  @override
  State<_Diagnostics> createState() => _DiagnosticsState();
}

class _DiagnosticsState extends State<_Diagnostics> {
  String _webview = '—';
  String _net = '—';
  bool _busy = false;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _webview = '…';
      _net = '…';
    });
    try {
      final info = await InAppWebViewController.getCurrentWebViewPackage();
      _webview = info == null
          ? 'не найден'
          : '${info.packageName} ${info.versionName}';
    } catch (e) {
      _webview = 'ошибка: $e';
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client
          .getUrl(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 10));
      final res = await req.close().timeout(const Duration(seconds: 10));
      _net = 'OK (HTTP ${res.statusCode})';
    } catch (e) {
      _net = 'ошибка: $e';
    } finally {
      client.close(force: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(color: AppColors.muted, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WebView: $_webview', style: label),
          const SizedBox(height: 6),
          Text('Сеть (Dart): $_net', style: label),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : _run,
            child: const Text('Проверить'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import 'package:flutter/services.dart';
import '../state/app_settings.dart';
import '../state/downloads_controller.dart';
import '../widgets/downloads_panel.dart';
import '../state/default_browser.dart';
import '../state/history_controller.dart';
import '../state/languages.dart';
import '../state/passwords_controller.dart';
import '../widgets/flag_icon.dart';
import '../theme/app_theme.dart';

enum _Tab {
  personal,
  toolbar,
  search,
  privacy,
  passwords,
  languages,
  history,
  downloads,
  network,
  about
}

class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  final HistoryController history;
  final PasswordsController passwords;
  final DownloadsController downloads;
  final ValueChanged<String> onOpenUrl;
  const SettingsPage({
    super.key,
    required this.settings,
    required this.history,
    required this.passwords,
    required this.downloads,
    required this.onOpenUrl,
  });

  /// Открыть нужный раздел ('passwords', 'languages') — например, из подсказки паролей.
  static final jumpTo = ValueNotifier<String?>(null);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _Tab _tab = _Tab.personal;
  final _filter = TextEditingController();
  late final TextEditingController _apiKey =
      TextEditingController(text: widget.settings.braveApiKey);
  late final TextEditingController _sbKey =
      TextEditingController(text: widget.settings.safeBrowsingKey);
  bool _showKey = false;
  bool _showSb = false;
  int _shown = 200;

  @override
  void initState() {
    super.initState();
    SettingsPage.jumpTo.addListener(_jump);
    _jump();
  }

  void _jump() {
    final id = SettingsPage.jumpTo.value;
    if (id == null) return;
    SettingsPage.jumpTo.value = null;
    for (final t in _Tab.values) {
      if (t.name == id && mounted) setState(() => _tab = t);
    }
  }

  @override
  void dispose() {
    SettingsPage.jumpTo.removeListener(_jump);
    _filter.dispose();
    _apiKey.dispose();
    _sbKey.dispose();
    super.dispose();
  }

  static const _items = <_Tab, (IconData, String)>{
    _Tab.personal: (Icons.palette_outlined, 'Персонализация'),
    _Tab.toolbar: (Icons.tune, 'Панель инструментов'),
    _Tab.search: (Icons.search, 'Поиск'),
    _Tab.privacy: (Icons.shield_outlined, 'Конфиденциальность'),
    _Tab.passwords: (Icons.key_outlined, 'Пароли'),
    _Tab.languages: (Icons.translate, 'Языки'),
    _Tab.history: (Icons.history, 'История'),
    _Tab.downloads: (Icons.download_outlined, 'Загрузки'),
    _Tab.network: (Icons.language, 'Сеть'),
    _Tab.about: (Icons.info_outline, 'О браузере'),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ----- меню слева -----
        Container(
          width: 230,
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Color(0xFF14171B))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 12, bottom: 16),
                child: Text(
                  'Настройки',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              for (final e in _items.entries)
                _NavItem(
                  icon: e.value.$1,
                  label: e.value.$2,
                  selected: _tab == e.key,
                  onTap: () => setState(() => _tab = e.key),
                ),
            ],
          ),
        ),
        // ----- содержимое -----
        Expanded(
          child: ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: _content(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content() {
    final s = widget.settings;
    switch (_tab) {
      case _Tab.personal:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (DefaultBrowser.supported)
              const _Section(title: 'Браузер по умолчанию', children: [
                _DefaultBrowserRow(),
              ]),
            _Section(title: 'Внешний вид', children: [
              _Row(
                title: 'Масштаб браузера',
                subtitle: 'Размер всего интерфейса и страниц сайтов',
                trailing: _Dropdown<double>(
                  value: _nearest(s.uiScale),
                  items: {for (final v in _scales) v: '${(v * 100).round()}%'},
                  onChanged: (v) => s.uiScale = v,
                ),
              ),
            ]),
            _Section(title: 'Тёмная тема', children: [
              _Row(
                title: 'Сайты Google всегда тёмные',
                subtitle:
                    'Поиск, YouTube, Gmail, Диск и другие сайты Google сразу открываются с тёмной темой',
                trailing: _Toggle(
                  value: s.googleDark,
                  onChanged: (v) => s.googleDark = v,
                ),
              ),
            ]),
            _Section(title: 'Прокрутка', children: [
              _Row(
                title: 'Плавная прокрутка',
                subtitle: 'Страница прокручивается мягко, а не рывками',
                trailing: _Toggle(
                  value: s.smoothScroll,
                  onChanged: (v) => s.smoothScroll = v,
                ),
              ),
              const _Divider(),
              _Row(
                title: 'Чувствительность прокрутки',
                subtitle: 'Насколько далеко прокручивается страница за одно движение колеса',
                trailing: _Dropdown<double>(
                  value: _nearestSpeed(s.scrollSpeed),
                  items: {for (final v in _speeds) v: '${(v * 100).round()}%'},
                  onChanged: (v) => s.scrollSpeed = v,
                ),
              ),
            ]),
            _Section(title: 'Стартовая страница', children: [
              _Row(
                title: 'Показывать ярлыки',
                subtitle: 'Быстрые ссылки под строкой поиска',
                trailing: _Toggle(
                  value: s.showShortcuts,
                  onChanged: (v) => s.showShortcuts = v,
                ),
              ),
            ]),
          ],
        );
      case _Tab.toolbar:
        return _toolbarContent(s);
      case _Tab.search:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(title: 'Поиск', children: [
          _Row(
            title: 'Поисковая система',
            subtitle:
                'Используется в адресной строке и на стартовой странице. Zembo Search — наш поиск на основе Brave Search',
            trailing: _Dropdown<String>(
              value: s.searchEngine,
              items: {
                for (final e in AppSettings.searchEngines)
                  e: AppSettings.searchLabels[e] ?? e,
              },
              onChanged: (v) => s.searchEngine = v,
            ),
          ),
        ]),
            _braveSection(s),
          ],
        );
      case _Tab.privacy:
        return _Section(title: 'Конфиденциальность', children: [
          _Row(
            title: 'Уровень защиты',
            subtitle: 'Отключена, стандартная или строгая (то же, что значок щита)',
            trailing: _Dropdown<int>(
              value: s.protectionLevel,
              items: const {0: 'Отключена', 1: 'Стандартная', 2: 'Строгая'},
              onChanged: (v) => s.protectionLevel = v,
            ),
          ),
          const _Divider(),
          _Row(
            title: 'Файлы cookie',
            subtitle: 'При отклонении сайты не смогут сохранять cookie',
            trailing: _Dropdown<bool>(
              value: s.rejectCookies,
              items: const {false: 'Разрешать', true: 'Отклонять'},
              onChanged: (v) => s.rejectCookies = v,
            ),
          ),
          const _Divider(),
          _Row(
            title: 'Блокировать трекеры',
            subtitle: 'Включает большой список трекеров (HaGeZi Pro)',
            trailing: _Toggle(
              value: s.blockTrackers,
              onChanged: (v) => s.blockTrackers = v,
            ),
          ),
          const _Divider(),
          _Row(
            title: 'Отправлять запрос «Не отслеживать»',
            subtitle: 'Сайты получат сигнал Do Not Track',
            trailing: _Toggle(
              value: s.doNotTrack,
              onChanged: (v) => s.doNotTrack = v,
            ),
          ),
        ]);
      case _Tab.passwords:
        return _passwordsContent(s);
      case _Tab.languages:
        return _languagesContent(s);
      case _Tab.history:
        return _historyContent();
      case _Tab.downloads:
        return _downloadsContent();
      case _Tab.network:
        return _Section(title: 'Сеть', children: [
          _Row(
            title: 'DNS-сервер',
            subtitle:
                'Безопасный DNS (DNS-over-HTTPS): адреса сайтов определяются через выбранный сервер',
            trailing: _Dropdown<String>(
              value: s.dns,
              items: AppSettings.dnsLabels,
              onChanged: (v) => s.dns = v,
            ),
          ),
        ]);
      case _Tab.about:
        return const _Section(title: 'О браузере', children: [
          _Row(title: 'Zembo Browser', subtitle: 'Версия 1.0.0'),
        ]);
    }
  }

  // ---------- пароли ----------

  bool _confirmClear = false;

  Widget _passwordsContent(AppSettings s) {
    return ListenableBuilder(
      listenable: widget.passwords,
      builder: (context, _) {
        final pc = widget.passwords;
        final items = pc.items;
        final never = pc.neverHosts;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(title: 'Пароли', children: [
              _Row(
                title: 'Предлагать сохранять пароли',
                subtitle: 'После входа на сайт браузер спросит, сохранить ли пароль',
                trailing: _Toggle(
                  value: s.offerPasswords,
                  onChanged: (v) => s.offerPasswords = v,
                ),
              ),
              const _Divider(),
              _Row(
                title: 'Подсказывать сохранённые логины',
                subtitle: 'Под полем входа появится список — пароль подставится по клику',
                trailing: _Toggle(
                  value: s.autofillPasswords,
                  onChanged: (v) => s.autofillPasswords = v,
                ),
              ),
              const _Divider(),
              const _Row(
                title: 'Хранятся зашифрованными',
                subtitle:
                    'Пароли шифруются средствами Windows и открываются только в вашей учётной записи Windows',
              ),
            ]),
            _Section(title: 'Сохранённые пароли (${items.length})', children: [
              if (items.isEmpty)
                const _Row(
                  title: 'Пока ничего нет',
                  subtitle: 'Войдите на любой сайт — браузер предложит сохранить пароль',
                )
              else
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const _Divider(),
                  _PasswordRow(
                    key: ValueKey(items[i].id),
                    login: items[i],
                    controller: pc,
                  ),
                ],
            ]),
            if (never.isNotEmpty)
              _Section(title: 'Пароли не сохраняются для', children: [
                for (var i = 0; i < never.length; i++) ...[
                  if (i > 0) const _Divider(),
                  _Row(
                    title: never[i],
                    trailing: TextButton(
                      onPressed: () => pc.removeNever(never[i]),
                      child: const Text('Убрать',
                          style: TextStyle(color: AppColors.orange)),
                    ),
                  ),
                ],
              ]),
            if (items.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () {
                    if (_confirmClear) {
                      pc.deleteAll();
                      setState(() => _confirmClear = false);
                    } else {
                      setState(() => _confirmClear = true);
                    }
                  },
                  child: Text(
                    _confirmClear ? 'Точно удалить все пароли?' : 'Удалить все пароли',
                    style: TextStyle(
                        color: _confirmClear ? Colors.redAccent : AppColors.muted),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------- языки ----------

  Widget _languagesContent(AppSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.languageNeedsRestart)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x1AFF5A0A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x55FF5A0A)),
            ),
            child: const Text(
              'Интерфейс и скрипты на страницах меняются сразу. Чтобы сайты получали язык в заголовках запросов, перезапустите браузер.',
              style: TextStyle(fontSize: 13, color: AppColors.foreground),
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(
            'Интерфейс переведён на русский, украинский и английский. Для остальных языков интерфейс будет на английском, а сайты откроются на выбранном языке.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
          ),
        ),
        _Section(title: 'Язык интерфейса и сайтов', children: [
          _LangRow(
            leading: const Icon(Icons.public, size: 22, color: AppColors.muted),
            title: 'Как в системе',
            subtitle: 'Язык Windows',
            selected: s.language == Languages.system,
            onTap: () => s.language = Languages.system,
          ),
          for (final l in Languages.all) ...[
            const _Divider(),
            _LangRow(
              leading: FlagIcon(l.flag),
              title: l.native,
              subtitle: l.russian,
              selected: s.language == l.code,
              onTap: () => s.language = l.code,
            ),
          ],
        ]),
      ],
    );
  }

  Widget _braveSection(AppSettings s) {
    final hasKey = s.braveApiKey.trim().isNotEmpty;
    return _Section(title: 'Результаты поиска Zembo', children: [
      _Row(
        title: 'Оформление Zembo',
        subtitle:
            'Результаты Zembo Search показываются в стиле браузера. Если выключить, откроется обычная страница Brave Search',
        trailing: _Toggle(
          value: s.searchShell,
          onChanged: (v) => s.searchShell = v,
        ),
      ),
      const _Divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ключ Brave Search API (необязательно)',
                style: TextStyle(fontSize: 14, color: AppColors.foreground)),
            const SizedBox(height: 4),
            Text(
              hasKey
                  ? 'Результаты берутся напрямую у Brave. Если ключ не подойдёт, браузер возьмёт их со страницы Brave Search.'
                  : 'Ключ не нужен: без него результаты берутся со страницы Brave Search прямо в браузере. С ключом они приходят быстрее и надёжнее.',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              height: 42,
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _apiKey,
                      obscureText: !_showKey,
                      onChanged: (v) => s.braveApiKey = v,
                      cursorColor: AppColors.orange,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.foreground),
                      decoration: InputDecoration(
                        hintText: tr('Ключ Brave Search API'),
                        hintStyle: TextStyle(fontSize: 14, color: AppColors.muted),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showKey = !_showKey),
                    tooltip: _showKey ? 'Скрыть' : 'Показать',
                    splashRadius: 16,
                    icon: Icon(
                      _showKey ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => widget.onOpenUrl('https://brave.com/search/api/'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.orange,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
              ),
              child: const Text('Получить ключ на сайте Brave'),
            ),
          ],
        ),
      ),
      const _Divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ключ Google Safe Browsing (необязательно)',
                style: TextStyle(fontSize: 14, color: AppColors.foreground)),
            const SizedBox(height: 4),
            Text(
              s.safeBrowsingKey.trim().isNotEmpty
                  ? 'Ссылки в результатах проверяются по базе Google. Опасные сайты получают 3% репутации и уходят в конец выдачи.'
                  : 'Без ключа репутация — лишь примерная оценка: известные сайты получают высокий процент, остальным он занижен. С ключом ссылки проверяются по базе вредоносных и фишинговых сайтов Google.',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              height: 42,
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sbKey,
                      obscureText: !_showSb,
                      onChanged: (v) => s.safeBrowsingKey = v,
                      cursorColor: AppColors.orange,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.foreground),
                      decoration: InputDecoration(
                        hintText: tr('Ключ Safe Browsing API'),
                        hintStyle: TextStyle(fontSize: 14, color: AppColors.muted),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showSb = !_showSb),
                    tooltip: _showSb ? 'Скрыть' : 'Показать',
                    splashRadius: 16,
                    icon: Icon(
                      _showSb ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => widget.onOpenUrl(
                  'https://developers.google.com/safe-browsing/v4/get-started'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.orange,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
              ),
              child: const Text('Как получить бесплатный ключ'),
            ),
          ],
        ),
      ),
    ]);
  }

  static const _toolbarMeta = <String, (IconData, String)>{
    'sites': (Icons.apps, 'Мои сайты'),
    'pip': (Icons.picture_in_picture_alt_outlined,
        'Картинка в картинке (видна, когда на странице есть видео)'),
    'extensions': (Icons.extension_outlined, 'Расширения'),
    'downloads': (Icons.download_outlined, 'Загрузки'),
    'mail': (Icons.mail_outline, 'Почта'),
    'shield': (Icons.shield_outlined, 'Уровень защиты'),
    'menu': (Icons.more_vert, 'Меню (три точки)'),
  };

  Widget _toolbarContent(AppSettings s) {
    final order = s.toolbarOrder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 14),
          child: Text(
            'Перетаскивай кнопки за значок слева, чтобы поменять порядок, и выключай ненужные.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
        ),
        _Section(title: 'Кнопки справа от адресной строки', children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // В onReorderItem новый индекс уже учитывает удаление элемента.
            onReorderItem: (oldIndex, newIndex) => s.moveToolbarItem(
                oldIndex, newIndex > oldIndex ? newIndex + 1 : newIndex),
            children: [
              for (var i = 0; i < order.length; i++)
                Container(
                  key: ValueKey(order[i]),
                  color: AppColors.tile,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Icon(Icons.drag_indicator,
                              size: 20, color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(_toolbarMeta[order[i]]!.$1,
                          size: 20, color: const Color(0xFFCAD0D7)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_toolbarMeta[order[i]]!.$2,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.foreground)),
                      ),
                      if (order[i] == 'menu')
                        const Text('Всегда виден',
                            style: TextStyle(fontSize: 12, color: AppColors.muted))
                      else
                        _Toggle(
                          value: s.toolbarVisible(order[i]),
                          onChanged: (v) => s.setToolbarVisible(order[i], v),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ]),
        _Section(title: 'Кнопки в адресной строке', children: [
          _Row(
            title: 'Скопировать адрес',
            trailing: _Toggle(
              value: s.showCopyButton,
              onChanged: (v) => s.showCopyButton = v,
            ),
          ),
          const _Divider(),
          _Row(
            title: 'Звёздочка (добавить сайт)',
            trailing: _Toggle(
              value: s.showStarButton,
              onChanged: (v) => s.showStarButton = v,
            ),
          ),
        ]),
        TextButton(
          onPressed: s.resetToolbar,
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          child: const Text('Вернуть как было'),
        ),
      ],
    );
  }

  // ---------- история ----------

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _askClear() async {
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF171A1E),
        title: const Text('Очистить историю'),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 0),
              child: const Text('За последний час')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 1),
              child: const Text('За последние 24 часа')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 2),
              child: const Text('За всё время',
                  style: TextStyle(color: Color(0xFFFF6B6B)))),
        ],
      ),
    );
    switch (choice) {
      case 0:
        widget.history.clear(period: const Duration(hours: 1));
      case 1:
        widget.history.clear(period: const Duration(hours: 24));
      case 2:
        widget.history.clear();
    }
  }

  Widget _downloadsContent() {
    final d = widget.downloads;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Файлы, скачанные в браузере. Список сохраняется после перезапуска.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.4),
                ),
              ),
              TextButton(
                onPressed: d.openDownloadsFolder,
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text('Открыть папку'),
              ),
              TextButton(
                onPressed: d.clearFinished,
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text('Очистить список'),
              ),
            ],
          ),
        ),
        DownloadsList(downloads: d, scrollable: false),
      ],
    );
  }

  Widget _historyContent() {
    final h = widget.history;
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) {
        final q = _filter.text.trim().toLowerCase();
        final all = h.items
            .where((e) =>
                q.isEmpty ||
                e.title.toLowerCase().contains(q) ||
                e.url.toLowerCase().contains(q))
            .toList();
        final shown = all.take(_shown).toList();

        final rows = <Widget>[];
        String? lastDay;
        for (final e in shown) {
          final day = _dayLabel(e.time);
          if (day != lastDay) {
            lastDay = day;
            rows.add(Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
              child: Text(day,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.orange)),
            ));
          }
          rows.add(_HistoryRow(
            entry: e,
            time: _time(e.time),
            onOpen: () => widget.onOpenUrl(e.url),
            onDelete: () => h.remove(e),
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.field,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 18, color: AppColors.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _filter,
                            onChanged: (_) => setState(() => _shown = 200),
                            cursorColor: AppColors.orange,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.foreground),
                            decoration: InputDecoration(
                              hintText: tr('Поиск по истории'),
                              hintStyle:
                                  TextStyle(fontSize: 14, color: AppColors.muted),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: h.items.isEmpty ? null : _askClear,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Очистить'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                    side: const BorderSide(color: Color(0xFF3A2326)),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ],
            ),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 36, left: 4),
                child: Text(
                  q.isEmpty ? 'История пуста' : 'Ничего не найдено',
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ),
            ...rows,
            if (all.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: () => setState(() => _shown += 200),
                  child: Text('Показать ещё (${all.length - shown.length})'),
                ),
              ),
          ],
        );
      },
    );
  }

  static const _scales = [0.7, 0.75, 0.8, 0.85, 0.9, 1.0, 1.1];

  static const _speeds = [0.5, 0.75, 1.0, 1.5, 2.0, 3.0];

  static double _nearestSpeed(double v) {
    var best = _speeds.first;
    for (final s in _speeds) {
      if ((s - v).abs() < (best - v).abs()) best = s;
    }
    return best;
  }

  static double _nearest(double v) {
    var best = _scales.first;
    for (final s in _scales) {
      if ((s - v).abs() < (best - v).abs()) best = s;
    }
    return best;
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.field
                : (_hover ? const Color(0xFF0D0F12) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 19, color: sel ? AppColors.orange : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: sel ? AppColors.foreground : const Color(0xFFB4BBC2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.tile,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF171B20)),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const _Row({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.foreground)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0xFF171B20));
}

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.orange,
      inactiveThumbColor: AppColors.muted,
      inactiveTrackColor: AppColors.field,
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.orange
            : AppColors.border,
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF171A1E),
          borderRadius: BorderRadius.circular(10),
          style: const TextStyle(fontSize: 14, color: AppColors.foreground),
          icon: const Icon(Icons.expand_more, color: AppColors.muted),
          items: [
            for (final e in items.entries)
              DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final HistoryEntry entry;
  final String time;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _HistoryRow({
    required this.entry,
    required this.time,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final host = (Uri.tryParse(e.url)?.host ?? '').replaceFirst('www.', '');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? AppColors.tile : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(widget.time,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title.isEmpty ? e.url : e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.foreground),
                    ),
                    Text(
                      host.isEmpty ? e.url : host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: _hover ? 1 : 0,
                child: IconButton(
                  onPressed: widget.onDelete,
                  tooltip: tr('Удалить из истории'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                  splashRadius: 15,
                  icon: const Icon(Icons.close, size: 17, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _LangRow extends StatefulWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _LangRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LangRow> createState() => _LangRowState();
}

class _LangRowState extends State<_LangRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: _hover ? const Color(0xFF15191E) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 30, child: Center(child: widget.leading)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.foreground)),
                    Text(widget.subtitle,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
              if (widget.selected)
                const Icon(Icons.check, size: 20, color: AppColors.orange),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRow extends StatefulWidget {
  final SavedLogin login;
  final PasswordsController controller;
  const _PasswordRow({super.key, required this.login, required this.controller});

  @override
  State<_PasswordRow> createState() => _PasswordRowState();
}

class _PasswordRowState extends State<_PasswordRow> {
  String? _plain;
  bool _busy = false;

  Future<String?> _load() async {
    if (_plain != null) return _plain;
    setState(() => _busy = true);
    final p = await widget.controller.reveal(widget.login.id);
    if (!mounted) return p;
    setState(() {
      _plain = p;
      _busy = false;
    });
    return p;
  }

  Future<void> _toggle() async {
    if (_plain != null) {
      setState(() => _plain = null);
    } else {
      await _load();
    }
  }

  Future<void> _copy() async {
    final p = _plain ?? await widget.controller.reveal(widget.login.id);
    if (p != null) await Clipboard.setData(ClipboardData(text: p));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.login;
    return _Row(
      title: l.host,
      subtitle:
          '${l.username.isEmpty ? '(без логина)' : l.username}  •  ${_plain ?? '••••••••'}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: _plain == null ? 'Показать пароль' : 'Скрыть пароль',
            onPressed: _busy ? null : _toggle,
            icon: Icon(
                _plain == null ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 19,
                color: AppColors.muted),
          ),
          IconButton(
            tooltip: tr('Скопировать пароль'),
            onPressed: _copy,
            icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.muted),
          ),
          IconButton(
            tooltip: tr('Удалить'),
            onPressed: () => widget.controller.delete(l.id),
            icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}


class _DefaultBrowserRow extends StatefulWidget {
  const _DefaultBrowserRow();

  @override
  State<_DefaultBrowserRow> createState() => _DefaultBrowserRowState();
}

class _DefaultBrowserRowState extends State<_DefaultBrowserRow>
    with WidgetsBindingObserver {
  bool? _isDefault;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Вернулись из настроек Windows — проверяем, что выбрали.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final v = await DefaultBrowser.isDefault();
    if (mounted) setState(() => _isDefault = v);
  }

  Future<void> _makeDefault() async {
    setState(() => _busy = true);
    await DefaultBrowser.register();
    await DefaultBrowser.openWindowsSettings();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = _isDefault == true;
    return _Row(
      title: isDefault
          ? 'Zembo Browser — браузер по умолчанию'
          : 'Сделать Zembo Browser браузером по умолчанию',
      subtitle: isDefault
          ? 'Ссылки и html-файлы открываются в Zembo Browser'
          : 'Откроются настройки Windows: выберите Zembo Browser для ссылок и файлов HTML',
      trailing: isDefault
          ? const Icon(Icons.check_circle, size: 22, color: AppColors.orange)
          : FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: _busy ? null : _makeDefault,
              child: const Text('Сделать основным'),
            ),
    );
  }
}

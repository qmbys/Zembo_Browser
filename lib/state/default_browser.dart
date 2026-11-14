import 'dart:io';

/// «Браузер по умолчанию» в Windows.
///
/// Windows не разрешает программе назначить себя браузером по умолчанию молча:
/// мы регистрируем Zembo Browser в списке браузеров (раздел реестра пользователя),
/// а выбрать его пользователь должен сам в настройках Windows.
class DefaultBrowser {
  DefaultBrowser._();

  static const urlProgId = 'ZemboBrowserURL';
  static const htmlProgId = 'ZemboBrowserHTML';
  static const _appKey = r'Software\Clients\StartMenuInternet\ZemboBrowser';

  static bool get supported => Platform.isWindows;

  /// Выбран ли Zembo Browser для ссылок. Windows хранит выбор по-разному в зависимости
  /// от сборки (UserChoice, UserChoiceLatest и т.д.), поэтому читаем весь раздел
  /// выбора для https и http и ищем в нём идентификатор Zembo Browser.
  static Future<bool> isDefault() async {
    if (!supported) return false;
    const base =
        r'HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations';
    for (final proto in ['https', 'http']) {
      try {
        final r = await Process.run('reg', ['query', '$base\\$proto', '/s']);
        if (r.exitCode == 0 &&
            r.stdout.toString().toLowerCase().contains('zembobrowser')) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  static Future<void> _set(String key, String value, [String? name]) async {
    await Process.run('reg', [
      'add',
      'HKCU\\$key',
      if (name == null) '/ve' else ...['/v', name],
      '/t',
      'REG_SZ',
      '/d',
      value,
      '/f',
    ]);
  }

  /// Добавляет Zembo Browser в список браузеров Windows.
  static Future<void> register() async {
    if (!supported) return;
    final exe = Platform.resolvedExecutable;
    final open = '"$exe" "%1"';
    const cls = r'Software\Classes';

    for (final id in [urlProgId, htmlProgId]) {
      await _set('$cls\\$id', id == urlProgId ? 'Zembo Browser URL' : 'Zembo Browser HTML Document');
      await _set('$cls\\$id\\DefaultIcon', '"$exe",0');
      await _set('$cls\\$id\\shell\\open\\command', open);
    }
    await _set('$cls\\$urlProgId', '', 'URL Protocol');

    await _set(_appKey, 'Zembo Browser');
    await _set('$_appKey\\DefaultIcon', '"$exe",0');
    await _set('$_appKey\\shell\\open\\command', '"$exe"');
    const cap = '$_appKey\\Capabilities';
    await _set(cap, 'Zembo Browser', 'ApplicationName');
    await _set(cap, 'Zembo Browser', 'ApplicationDescription');
    await _set(cap, '"$exe",0', 'ApplicationIcon');
    await _set('$cap\\StartMenu', 'ZemboBrowser', 'StartMenuInternet');
    for (final p in ['http', 'https']) {
      await _set('$cap\\URLAssociations', urlProgId, p);
    }
    for (final e in ['.htm', '.html', '.shtml', '.xhtml']) {
      await _set('$cap\\FileAssociations', htmlProgId, e);
    }
    await _set(r'Software\RegisteredApplications',
        '$_appKey\\Capabilities', 'ZemboBrowser');
  }

  /// Открывает настройки Windows сразу на странице Zembo Browser — там одна кнопка
  /// «Использовать по умолчанию». На Windows 10 откроется общий список приложений.
  static Future<void> openWindowsSettings() async {
    if (!supported) return;
    // explorer.exe принимает такой адрес за путь к папке (открывает «Документы»),
    // поэтому отдаём его системе как ссылку.
    Future<bool> run(String uri) async {
      try {
        await Process.start('rundll32', ['url.dll,FileProtocolHandler', uri],
            mode: ProcessStartMode.detached);
        return true;
      } catch (_) {
        return false;
      }
    }

    if (!await run('ms-settings:defaultapps?registeredAppUser=ZemboBrowser')) {
      await run('ms-settings:defaultbrowser');
    }
  }
}

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

  /// Выбран ли Zembo Browser для ссылок https.
  static Future<bool> isDefault() async {
    if (!supported) return false;
    try {
      final r = await Process.run('reg', [
        'query',
        r'HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice',
        '/v',
        'ProgId',
      ]);
      return r.exitCode == 0 && r.stdout.toString().contains(urlProgId);
    } catch (_) {
      return false;
    }
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

  /// Открывает «Приложения по умолчанию» в настройках Windows.
  static Future<void> openWindowsSettings() async {
    if (!supported) return;
    try {
      await Process.start('explorer.exe', ['ms-settings:defaultbrowser'],
          mode: ProcessStartMode.detached);
    } catch (_) {}
  }
}

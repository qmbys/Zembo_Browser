import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'google_oauth.dart';
import 'secret_store.dart';

/// Готовые настройки популярных почтовых сервисов.
class MailProvider {
  const MailProvider({
    required this.id,
    required this.name,
    required this.host,
    this.port = 993,
    this.domains = const [],
    this.hint = '',
    this.helpUrl,
    this.webUrl,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final List<String> domains;
  final String hint;
  final String? helpUrl;
  final String? webUrl;
}

class MailAccount {
  MailAccount({
    required this.id,
    required this.email,
    required this.providerId,
    required this.host,
    required this.port,
    required this.secure,
    required this.username,
    required this.encPassword,
    this.authType = 'password',
  });

  /// 'none' — только адрес (без чтения писем), 'password' — пароль приложения,
  /// 'google' — вход через Google (OAuth).
  final String authType;

  final String id;
  final String email;
  final String providerId;
  final String host;
  final int port;
  final bool secure;
  final String username;
  final String encPassword;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'provider': providerId,
        'host': host,
        'port': port,
        'secure': secure,
        'user': username,
        'pass': encPassword,
        'auth': authType,
      };
}

class MailItem {
  const MailItem({
    required this.fromName,
    required this.fromEmail,
    required this.subject,
    required this.date,
    required this.seen,
    required this.body,
    required this.hasAttachments,
  });

  final String fromName;
  final String fromEmail;
  final String subject;
  final DateTime? date;
  final bool seen;
  final String body;
  final bool hasAttachments;

  String get sender => fromName.isNotEmpty ? fromName : fromEmail;
}

class MailBoxState {
  bool loading = false;
  String? error;
  List<MailItem> items = [];
  int? unseen;
  DateTime? updated;
}

/// Привязанные почтовые ящики: список адресов и входящие письма (IMAP).
class MailController extends ChangeNotifier {
  MailController(this.settings);

  final AppSettings settings;

  static const providers = <MailProvider>[
    MailProvider(
      id: 'gmail',
      name: 'Gmail',
      host: 'imap.gmail.com',
      domains: ['gmail.com', 'googlemail.com'],
      hint:
          'Для Gmail нужен пароль приложения: включи двухэтапную проверку в аккаунте Google и создай пароль приложения.',
      helpUrl: 'https://myaccount.google.com/apppasswords',
      webUrl: 'https://mail.google.com/',
    ),
    MailProvider(
      id: 'yandex',
      name: 'Яндекс',
      host: 'imap.yandex.com',
      domains: ['yandex.ru', 'yandex.com', 'ya.ru', 'yandex.ua', 'yandex.by', 'yandex.kz'],
      hint:
          'В Яндекс Почте включи доступ по IMAP и создай пароль приложения для почтового клиента.',
      helpUrl: 'https://id.yandex.ru/security/app-passwords',
      webUrl: 'https://mail.yandex.ru/',
    ),
    MailProvider(
      id: 'mailru',
      name: 'Mail.ru',
      host: 'imap.mail.ru',
      domains: ['mail.ru', 'inbox.ru', 'list.ru', 'bk.ru', 'internet.ru'],
      hint:
          'В настройках безопасности Mail.ru создай пароль для внешнего приложения и используй его.',
      helpUrl: 'https://account.mail.ru/user/2-step-auth/passwords/',
      webUrl: 'https://e.mail.ru/',
    ),
    MailProvider(
      id: 'ukrnet',
      name: 'Ukr.net',
      host: 'imap.ukr.net',
      domains: ['ukr.net'],
      hint:
          'В настройках ukr.net включи доступ к ящику по IMAP (внешние почтовые программы).',
      webUrl: 'https://mail.ukr.net/',
    ),
    MailProvider(
      id: 'yahoo',
      name: 'Yahoo',
      host: 'imap.mail.yahoo.com',
      domains: ['yahoo.com', 'ymail.com'],
      hint: 'Для Yahoo нужен пароль приложения из настроек безопасности.',
      helpUrl: 'https://login.yahoo.com/account/security',
      webUrl: 'https://mail.yahoo.com/',
    ),
    MailProvider(
      id: 'icloud',
      name: 'iCloud',
      host: 'imap.mail.me.com',
      domains: ['icloud.com', 'me.com', 'mac.com'],
      hint: 'Для iCloud нужен пароль для приложения (Apple ID → Вход и безопасность).',
      helpUrl: 'https://appleid.apple.com/',
      webUrl: 'https://www.icloud.com/mail',
    ),
    MailProvider(
      id: 'outlook',
      name: 'Outlook',
      host: 'outlook.office365.com',
      domains: ['outlook.com', 'hotmail.com', 'live.com'],
      hint:
          'Microsoft для личных адресов часто требует вход через OAuth, поэтому вход по паролю может не сработать.',
      webUrl: 'https://outlook.live.com/mail/',
    ),
    MailProvider(
      id: 'other',
      name: 'Другая',
      host: '',
      hint: 'Укажи адрес IMAP-сервера своей почты (обычно imap.домен).',
    ),
  ];

  static MailProvider providerById(String id) => providers
      .firstWhere((p) => p.id == id, orElse: () => providers.last);

  static MailProvider? providerForEmail(String email) {
    final at = email.lastIndexOf('@');
    if (at < 0) return null;
    final domain = email.substring(at + 1).trim().toLowerCase();
    for (final p in providers) {
      if (p.domains.contains(domain)) return p;
    }
    return null;
  }

  final List<MailAccount> _accounts = [];
  final Map<String, MailBoxState> _boxes = {};
  final Map<String, String> _plain = {}; // расшифрованные пароли только в памяти
  Timer? _poll;
  bool _disposed = false;

  List<MailAccount> get accounts => List.unmodifiable(_accounts);
  List<String> get emails => [for (final a in _accounts) a.email];
  bool get hasAccounts => _accounts.isNotEmpty;

  MailBoxState boxOf(String id) => _boxes.putIfAbsent(id, MailBoxState.new);

  int get totalUnseen {
    var n = 0;
    for (final b in _boxes.values) {
      n += b.unseen ?? 0;
    }
    return n;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }

  static File get _file => File(
      '${AppSettings.dataDir.path}${Platform.pathSeparator}mail_accounts.json');

  Future<void> init() async {
    try {
      final f = _file;
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        if (data is List) {
          for (final e in data) {
            if (e is! Map) continue;
            final id = e['id'];
            final email = e['email'];
            final host = e['host'];
            final user = e['user'];
            final pass = e['pass'];
            if (id is! String ||
                email is! String ||
                host is! String ||
                user is! String ||
                pass is! String) {
              continue;
            }
            _accounts.add(MailAccount(
              id: id,
              email: email,
              providerId: e['provider'] is String ? e['provider'] as String : 'other',
              host: host,
              port: e['port'] is int ? e['port'] as int : 993,
              secure: e['secure'] is bool ? e['secure'] as bool : true,
              username: user,
              encPassword: pass,
              authType: e['auth'] == 'google'
                  ? 'google'
                  : (e['auth'] == 'none' ? 'none' : 'password'),
            ));
          }
        }
      }
    } catch (_) {}
    notifyListeners();
    if (_accounts.isNotEmpty) {
      refreshAll();
    }
    // Раз в 5 минут обновляем число непрочитанных.
    _poll = Timer.periodic(const Duration(minutes: 5), (_) => refreshAll());
  }

  Future<void> _save() async {
    try {
      await AppSettings.dataDir.create(recursive: true);
      await _file.writeAsString(jsonEncode([for (final a in _accounts) a.toJson()]));
    } catch (_) {}
  }

  // ---------- добавление и удаление ----------

  /// Проверяет вход и привязывает почту. Возвращает текст ошибки или null.
  /// Привязывает только адрес: без пароля и без чтения писем.
  /// Адрес предлагается в полях входа на сайтах.
  Future<String?> addAddressOnly(String email) async {
    final mail = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      return 'Проверь адрес почты';
    }
    if (_accounts.any((a) => a.email.toLowerCase() == mail.toLowerCase())) {
      return 'Эта почта уже привязана';
    }
    final p = providerForEmail(mail);
    _accounts.add(MailAccount(
      id: '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(1000)}',
      email: mail,
      providerId: p?.id ?? 'other',
      host: p?.host ?? '',
      port: p?.port ?? 993,
      secure: true,
      username: mail,
      encPassword: '',
      authType: 'none',
    ));
    await _save();
    notifyListeners();
    return null;
  }

  Future<String?> addAccount({
    required String email,
    required String password,
    required String providerId,
    String host = '',
    int port = 993,
    bool secure = true,
    String? username,
  }) async {
    final mail = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      return 'Проверь адрес почты';
    }
    // Пароли приложений показываются с пробелами («abcd efgh ijkl mnop») — убираем их.
    if (providerId != 'other') password = password.replaceAll(RegExp(r'\s'), '');
    if (password.isEmpty) return 'Введи пароль';
    if (providerId == 'gmail' && password.length != 16) {
      return 'Gmail не пускает по обычному паролю от аккаунта. Нужен пароль приложения — он состоит из 16 букв. Создай его по ссылке ниже (нужна включённая двухэтапная проверка).';
    }
    if (_accounts.any((a) =>
        a.email.toLowerCase() == mail.toLowerCase() && a.authType != 'none')) {
      return 'Эта почта уже привязана';
    }

    final provider = providerById(providerId);
    final imapHost = provider.id == 'other' ? host.trim() : provider.host;
    final imapPort = provider.id == 'other' ? port : provider.port;
    final useSsl = provider.id == 'other' ? secure : true;
    if (imapHost.isEmpty) return 'Укажи адрес IMAP-сервера';

    final account = MailAccount(
      id: '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(1000)}',
      email: mail,
      providerId: provider.id,
      host: imapHost,
      port: imapPort,
      secure: useSsl,
      username: (username ?? '').trim().isEmpty ? mail : username!.trim(),
      encPassword: '',
    );

    // Сначала проверяем вход.
    try {
      await _load(account, password);
    } catch (e) {
      return _friendlyError(e, withDetails: true);
    }

    String enc;
    try {
      enc = await SecretStore.protect(password);
    } catch (_) {
      return 'Не удалось безопасно сохранить пароль (нужен Windows PowerShell)';
    }

    final saved = MailAccount(
      id: account.id,
      email: account.email,
      providerId: account.providerId,
      host: account.host,
      port: account.port,
      secure: account.secure,
      username: account.username,
      encPassword: enc,
    );
    // Если раньше был сохранён только адрес — заменяем его полной привязкой.
    _accounts.removeWhere(
        (a) => a.email.toLowerCase() == mail.toLowerCase() && a.authType == 'none');
    _accounts.add(saved);
    _plain[saved.id] = password;
    await _save();
    notifyListeners();
    refresh(saved.id);
    return null;
  }

  /// Вход через Google без пароля: подтверждение в браузере. Возвращает ошибку или null.
  Future<String?> addGoogleAccount() async {
    final cid = settings.googleClientId;
    final secret = settings.googleClientSecret;
    if (cid.isEmpty || secret.isEmpty) {
      return 'Сначала вставь Client ID и Client secret';
    }
    try {
      final r = await GoogleOAuth.signIn(clientId: cid, clientSecret: secret);
      if (_accounts.any((a) =>
          a.email.toLowerCase() == r.email.toLowerCase() && a.authType != 'none')) {
        return 'Эта почта уже привязана';
      }
      final account = MailAccount(
        id: '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(1000)}',
        email: r.email,
        providerId: 'gmail',
        host: 'imap.gmail.com',
        port: 993,
        secure: true,
        username: r.email,
        encPassword: '',
        authType: 'google',
      );
      await _load(account, r.accessToken); // проверяем, что письма читаются
      final enc = await SecretStore.protect(r.refreshToken);
      final saved = MailAccount(
        id: account.id,
        email: account.email,
        providerId: 'gmail',
        host: account.host,
        port: account.port,
        secure: true,
        username: account.username,
        encPassword: enc,
        authType: 'google',
      );
      _accounts.removeWhere((a) =>
          a.email.toLowerCase() == r.email.toLowerCase() && a.authType == 'none');
      _accounts.add(saved);
      _plain[saved.id] = r.refreshToken;
      await _save();
      notifyListeners();
      refresh(saved.id);
      return null;
    } on GoogleOAuthException catch (e) {
      return e.message;
    } catch (e) {
      return _friendlyError(e, withDetails: true);
    }
  }

  Future<void> removeAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    _boxes.remove(id);
    _plain.remove(id);
    await _save();
    notifyListeners();
  }

  // ---------- письма ----------

  Future<void> refreshAll() async {
    for (final a in List.of(_accounts)) {
      await refresh(a.id);
    }
  }

  Future<void> refresh(String id) async {
    MailAccount? a;
    for (final x in _accounts) {
      if (x.id == id) a = x;
    }
    if (a == null || a.authType == 'none') return;
    final box = boxOf(id);
    if (box.loading) return;
    box.loading = true;
    box.error = null;
    notifyListeners();
    try {
      var pass = _plain[id];
      if (pass == null) {
        pass = await SecretStore.unprotect(a.encPassword);
        _plain[id] = pass;
      }
      // Для входа через Google «пароль» — это постоянный токен: меняем его на свежий доступ.
      final secret = a.authType == 'google'
          ? await GoogleOAuth.refresh(
              clientId: settings.googleClientId,
              clientSecret: settings.googleClientSecret,
              refreshToken: pass,
            )
          : pass;
      final r = await _load(a, secret);
      box.items = r.$1;
      box.unseen = r.$2;
      box.updated = DateTime.now();
    } on GoogleOAuthException catch (e) {
      box.error = e.message;
    } catch (e) {
      box.error = _friendlyError(e);
    } finally {
      box.loading = false;
      notifyListeners();
    }
  }

  /// Подключается к серверу и читает последние письма из «Входящих».
  Future<(List<MailItem>, int?)> _load(MailAccount a, String password) async {
    final client = ImapClient(isLogEnabled: false);
    try {
      return await Future(() async {
        await client.connectToServer(a.host, a.port, isSecure: a.secure);
        if (a.authType == 'google') {
          await client.authenticateWithOAuth2(a.username, password);
        } else {
          await client.login(a.username, password);
        }
        final box = await client.selectInbox();
        final res = await client.fetchRecentMessages(messageCount: 15);
        final items = <MailItem>[];
        for (final m in res.messages.reversed) {
          items.add(_toItem(m));
        }
        return (items, box.messagesUnseen);
      }).timeout(const Duration(seconds: 30));
    } finally {
      try {
        await client.logout();
      } catch (_) {}
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  static MailItem _toItem(MimeMessage m) {
    final from = (m.from != null && m.from!.isNotEmpty) ? m.from!.first : null;
    var text = m.decodeTextPlainPart();
    if (text == null || text.trim().isEmpty) {
      final html = m.decodeTextHtmlPart();
      text = html == null ? '' : _stripHtml(html);
    }
    text = text.trim();
    if (text.length > 20000) text = '${text.substring(0, 20000)}…';
    return MailItem(
      fromName: from?.personalName ?? '',
      fromEmail: from?.email ?? '',
      subject: (m.decodeSubject() ?? '').trim().isEmpty
          ? '(без темы)'
          : m.decodeSubject()!.trim(),
      date: m.decodeDate(),
      seen: m.isSeen,
      body: text,
      hasAttachments: m.hasAttachments(),
    );
  }

  static String _stripHtml(String html) {
    var t = html
        .replaceAll(RegExp(r'<(style|script)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|tr|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    return t.trim();
  }

  static String _details(Object e) {
    var t = e.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > 160) t = '${t.substring(0, 160)}…';
    return '\n\nОтвет сервера: $t';
  }

  static String _friendlyError(Object e, {bool withDetails = false}) {
    if (e is TimeoutException) {
      return 'Сервер не отвечает. Проверь интернет и повтори.';
    }
    final d = withDetails ? _details(e) : '';
    if (e is SocketException || e is HandshakeException) {
      return 'Не удалось подключиться к почтовому серверу$d';
    }
    final s = e.toString().toLowerCase();
    if (s.contains('auth') ||
        s.contains('login') ||
        s.contains('password') ||
        s.contains('credentials') ||
        s.contains('invalid') ||
        s.contains('no ')) {
      return 'Сервер не принял логин или пароль. Скорее всего, нужен пароль приложения и включённый IMAP.$d';
    }
    return 'Не удалось получить письма$d';
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

class GoogleOAuthException implements Exception {
  GoogleOAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class GoogleSignIn {
  const GoogleSignIn({
    required this.email,
    required this.accessToken,
    required this.refreshToken,
  });
  final String email;
  final String accessToken;
  final String refreshToken;
}

/// Вход через Google без пароля: страница входа Google открывается в обычном
/// браузере (там же двухэтапная проверка), а Zembo получает доступ к почте.
class GoogleOAuth {
  GoogleOAuth._();

  static const _scope = 'https://mail.google.com/ email';

  static final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  static String _random(int bytes) {
    final r = Random.secure();
    final b = List<int>.generate(bytes, (_) => r.nextInt(256));
    return base64UrlEncode(b).replaceAll('=', '');
  }

  static Future<void> _openInSystemBrowser(String url) async {
    // Google запрещает вход во встроенных окнах, поэтому — системный браузер.
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else {
      await Process.run('xdg-open', [url]);
    }
  }

  static Future<Map<String, dynamic>> _postForm(
      String url, Map<String, String> form) async {
    final req = await _http.postUrl(Uri.parse(url));
    req.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    req.write(Uri(queryParameters: form).query);
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await res.transform(utf8.decoder).join();
    final data = jsonDecode(body);
    if (res.statusCode != 200) {
      final err = data is Map ? (data['error_description'] ?? data['error']) : body;
      throw GoogleOAuthException('Google отклонил запрос: $err');
    }
    return data as Map<String, dynamic>;
  }

  /// Открывает вход Google в браузере и ждёт результат.
  static Future<GoogleSignIn> signIn({
    required String clientId,
    required String clientSecret,
  }) async {
    final verifier = _random(48);
    final challenge = base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _random(16);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}';
    final done = Completer<Map<String, String>>();

    server.listen((req) async {
      final q = req.uri.queryParameters;
      final isResult = q.containsKey('code') || q.containsKey('error');
      req.response.headers.contentType = ContentType.html;
      if (isResult) {
        final ok = q.containsKey('code');
        req.response.write('<!doctype html><meta charset="utf-8">'
            '<title>Zembo</title>'
            '<body style="font-family:sans-serif;background:#000;color:#eee;'
            'text-align:center;padding-top:80px">'
            '<h2>${ok ? 'Готово!' : 'Вход отменён'}</h2>'
            '<p>${ok ? 'Можно закрыть эту вкладку и вернуться в Zembo.' : 'Вернись в Zembo и попробуй ещё раз.'}</p>'
            '</body>');
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
      if (isResult && !done.isCompleted) done.complete(q);
    });

    try {
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': _scope,
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
      });
      await _openInSystemBrowser(authUrl.toString());

      final q = await done.future.timeout(
        const Duration(minutes: 4),
        onTimeout: () =>
            throw GoogleOAuthException('Время ожидания входа истекло'),
      );
      if (q['error'] != null) {
        throw GoogleOAuthException(q['error'] == 'access_denied'
            ? 'Вход отменён'
            : 'Google вернул ошибку: ${q['error']}');
      }
      if (q['state'] != state) {
        throw GoogleOAuthException('Ответ Google не прошёл проверку, повтори вход');
      }

      final tokens = await _postForm('https://oauth2.googleapis.com/token', {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': q['code']!,
        'code_verifier': verifier,
        'redirect_uri': redirect,
        'grant_type': 'authorization_code',
      });
      final access = tokens['access_token'];
      final refresh = tokens['refresh_token'];
      if (access is! String) {
        throw GoogleOAuthException('Google не выдал доступ');
      }
      if (refresh is! String) {
        throw GoogleOAuthException(
            'Google не выдал постоянный доступ. Убери Zembo из «Доступ сторонних приложений» в аккаунте Google и повтори вход.');
      }

      // Адрес почты, в которую вошли.
      final req = await _http.getUrl(
          Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'));
      req.headers.set('Authorization', 'Bearer $access');
      final res = await req.close().timeout(const Duration(seconds: 15));
      final info = jsonDecode(await res.transform(utf8.decoder).join());
      final email = info is Map ? info['email'] : null;
      if (email is! String || email.isEmpty) {
        throw GoogleOAuthException('Не удалось узнать адрес почты');
      }
      return GoogleSignIn(
          email: email, accessToken: access, refreshToken: refresh);
    } finally {
      await server.close(force: true);
    }
  }

  /// Новый короткоживущий токен доступа по сохранённому постоянному.
  static Future<String> refresh({
    required String clientId,
    required String clientSecret,
    required String refreshToken,
  }) async {
    final data = await _postForm('https://oauth2.googleapis.com/token', {
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'grant_type': 'refresh_token',
    });
    final access = data['access_token'];
    if (access is! String) {
      throw GoogleOAuthException('Не удалось обновить доступ к почте');
    }
    return access;
  }
}

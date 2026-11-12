import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Проверка адресов по базе Google Safe Browsing (вредоносные и фишинговые сайты).
/// Нужен бесплатный ключ API; без него репутация — только примерная оценка.
class SafeBrowsing {
  SafeBrowsing._();

  static final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  /// Возвращает адреса из [urls], которые Google считает опасными.
  static Future<Set<String>> check(String key, List<String> urls) async {
    final bad = <String>{};
    for (var i = 0; i < urls.length; i += 400) {
      final end = i + 400 > urls.length ? urls.length : i + 400;
      final chunk = urls.sublist(i, end);

      final uri = Uri.https(
        'safebrowsing.googleapis.com',
        '/v4/threatMatches:find',
        {'key': key},
      );
      final req = await _http.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'client': {'clientId': 'zembo-browser', 'clientVersion': '1.0'},
        'threatInfo': {
          'threatTypes': [
            'MALWARE',
            'SOCIAL_ENGINEERING',
            'UNWANTED_SOFTWARE',
            'POTENTIALLY_HARMFUL_APPLICATION',
          ],
          'platformTypes': ['ANY_PLATFORM'],
          'threatEntryTypes': ['URL'],
          'threatEntries': [
            for (final u in chunk) {'url': u}
          ],
        },
      }));
      final res = await req.close().timeout(const Duration(seconds: 10));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw HttpException('Safe Browsing: ${res.statusCode}');
      }
      final data = jsonDecode(body);
      final matches = data is Map ? data['matches'] : null;
      if (matches is List) {
        for (final m in matches) {
          final t = m is Map ? m['threat'] : null;
          final u = t is Map ? t['url'] : null;
          if (u is String) bad.add(u);
        }
      }
    }
    return bad;
  }
}

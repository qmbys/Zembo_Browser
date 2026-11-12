import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'brave_search.dart';

/// Запасной источник результатов (DuckDuckGo, лёгкая HTML-версия), если
/// Brave Search не отдаёт результаты скрытой странице.
class DdgSearch {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static final _titleRe = RegExp(
      r'<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
      dotAll: true);
  static final _snippetRe = RegExp(
      r'<a[^>]*class="[^"]*result__snippet[^"]*"[^>]*>(.*?)</a>',
      dotAll: true);

  static String _clean(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _target(String href) {
    var h = href.replaceAll('&amp;', '&');
    if (h.startsWith('//')) h = 'https:$h';
    final u = Uri.tryParse(h);
    if (u == null) return null;
    final real = u.queryParameters['uddg'];
    final out = real ?? h;
    return out.startsWith('http') ? out : null;
  }

  static Future<List<SearchResult>> web(String query, {int page = 0}) async {
    // Дальше первой страницы запасной источник не листает.
    if (page > 0) return const [];

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .postUrl(Uri.parse('https://html.duckduckgo.com/html/'))
          .timeout(const Duration(seconds: 12));
      req.headers
        ..set(HttpHeaders.userAgentHeader, _ua)
        ..set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded')
        ..set(HttpHeaders.acceptLanguageHeader, 'ru,en;q=0.8');
      req.write('q=${Uri.encodeQueryComponent(query)}&kl=wt-wt');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw BraveError('Запасной поиск ответил кодом ${res.statusCode}.');
      }
      final html = await res.transform(utf8.decoder).join();

      final titles = _titleRe.allMatches(html).toList();
      final snippets = _snippetRe.allMatches(html).toList();
      final out = <SearchResult>[];
      for (var i = 0; i < titles.length; i++) {
        final t = titles[i];
        final url = _target(t.group(1) ?? '');
        if (url == null) continue;
        final uri = Uri.tryParse(url);
        final host = (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
        if (host.isEmpty || host.endsWith('duckduckgo.com')) continue;

        // Описание — первый сниппет, который идёт после этого заголовка.
        var desc = '';
        final end = i + 1 < titles.length ? titles[i + 1].start : html.length;
        for (final s in snippets) {
          if (s.start > t.end && s.start < end) {
            desc = _clean(s.group(1) ?? '');
            break;
          }
        }

        final path = (uri?.path ?? '').replaceAll(RegExp(r'/+$'), '');
        out.add(SearchResult(
          title: _clean(t.group(2) ?? ''),
          url: url,
          description: desc,
          host: host,
          crumbs: path.isEmpty ? host : '$host › ${path.replaceFirst('/', '')}',
          favicon: 'https://www.google.com/s2/favicons?sz=64&domain=$host',
        ));
        if (out.length >= 25) break;
      }
      if (out.isEmpty) {
        throw BraveError('Запасной поиск не вернул результатов.');
      }
      return out;
    } on BraveError {
      rethrow;
    } catch (e) {
      throw BraveError('Запасной поиск недоступен: $e');
    } finally {
      client.close(force: true);
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_settings.dart';
import 'history_controller.dart';

class Suggestion {
  const Suggestion({required this.text, this.url, this.subtitle, this.fromHistory = false});

  /// Что подставить в строку.
  final String text;

  /// Адрес для перехода (для записей истории).
  final String? url;
  final String? subtitle;
  final bool fromHistory;
}

/// Подсказки при вводе: записи истории и варианты от выбранной поисковой системы.
class SuggestService {
  SuggestService(this.settings, this.history);

  final AppSettings settings;
  final HistoryController history;

  HttpClient? _client;

  HttpClient get _http => _client ??= HttpClient()
    ..findProxy = ((_) => 'DIRECT')
    ..connectionTimeout = const Duration(seconds: 4)
    ..idleTimeout = const Duration(seconds: 20);

  /// Сколько подсказок показывать максимум.
  static const int maxSuggestions = 3;

  Future<List<Suggestion>> suggest(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final out = <Suggestion>[];
    for (final e in history.search(q, limit: 1)) {
      out.add(Suggestion(
        text: e.url,
        url: e.url,
        subtitle: e.title.isEmpty ? null : e.title,
        fromHistory: true,
      ));
    }

    var remote = await _fetch(_endpoint(q));
    // Если выбранная система не ответила (или это Zembo Search), берём подсказки DuckDuckGo.
    if (remote.isEmpty) remote = await _fetch(_ddg(q));
    for (final s in remote) {
      if (out.length >= maxSuggestions) break;
      if (out.any((o) => o.text.toLowerCase() == s.toLowerCase())) continue;
      out.add(Suggestion(text: s));
    }
    return out.take(maxSuggestions).toList();
  }

  Uri _ddg(String q) =>
      Uri.parse('https://duckduckgo.com/ac/?q=${Uri.encodeQueryComponent(q)}&type=list');

  Uri? _endpoint(String q) {
    final e = Uri.encodeQueryComponent(q);
    switch (settings.searchEngine) {
      case 'Google':
        return Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&q=$e');
      case 'Bing':
        return Uri.parse('https://api.bing.com/osjson.aspx?query=$e');
      case 'Яндекс':
        return Uri.parse('https://suggest.yandex.ru/suggest-ff.cgi?part=$e&uil=ru');
      default:
        return _ddg(q);
    }
  }

  Future<List<String>> _fetch(Uri? uri) async {
    try {
      if (uri == null) return [];
      final req = await _http.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36');
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return [];
      }
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data is List && data.length > 1 && data[1] is List) {
        return (data[1] as List).whereType<String>().take(8).toList();
      }
    } catch (_) {}
    return [];
  }

  void dispose() => _client?.close(force: true);
}

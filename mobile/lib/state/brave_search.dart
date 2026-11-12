import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_settings.dart';

class SearchResult {
  const SearchResult({
    required this.title,
    required this.url,
    this.description = '',
    this.host = '',
    this.crumbs = '',
    this.favicon,
    this.thumb,
    this.date,
    this.imageUrl,
    this.duration,
    this.creator,
  });

  final String title;
  final String url;
  final String description;
  final String host;

  /// Адрес в виде «хост › путь».
  final String crumbs;
  final String? favicon;
  final String? thumb;

  /// Дата публикации (уже в виде «дд.мм.гггг»), если известна.
  final String? date;

  /// Полноразмерная картинка (для вкладки «Изображения»).
  final String? imageUrl;

  /// Для видео: длительность («12:34») и автор канала.
  final String? duration;
  final String? creator;
}

class BraveError implements Exception {
  BraveError(this.message);
  final String message;
}

/// Состояние страницы результатов в одной вкладке.
class SearchSession {
  SearchSession(this.query);

  final String query;
  String category = 'web'; // web | news | images
  final Map<String, List<SearchResult>> results = {};
  final Map<String, bool> loading = {};
  final Map<String, String?> error = {};
  int webPage = 0;
  bool webHasMore = true;
  int videoPage = 0;
  bool videosHasMore = true;

  /// Сколько картинок показано (остальные открываются кнопкой «Показать ещё»).
  int imagesShown = 40;
}

/// Brave Search API (нужен личный ключ из https://brave.com/search/api/).
class BraveSearchApi {
  BraveSearchApi(this.settings);

  final AppSettings settings;
  HttpClient? _client;

  HttpClient get _http => _client ??= HttpClient()
    ..findProxy = ((_) => 'DIRECT')
    ..connectionTimeout = const Duration(seconds: 8)
    ..idleTimeout = const Duration(seconds: 20);

  void dispose() => _client?.close(force: true);

  static final _cyrillic = RegExp(r'[а-яА-ЯёЁіїєґІЇЄҐ]');

  Map<String, String> _lang(String q) {
    if (_cyrillic.hasMatch(q)) {
      return {'search_lang': 'ru', 'ui_lang': 'ru-RU'};
    }
    return {};
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final key = settings.braveApiKey.trim();
    if (key.isEmpty) throw BraveError('Не указан ключ Brave Search API.');

    final uri = Uri.https('api.search.brave.com', '/res/v1/$path', params);
    final req = await _http.getUrl(uri);
    req.headers.set('Accept', 'application/json');
    req.headers.set('X-Subscription-Token', key);
    final res = await req.close().timeout(const Duration(seconds: 12));
    final body = await res.transform(utf8.decoder).join();

    switch (res.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw BraveError('Ключ Brave Search API не подошёл. Проверьте его в настройках.');
      case 422:
        throw BraveError('Brave Search не принял запрос или ключ.');
      case 429:
        throw BraveError('Превышен лимит запросов Brave Search API.');
      default:
        throw BraveError('Ошибка Brave Search (${res.statusCode}).');
    }

    final data = jsonDecode(body);
    if (data is Map<String, dynamic>) return data;
    throw BraveError('Неожиданный ответ Brave Search.');
  }

  // ---------- разбор ----------

  static String _clean(dynamic v) {
    if (v is! String) return '';
    return v
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

  static String? _date(dynamic v) {
    if (v is! String) return null;
    final d = DateTime.tryParse(v);
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  List<SearchResult> _parse(dynamic list) {
    final out = <SearchResult>[];
    if (list is! List) return out;
    for (final e in list) {
      if (e is! Map) continue;
      final url = e['url'];
      final title = _clean(e['title']);
      if (url is! String || title.isEmpty) continue;

      final meta = e['meta_url'];
      var host = '';
      var path = '';
      String? favicon;
      if (meta is Map) {
        host = (meta['hostname'] is String ? meta['hostname'] as String : '')
            .replaceFirst('www.', '');
        path = meta['path'] is String ? (meta['path'] as String).trim() : '';
        favicon = _str(meta['favicon']);
      }
      if (host.isEmpty) host = (Uri.tryParse(url)?.host ?? '').replaceFirst('www.', '');

      final th = e['thumbnail'];
      final props = e['properties'];
      final video = e['video'];

      out.add(SearchResult(
        title: title,
        url: url,
        description: _clean(e['description']),
        host: host,
        crumbs: path.isEmpty ? host : '$host $path',
        favicon: favicon,
        thumb: th is Map ? _str(th['src']) : null,
        date: _date(e['page_age']),
        imageUrl: props is Map ? _str(props['url']) : null,
        duration: video is Map ? _str(video['duration']) : null,
        creator: video is Map
            ? (_str(video['creator']) ?? _str(video['publisher']))
            : null,
      ));
    }
    return out;
  }

  // ---------- запросы ----------

  Future<List<SearchResult>> web(String q, {int page = 0}) async {
    final data = await _get('web/search', {
      'q': q,
      'count': '20',
      'offset': '$page',
      'safesearch': 'moderate',
      'text_decorations': 'false',
      ..._lang(q),
    });
    final web = data['web'];
    return _parse(web is Map ? web['results'] : null);
  }

  Future<List<SearchResult>> news(String q) async {
    final data = await _get('news/search', {
      'q': q,
      'count': '20',
      'safesearch': 'moderate',
      'text_decorations': 'false',
      ..._lang(q),
    });
    return _parse(data['results']);
  }

  Future<List<SearchResult>> videos(String q, {int page = 0}) async {
    final data = await _get('videos/search', {
      'q': q,
      'count': '20',
      'offset': '$page',
      'safesearch': 'moderate',
      ..._lang(q),
    });
    return _parse(data['results']);
  }

  Future<List<SearchResult>> images(String q) async {
    final data = await _get('images/search', {
      'q': q,
      'count': '200',
      'safesearch': 'moderate',
      ..._lang(q),
    });
    return _parse(data['results']);
  }
}

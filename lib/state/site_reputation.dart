import 'brave_search.dart';

/// Примерная репутация сайта (0–100) и приоритет доверенных сайтов в выдаче.
///
/// Это локальная оценка: список известных надёжных сайтов + простые признаки
/// (https, зона домена, подозрительные слова). Она не заменяет настоящую
/// проверку безопасности.
class SiteReputation {
  SiteReputation._();

  /// Сайт считается «доверенным» и поднимается в выдаче, если оценка не ниже.
  static const int trustedFrom = 85;

  static const Map<String, int> _known = {
    // Энциклопедии, справка, наука
    'wikipedia.org': 97, 'wikimedia.org': 96, 'britannica.com': 92,
    'stackoverflow.com': 94, 'stackexchange.com': 92, 'w3.org': 96,
    'mozilla.org': 96, 'python.org': 96, 'flutter.dev': 96, 'dart.dev': 96,
    'github.com': 95, 'gitlab.com': 92, 'npmjs.com': 92, 'docker.com': 92,
    'habr.com': 90, 'imdb.com': 90, 'kinopoisk.ru': 88,
    // Крупные компании и сервисы
    'google.com': 96, 'youtube.com': 94, 'microsoft.com': 96,
    'live.com': 94, 'outlook.com': 94, 'office.com': 94, 'apple.com': 96,
    'icloud.com': 95, 'amazon.com': 93, 'cloudflare.com': 94,
    'dropbox.com': 92, 'proton.me': 94, 'protonmail.com': 94,
    'brave.com': 94, 'duckduckgo.com': 94, 'yandex.com': 90, 'yandex.ru': 90,
    'ya.ru': 90, 'mail.ru': 88, 'vk.com': 86, 'ok.ru': 82, 'dzen.ru': 80,
    'telegram.org': 90, 'whatsapp.com': 90, 'linkedin.com': 92,
    'facebook.com': 84, 'instagram.com': 84, 'x.com': 82, 'twitter.com': 82,
    'reddit.com': 85, 'twitch.tv': 90, 'spotify.com': 92, 'netflix.com': 92,
    // Почта, госуслуги, банки
    'pochta.ru': 92, 'gosuslugi.ru': 95, 'ukr.net': 88, 'privatbank.ua': 93,
    'monobank.ua': 92, 'sberbank.ru': 92, 'tinkoff.ru': 90,
    // Игры
    'minecraft.net': 95, 'mojang.com': 95, 'steampowered.com': 93,
    'epicgames.com': 92, 'curseforge.com': 88, 'modrinth.com': 88,
    // Новости
    'bbc.com': 93, 'bbc.co.uk': 93, 'reuters.com': 93, 'nytimes.com': 90,
    'theguardian.com': 90, 'dw.com': 90, 'pravda.com.ua': 85,
    // Магазины
    'ebay.com': 88, 'rozetka.com.ua': 88, 'olx.ua': 84, 'ozon.ru': 82,
    'wildberries.ru': 80, 'avito.ru': 80, 'aliexpress.com': 80, '2gis.ru': 88,
  };

  static const _badTlds = {
    'xyz', 'top', 'click', 'tk', 'ml', 'ga', 'cf', 'gq', 'icu', 'buzz',
    'work', 'fit', 'cyou', 'rest', 'loan', 'win', 'bid', 'monster',
  };
  static const _goodTlds = {'gov', 'edu', 'mil'};
  static const _badWords = [
    'casino', 'kazino', 'slot', 'jackpot', '1xbet', 'vulkan', 'betking',
    'betting', 'porn', 'xxx', 'torrent', 'crack', 'keygen', 'warez',
    'freemoney', 'free-money', 'bonus',
  ];

  static String _clean(String host) {
    var h = host.toLowerCase().trim();
    if (h.startsWith('www.')) h = h.substring(4);
    return h;
  }

  static String _hostOf(SearchResult r) {
    if (r.host.isNotEmpty) return _clean(r.host.split('/').first);
    return _clean(Uri.tryParse(r.url)?.host ?? '');
  }

  /// Адреса, которые Google Safe Browsing пометил как опасные.
  static final Set<String> flagged = {};

  /// Адреса, которые уже проверены в Safe Browsing (в том числе чистые).
  static final Set<String> checked = {};

  /// Оценка известного сайта или null, если сайта нет в списке.
  static int? _knownScore(String host) {
    final labels = host.split('.');
    // Государственные и учебные сайты (gov, edu, gov.ua, edu.ua …).
    if (_goodTlds.contains(labels.last) ||
        (labels.length >= 2 && _goodTlds.contains(labels[labels.length - 2]))) {
      return 94;
    }
    // Известные сайты: проверяем сам домен и его родителей.
    for (var i = 0; i < labels.length - 1; i++) {
      final v = _known[labels.sublist(i).join('.')];
      if (v != null) return v;
    }
    // Официальные адреса популярных брендов (roblox.com, discord.com …).
    if (_brandByHost(host) != null) return 90;
    return null;
  }

  /// Бренд, чей настоящий адрес совпадает с хостом (youtube.fun сюда не попадёт).
  static _Brand? _brandByHost(String host) {
    for (final b in _brands) {
      final bh = Uri.parse(b.url).host.replaceFirst('www.', '');
      if (host == bh || host.endsWith('.$bh')) return b;
    }
    return null;
  }

  /// Примерная репутация 3–99.
  ///
  /// Высокие значения получают только известные сайты. Сайт, которого нет в
  /// списке, не может получить больше 60%: без настоящей проверки по базе
  /// угроз мы не знаем, безопасен ли он.
  static int score(SearchResult r) {
    final host = _hostOf(r);
    if (host.isEmpty) return 30;
    if (flagged.contains(r.url)) return 3;

    final known = _knownScore(host);
    if (known != null) return known;

    final labels = host.split('.');
    var s = 38;
    s += r.url.startsWith('https://') ? 6 : -10;
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) s -= 20;
    if (host.contains('xn--')) s -= 10;
    if (labels.length >= 5) s -= 8;
    if (host.length > 30) s -= 6;
    final tld = labels.last;
    if (_badTlds.contains(tld)) s -= 22;
    if (tld == 'org') s += 3;
    for (final w in _badWords) {
      if (host.contains(w)) {
        s -= 35;
        break;
      }
    }
    if ('-'.allMatches(host).length >= 3) s -= 8;
    final digits = host.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digits >= 4) s -= 8;
    // Google проверил адрес и угроз не нашёл.
    if (checked.contains(r.url)) s += 14;
    return s.clamp(3, 60);
  }

  /// Подсказка к значку репутации.
  static String note(SearchResult r) {
    if (flagged.contains(r.url)) {
      return 'Google Safe Browsing пометил этот адрес как опасный';
    }
    final host = _hostOf(r);
    if (host.isNotEmpty && _knownScore(host) != null) {
      return 'Известный сайт: примерная репутация по списку';
    }
    if (checked.contains(r.url)) {
      return 'Google Safe Browsing угроз не нашёл, но сайт не из списка известных';
    }
    return 'Сайт не из списка известных и не проверен: оценка осторожная';
  }

  static bool isTrusted(SearchResult r) => score(r) >= trustedFrom;

  /// Ролики YouTube показываются только во вкладке «Видео».
  /// Главная страница, каналы и т. п. — не ролики, их оставляем.
  static bool isYoutube(SearchResult r) {
    final h = _hostOf(r);
    final u = Uri.tryParse(r.url);
    final path = u?.path ?? '';
    if (h == 'youtu.be') return path.length > 1;
    final yt = h == 'youtube.com' ||
        h.endsWith('.youtube.com') ||
        h == 'youtube-nocookie.com' ||
        h.endsWith('.youtube-nocookie.com');
    if (!yt) return false;
    return path.startsWith('/watch') ||
        path.startsWith('/shorts') ||
        path.startsWith('/live') ||
        path.startsWith('/embed') ||
        path.startsWith('/playlist') ||
        path.startsWith('/v/') ||
        (u?.queryParameters.containsKey('v') ?? false);
  }

  /// Магазины приложений в обычной выдаче не нужны — только если их ищут.
  static const _storeHosts = {
    'play.google.com',
    'apps.apple.com',
    'itunes.apple.com',
    'apps.microsoft.com',
    'appgallery.huawei.com',
    'galaxystore.samsung.com',
  };
  static const _storeWords = {
    'play', 'store', 'appstore', 'googleplay', 'itunes', 'плей', 'маркет',
    'стор', 'аппстор', 'гуглплей', 'appgallery', 'galaxy',
  };

  static List<SearchResult> withoutStores(
      List<SearchResult> list, String query) {
    if (_words(query).any(_storeWords.contains)) return list;
    return [for (final r in list) if (!_storeHosts.contains(_hostOf(r))) r];
  }

  static List<SearchResult> withoutYoutube(List<SearchResult> list) =>
      [for (final r in list) if (!isYoutube(r)) r];

  // ---------- официальные сайты ----------

  static const _cyr = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'ґ': 'g', 'д': 'd', 'е': 'e',
    'ё': 'e', 'є': 'e', 'ж': 'zh', 'з': 'z', 'и': 'i', 'і': 'i', 'ї': 'i',
    'й': 'i', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p',
    'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'h', 'ц': 'c',
    'ч': 'ch', 'ш': 'sh', 'щ': 'sh', 'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e',
    'ю': 'yu', 'я': 'ya',
  };

  static String _translit(String s) {
    final t = s.toLowerCase().replaceAll('кс', 'x');
    final b = StringBuffer();
    for (final ch in t.split('')) {
      b.write(_cyr[ch] ?? ch);
    }
    return b.toString();
  }

  static int _distance(String a, String b) {
    if (a == b) return 0;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// Главная часть домена: для `en.help.roblox.com` это `roblox`.
  static String _brandLabel(String host) {
    final l = host.split('.');
    if (l.length < 2) return host;
    const second = {'com', 'co', 'org', 'net', 'gov', 'edu'};
    if (l.length >= 3 && l.last.length == 2 && second.contains(l[l.length - 2])) {
      return l[l.length - 3];
    }
    return l[l.length - 2];
  }

  // Популярные названия (в том числе русские) → официальный сайт.
  static const List<_Brand> _brands = [
    _Brand(['ютуб', 'ютюб', 'ютьюб', 'youtube'], 'youtube',
        'https://www.youtube.com/', 'YouTube'),
    _Brand(['инстаграм', 'инста', 'instagram'], 'instagram',
        'https://www.instagram.com/', 'Instagram'),
    _Brand(['телеграм', 'телега', 'telegram'], 'telegram',
        'https://telegram.org/', 'Telegram'),
    _Brand(['вк', 'вконтакте', 'vk'], 'vk', 'https://vk.com/', 'VK'),
    _Brand(['гугл', 'google'], 'google', 'https://www.google.com/', 'Google'),
    _Brand(['яндекс', 'yandex'], 'yandex', 'https://yandex.ru/', 'Яндекс'),
    _Brand(['дискорд', 'discord'], 'discord', 'https://discord.com/',
        'Discord'),
    _Brand(['тикток', 'tiktok'], 'tiktok', 'https://www.tiktok.com/',
        'TikTok'),
    _Brand(['ватсап', 'вотсап', 'whatsapp'], 'whatsapp',
        'https://www.whatsapp.com/', 'WhatsApp'),
    _Brand(['майнкрафт', 'minecraft'], 'minecraft',
        'https://www.minecraft.net/', 'Minecraft'),
    _Brand(['роблокс', 'roblox'], 'roblox', 'https://www.roblox.com/',
        'Roblox'),
    _Brand(['стим', 'steam'], 'steampowered',
        'https://store.steampowered.com/', 'Steam'),
    _Brand(['твич', 'twitch'], 'twitch', 'https://www.twitch.tv/', 'Twitch'),
    _Brand(['фейсбук', 'facebook'], 'facebook', 'https://www.facebook.com/',
        'Facebook'),
    _Brand(['твиттер', 'twitter'], 'x', 'https://x.com/', 'X (Twitter)'),
    _Brand(['нетфликс', 'netflix'], 'netflix', 'https://www.netflix.com/',
        'Netflix'),
    _Brand(['спотифай', 'spotify'], 'spotify', 'https://www.spotify.com/',
        'Spotify'),
    _Brand(['гитхаб', 'github'], 'github', 'https://github.com/', 'GitHub'),
    _Brand(['википедия', 'wikipedia'], 'wikipedia',
        'https://www.wikipedia.org/', 'Wikipedia'),
    _Brand(['алиэкспресс', 'aliexpress'], 'aliexpress',
        'https://www.aliexpress.com/', 'AliExpress'),
    _Brand(['озон', 'ozon'], 'ozon', 'https://www.ozon.ru/', 'Ozon'),
    _Brand(['вайлдберриз', 'wildberries'], 'wildberries',
        'https://www.wildberries.ru/', 'Wildberries'),
    _Brand(['авито', 'avito'], 'avito', 'https://www.avito.ru/', 'Авито'),
    _Brand(['кинопоиск', 'kinopoisk'], 'kinopoisk',
        'https://www.kinopoisk.ru/', 'Кинопоиск'),
    _Brand(['рутуб', 'rutube'], 'rutube', 'https://rutube.ru/', 'RuTube'),
    _Brand(['дзен', 'dzen'], 'dzen', 'https://dzen.ru/', 'Дзен'),
  ];

  static List<String> _words(String q) => q
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();

  static _Brand? _brandFor(String query) {
    final words = _words(query);
    for (final b in _brands) {
      for (final k in b.keys) {
        if (words.contains(k)) return b;
      }
    }
    return null;
  }

  /// Один сайт — один результат: остаётся первая ссылка с каждого адреса.
  /// [existing] — уже показанные результаты (для «Показать ещё»).
  static List<SearchResult> uniqueHosts(List<SearchResult> list,
      {Iterable<SearchResult> existing = const []}) {
    final seen = <String>{for (final r in existing) _hostOf(r)};
    final out = <SearchResult>[];
    for (final r in list) {
      final h = _hostOf(r);
      if (h.isEmpty || seen.add(h)) out.add(r);
    }
    return out;
  }

  /// Если поиск не вернул сайт из запроса, добавляем его ссылку первой строкой.
  static List<SearchResult> withOfficial(List<SearchResult> list, String query) {
    final b = _brandFor(query);
    if (b == null) return list;
    if (list.any((r) => isOfficial(r, query))) return list;
    final host = Uri.parse(b.url).host.replaceFirst('www.', '');
    return [
      SearchResult(
        title: b.title,
        url: b.url,
        description: 'Официальный сайт',
        host: host,
        crumbs: host,
      ),
      ...list,
    ];
  }

  /// Сайт называется так же, как запрос (roblox → roblox.com, почта → pochta.ru).
  static bool isOfficial(SearchResult r, String query) {
    final q = query.trim();
    if (q.isEmpty) return false;
    final host = _hostOf(r);
    if (host.isEmpty) return false;
    // Сомнительные сайты не считаем официальными, даже если домен похож.
    if (flagged.contains(r.url) || score(r) < 40) return false;

    final label = _brandLabel(host).replaceAll('-', '');

    // Известное название (ютуб → youtube.com).
    final brand = _brandFor(q);
    if (brand != null &&
        label == brand.label &&
        _knownScore(host) != null) {
      return true;
    }

    if (label.length < 3) return false;

    final words = _translit(q)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return false;
    final candidates = <String>{...words, words.join()};

    for (final w in candidates) {
      if (w == label) return true;
      // Опечатки и разная транслитерация.
      if (label.length >= 5 && w.length >= 5) {
        final limit = label.length >= 8 ? 2 : 1;
        if (_distance(label, w) <= limit) return true;
      }
    }
    return false;
  }

  /// Порядок: официальные сайты запроса → доверенные → остальные → подозрительные.
  /// Внутри каждой группы порядок поисковой системы сохраняется.
  static List<SearchResult> prioritize(List<SearchResult> list,
      {String query = ''}) {
    final official = <SearchResult>[];
    final top = <SearchResult>[];
    final mid = <SearchResult>[];
    final low = <SearchResult>[];
    for (final r in list) {
      final s = score(r);
      if (isOfficial(r, query)) {
        official.add(r);
      } else if (s >= trustedFrom) {
        top.add(r);
      } else if (s < 40) {
        low.add(r);
      } else {
        mid.add(r);
      }
    }
    return [...official, ...top, ...mid, ...low];
  }
}

class _Brand {
  const _Brand(this.keys, this.label, this.url, this.title);
  final List<String> keys;
  final String label;
  final String url;
  final String title;
}

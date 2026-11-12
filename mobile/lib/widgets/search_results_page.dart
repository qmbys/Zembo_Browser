import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';
import '../models/browser_tab.dart';
import '../state/brave_search.dart';
import '../state/site_reputation.dart';
import '../state/suggest_service.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';
import 'search_field.dart';
import 'site_icon.dart';

/// Страница результатов Zembo Search (мобильная версия): те же карточки, что и на десктопе.
class SearchResultsPage extends StatelessWidget {
  final BrowserTab tab;
  final TabsController tabs;
  final SuggestService suggest;
  const SearchResultsPage({
    super.key,
    required this.tab,
    required this.tabs,
    required this.suggest,
  });

  static const _categories = <String, String>{
    'web': 'Все',
    'news': 'Новости',
    'images': 'Изображения',
    'videos': 'Видео',
  };

  void _open(String url) => tabs.open(url, tab: tab);

  void _longPress(BuildContext context, String url) {
    if (url.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Открыть в новой вкладке'),
              onTap: () {
                Navigator.pop(ctx);
                tabs.newTab(url: url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать ссылку'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = tab.search!;
    final cat = s.category;
    final items = s.results[cat] ?? const <SearchResult>[];
    final loading = s.loading[cat] == true;
    final error = s.error[cat];

    // Список строится лениво: карточки создаются только когда они попадают на экран.
    const side = EdgeInsets.symmetric(horizontal: 16);
    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchField(
                key: ValueKey('results-field-${tab.id}-${s.query}'),
                initialText: s.query,
                service: suggest,
                onSubmit: (v) => tabs.open(v, tab: tab),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final e in _categories.entries)
                      _CategoryTab(
                        label: e.value,
                        selected: cat == e.key,
                        onTap: () => tabs.setSearchCategory(tab, e.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    if (error != null) {
      slivers.add(SliverPadding(
        padding: side,
        sliver: SliverToBoxAdapter(
          child: _ErrorCard(
            message: error,
            onBrave: () => tabs.openSearchOnBrave(tab),
          ),
        ),
      ));
    } else if (loading && items.isEmpty) {
      slivers.add(const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.orange),
            ),
          ),
        ),
      ));
    } else if (items.isEmpty) {
      slivers.add(const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 48, left: 20),
          child: Text('Ничего не найдено',
              style: TextStyle(fontSize: 14, color: AppColors.muted)),
        ),
      ));
    } else if (cat == 'images') {
      final shown = items.length < s.imagesShown ? items.length : s.imagesShown;
      slivers.add(SliverPadding(
        padding: side,
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1 / 0.78,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final r = items[i];
              return _ImageTile(
                result: r,
                onTap: () => _open(r.url.isNotEmpty ? r.url : (r.thumb ?? '')),
                onLongPress: () => _longPress(context, r.url),
              );
            },
            childCount: shown,
            addAutomaticKeepAlives: false,
          ),
        ),
      ));
    } else {
      slivers.add(SliverPadding(
        padding: side,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final r = items[i];
              if (cat == 'videos') {
                return _VideoCard(
                  result: r,
                  onTap: () => _open(r.url),
                  onLongPress: () => _longPress(context, r.url),
                );
              }
              return _ResultRow(
                result: r,
                compact: cat == 'web',
                official: SiteReputation.isOfficial(r, s.query),
                onTap: () => _open(r.url),
                onLongPress: () => _longPress(context, r.url),
              );
            },
            childCount: items.length,
            addAutomaticKeepAlives: false,
          ),
        ),
      ));
    }

    VoidCallback? onMore;
    if (items.isNotEmpty) {
      if (cat == 'web' && s.webHasMore) {
        onMore = () => tabs.loadMoreWeb(tab);
      } else if (cat == 'videos' && s.videosHasMore) {
        onMore = () => tabs.loadMoreVideos(tab);
      } else if (cat == 'images' && items.length > s.imagesShown) {
        onMore = () => tabs.showMoreImages(tab);
      }
    }

    slivers.add(SliverToBoxAdapter(
      child: Column(
        children: [
          if (onMore != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: OutlinedButton(
                  onPressed: loading ? null : onMore,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.foreground,
                    side: const BorderSide(color: Color(0xFF2A3036)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  ),
                  child: Text(loading ? 'Загрузка…' : 'Показать ещё'),
                ),
              ),
            ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 28),
              child: Center(
                child: Text(
                    tabs.settings.searchSource == 'duckduckgo'
                        ? 'Результаты: DuckDuckGo'
                        : 'Результаты: Brave Search',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF5B646D))),
              ),
            ),
        ],
      ),
    ));

    return CustomScrollView(slivers: slivers);
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.field : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? AppColors.orange : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: selected ? AppColors.foreground : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

/// Карточка результата.
class _ResultCard extends StatelessWidget {
  final SearchResult result;
  final bool compact;
  final bool official;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ResultCard({
    required this.result,
    required this.compact,
    required this.official,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final meta = [if (r.date != null) r.date!].join(' · ');
    final score = SiteReputation.score(r);
    final desc = compact ? _brief(r, official: official) : _shorten(r.description);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF171B20)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: SiteIcon(
                        url: r.url,
                        label: r.host,
                        iconUrl: r.favicon,
                        size: 18,
                        letterSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.crumbs,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ReputationBadge(score: score),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  r.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: official ? AppColors.orange : AppColors.foreground,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, color: Color(0xFFA7AFB7), height: 1.4),
                  ),
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(meta,
                      style:
                          const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _datePrefix = RegExp(
  r'^(\d+\s+\S+\s+(ago|назад)|[A-Za-zА-Яа-я]+\.?\s+\d{1,2},?\s+\d{4}|\d{1,2}[./]\d{1,2}[./]\d{2,4})\s*[-–—]\s*',
  caseSensitive: false,
);

/// Короткое описание для минималистичной карточки.
String _shorten(String text, {int max = 130}) {
  var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceFirst(_datePrefix, '');
  if (t.length <= max) return t;
  var cut = t.substring(0, max);
  final sp = cut.lastIndexOf(' ');
  if (sp > max * 0.6) cut = cut.substring(0, sp);
  cut = cut.replaceAll(RegExp(r'[\s,;:.\-–—]+$'), '');
  return '$cut…';
}

const _socialBrands = <String, String>{
  'youtube': 'YouTube',
  'youtu': 'YouTube',
  'tiktok': 'TikTok',
  'instagram': 'Instagram',
  'facebook': 'Facebook',
  'twitter': 'X',
  'x': 'X',
  'vk': 'VK',
  't': 'Telegram',
  'telegram': 'Telegram',
  'twitch': 'Twitch',
  'rutube': 'RuTube',
  'dzen': 'Дзен',
  'ok': 'OK',
  'reddit': 'Reddit',
  'pinterest': 'Pinterest',
  'linkedin': 'LinkedIn',
};

/// Тексты на арабском, китайском и других письменностях (не латиница и не кириллица).
bool _mostlyForeign(String t) {
  var letters = 0, foreign = 0;
  for (final c in t.runes) {
    final isLatin = (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A) ||
        (c >= 0xC0 && c <= 0x24F);
    final isCyr = c >= 0x400 && c <= 0x4FF;
    final isOther = (c >= 0x370 && c <= 0x3FF) || // греческий
        (c >= 0x590 && c <= 0x6FF) || // иврит, арабский
        (c >= 0x750 && c <= 0x77F) ||
        (c >= 0x900 && c <= 0xDFF) || // индийские письменности
        (c >= 0xE00 && c <= 0xEFF) || // тайский, лаосский
        (c >= 0x3040 && c <= 0x30FF) || // японская кана
        (c >= 0x4E00 && c <= 0x9FFF) || // иероглифы
        (c >= 0xAC00 && c <= 0xD7AF); // корейский
    if (isLatin || isCyr) letters++;
    if (isOther) {
      letters++;
      foreign++;
    }
  }
  return letters > 0 && foreign / letters > 0.3;
}

/// Очень короткое описание (3–4 слова) для минималистичной карточки.
String _brief(SearchResult r, {required bool official}) {
  final host = r.host.toLowerCase().replaceFirst('www.', '');
  final parts = host.split('.');
  final label = parts.length >= 2 ? parts[parts.length - 2] : host;
  final social = _socialBrands[label];
  final path = Uri.tryParse(r.url)?.path ?? '';
  final isRoot = path.isEmpty || path == '/';

  // Главная страница известного сайта.
  if (official && isRoot) return 'Официальный сайт';

  // Каналы и профили в соцсетях: длинные описания не нужны.
  if (social != null && !isRoot) return '$social channel';

  var t = r.description.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceFirst(_datePrefix, '');
  if (t.isEmpty || _mostlyForeign(t)) {
    return social != null ? '$social channel' : '';
  }

  // Первое предложение, не больше 4 слов.
  final sentence = t.split(RegExp(r'(?<=[.!?])\s')).first;
  final words = sentence.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length <= 4) {
    return sentence.replaceAll(RegExp(r'[.\s]+$'), '');
  }
  final cut = words.take(4).join(' ').replaceAll(RegExp(r'[\s,;:.\-–—]+$'), '');
  return '$cut…';
}

/// Строка результата: карточка + картинка с виньеткой справа (как на десктопе).
class _ResultRow extends StatelessWidget {
  final SearchResult result;
  final bool compact;
  final bool official;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ResultRow({
    required this.result,
    required this.compact,
    required this.official,
    required this.onTap,
    required this.onLongPress,
  });

  static const double thumbSize = 88;

  @override
  Widget build(BuildContext context) {
    final thumb = result.thumb;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ResultCard(
            result: result,
            compact: compact,
            official: official,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
        if (thumb != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: thumbSize,
            height: thumbSize,
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              child: _VignetteImage(url: thumb),
            ),
          ),
        ],
      ],
    );
  }
}

/// Картинка с виньеткой: края плавно уходят в фон.
class _VignetteImage extends StatelessWidget {
  final String url;
  const _VignetteImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: 260,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.9,
                  colors: [
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x99000000),
                    Color(0xFF000000),
                  ],
                  stops: [0.0, 0.42, 0.78, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Оранжевый значок «примерная репутация сайта».
class _ReputationBadge extends StatelessWidget {
  final int score;
  const _ReputationBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 12, color: AppColors.orange),
          const SizedBox(width: 4),
          Text(
            '$score%',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _VideoCard(
      {required this.result, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final by = [
      if (r.creator != null) r.creator!,
      r.host,
      if (r.date != null) r.date!,
    ].where((e) => e.isNotEmpty).join(' · ');

    const w = 128.0, h = 72.0;
    Widget thumb = Container(
      width: w,
      height: h,
      color: const Color(0xFF0E1013),
      child: const Icon(Icons.play_circle_outline,
          size: 30, color: AppColors.muted),
    );
    if (r.thumb != null) {
      thumb = Image.network(
        r.thumb!,
        width: w,
        height: h,
        fit: BoxFit.cover,
        cacheWidth: 300,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: w,
          height: h,
          child: Icon(Icons.play_circle_outline,
              size: 30, color: AppColors.muted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF171B20)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      thumb,
                      if (r.duration != null)
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.duration!,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color: AppColors.foreground),
                      ),
                      if (by.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(by,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.muted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ImageTile({
    required this.result,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.tile,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF171B20)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (r.thumb != null)
                Image.network(
                  r.thumb!,
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.muted),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                    ),
                  ),
                  child: Text(
                    r.host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onBrave;
  const _ErrorCard({required this.message, required this.onBrave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A2326)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 20, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.foreground, height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onBrave,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white),
            child: const Text('Открыть на сайте Brave Search'),
          ),
        ],
      ),
    );
  }
}

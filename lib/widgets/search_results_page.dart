import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';

import '../models/browser_tab.dart';
import '../state/brave_search.dart';
import '../state/page_menu.dart';
import '../state/site_reputation.dart';
import '../state/suggest_service.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';
import '../ui_scale.dart';
import 'search_field.dart';
import 'site_icon.dart';

/// Страница результатов поиска в оформлении Zembo (данные — Brave Search API).
class SearchResultsPage extends StatefulWidget {
  final BrowserTab tab;
  final TabsController tabs;
  final SuggestService suggest;
  const SearchResultsPage({
    super.key,
    required this.tab,
    required this.tabs,
    required this.suggest,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

bool _isSecondary(PointerDownEvent e) =>
    e.kind == PointerDeviceKind.mouse && (e.buttons & kSecondaryMouseButton) != 0;

/// Что находится под курсором при правом щелчке (ставят карточки, читает страница).
class _Pending {
  const _Pending({this.link = '', this.img = '', this.skip = false});
  final String link;
  final String img;
  final bool skip;
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  static const _categories = <String, String>{
    'web': 'Все',
    'news': 'Новости',
    'images': 'Изображения',
    'videos': 'Видео',
  };

  _Pending? _pending;

  BrowserTab get tab => widget.tab;
  TabsController get tabs => widget.tabs;
  SuggestService get suggest => widget.suggest;

  void _mark(_Pending p) => _pending = p;

  /// Правая кнопка мыши: открываем контекстное меню браузера.
  void _onPointerDown(PointerDownEvent e) {
    final p = _pending;
    _pending = null;
    if (!_isSecondary(e) || p?.skip == true) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final pos = box.globalToLocal(e.position);
    final query = tab.search?.query ?? '';
    tabs.showContext(PageContext(
      tabId: tab.id,
      x: pos.dx,
      y: pos.dy,
      page: tabs.settings.searchUrl(query),
      link: p?.link ?? '',
      img: p?.img ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = tab.search!;
    final cat = s.category;
    final items = s.results[cat] ?? const <SearchResult>[];
    final loading = s.loading[cat] == true;
    final error = s.error[cat];

    Widget body;
    if (error != null) {
      body = _ErrorCard(
        message: error,
        onBrave: () => tabs.openSearchOnBrave(tab),
        onSettings: tabs.openSettings,
      );
    } else if (loading && items.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.orange),
          ),
        ),
      );
    } else if (items.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.only(top: 48, left: 4),
        child: Text('Ничего не найдено',
            style: TextStyle(fontSize: 14, color: AppColors.muted)),
      );
    } else if (cat == 'images') {
      body = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in items.take(s.imagesShown))
            _ImageTile(
              result: r,
              onSecondary: () => _mark(_Pending(
                link: r.url,
                img: r.imageUrl ?? r.thumb ?? '',
              )),
              onTap: () => tabs.navigate(r.url.isNotEmpty ? r.url : (r.thumb ?? '')),
            ),
        ],
      );
    } else if (cat == 'videos') {
      body = Column(
        children: [
          for (final r in items)
            _VideoCard(
              result: r,
              onTap: () => tabs.navigate(r.url),
              onSecondary: () => _mark(_Pending(link: r.url)),
            ),
        ],
      );
    } else {
      body = LayoutBuilder(
        builder: (context, box) {
          // На узком окне картинки скрываем, чтобы ничего не выходило за края.
          final thumbs = box.maxWidth >= 820;
          return Column(
            children: [
              for (final r in items)
                _ResultRow(
                  result: r,
                  compact: cat == 'web',
                  official: SiteReputation.isOfficial(r, s.query),
                  showThumb: thumbs,
                  onTap: () => tabs.navigate(r.url),
                  onSecondary: () => _mark(_Pending(link: r.url)),
                  onThumbSecondary: () =>
                      _mark(_Pending(link: r.url, img: r.thumb ?? '')),
                ),
            ],
          );
        },
      );
    }

    // Кнопка «Показать ещё» для каждой вкладки.
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

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: ZoomBox(
        zoom: tab.searchZoom,
        child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 26, 24, 32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 966),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // У строки поиска своё меню (вставить/копировать).
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Listener(
                onPointerDown: (e) {
                  if (_isSecondary(e)) _mark(const _Pending(skip: true));
                },
                child: SearchField(
                  key: ValueKey('results-field-${s.query}'),
                  initialText: s.query,
                  service: suggest,
                  onSubmit: tabs.navigate,
                ),
              ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final e in _categories.entries)
                    _CategoryTab(
                      label: e.value,
                      selected: cat == e.key,
                      onTap: () => tabs.setSearchCategory(tab, e.key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              body,
              if (onMore != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(
                    child: OutlinedButton(
                      onPressed: loading ? null : onMore,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground,
                        side: const BorderSide(color: Color(0xFF2A3036)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                      ),
                      child: Text(loading ? 'Загрузка…' : 'Показать ещё'),
                    ),
                  ),
                  ),
                ),
              if (items.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 22),
                    child: Center(
                      child: Text('Результаты: Brave Search',
                          style: TextStyle(
                              fontSize: 11.5, color: Color(0xFF5B646D))),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}

class _CategoryTab extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.field
                : (_hover ? const Color(0xFF0D0F12) : Colors.transparent),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: sel ? AppColors.orange : Colors.transparent, width: 1),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13.5,
              color: sel ? AppColors.foreground : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatefulWidget {
  final SearchResult result;
  final bool compact;
  final bool official;
  final VoidCallback onTap;
  final VoidCallback onSecondary;
  const _ResultCard({
    required this.result,
    this.compact = false,
    this.official = false,
    required this.onTap,
    required this.onSecondary,
  });

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final meta = [if (r.date != null) r.date!].join(' · ');
    final score = SiteReputation.score(r);
    final desc = widget.compact
        ? _brief(r, official: widget.official)
        : _shorten(r.description);

    return Listener(
      onPointerDown: (e) {
        if (_isSecondary(e)) widget.onSecondary();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hover ? const Color(0xFF14171B) : AppColors.tile,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _hover
                      ? const Color(0xFF2A3036)
                      : const Color(0xFF171B20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ReputationBadge(
                              score: score, note: SiteReputation.note(r)),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        r.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          color:
                              _hover ? AppColors.orange : AppColors.foreground,
                        ),
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          desc,
                          maxLines: widget.compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFFA7AFB7),
                              height: 1.4),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(meta,
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

/// Строка результата: карточка + картинка справа, за рамкой карточки.
class _ResultRow extends StatelessWidget {
  final SearchResult result;
  final bool compact;
  final bool official;
  final bool showThumb;
  final VoidCallback onTap;
  final VoidCallback onSecondary;
  final VoidCallback onThumbSecondary;
  const _ResultRow({
    required this.result,
    required this.compact,
    required this.official,
    required this.showThumb,
    required this.onTap,
    required this.onSecondary,
    required this.onThumbSecondary,
  });

  static const double thumbWidth = 170;
  static const double thumbHeight = 104;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ResultCard(
            result: result,
            compact: compact,
            official: official,
            onTap: onTap,
            onSecondary: onSecondary,
          ),
        ),
        if (showThumb) ...[
          const SizedBox(width: 16),
          SizedBox(
            width: thumbWidth,
            height: thumbHeight,
            child: result.thumb == null
                ? null
                : Listener(
                    onPointerDown: (e) {
                      if (_isSecondary(e)) onThumbSecondary();
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onTap,
                        child: _VignetteImage(url: result.thumb!),
                      ),
                    ),
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
            filterQuality: FilterQuality.medium,
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

/// Оранжевый значок «примерная репутация сайта» в правом верхнем углу карточки.
class _ReputationBadge extends StatelessWidget {
  final int score;
  final String note;
  const _ReputationBadge({required this.score, required this.note});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: note,
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
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
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final VoidCallback onSecondary;
  const _VideoCard({
    required this.result,
    required this.onTap,
    required this.onSecondary,
  });

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final by = [
      if (r.creator != null) r.creator!,
      r.host,
      if (r.date != null) r.date!,
    ].where((e) => e.isNotEmpty).join(' · ');

    Widget thumb = Container(
      width: 176,
      height: 99,
      color: const Color(0xFF0E1013),
      child: const Icon(Icons.play_circle_outline,
          size: 34, color: AppColors.muted),
    );
    if (r.thumb != null) {
      thumb = Image.network(
        r.thumb!,
        width: 176,
        height: 99,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 176,
          height: 99,
          child: Icon(Icons.play_circle_outline,
              size: 34, color: AppColors.muted),
        ),
      );
    }

    return Listener(
      onPointerDown: (e) {
        if (_isSecondary(e)) widget.onSecondary();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _hover ? const Color(0xFF14171B) : AppColors.tile,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _hover
                      ? const Color(0xFF2A3036)
                      : const Color(0xFF171B20)),
            ),
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
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.duration!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          color:
                              _hover ? AppColors.orange : AppColors.foreground,
                        ),
                      ),
                      if (by.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(by,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                      ],
                      if (r.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          r.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFA7AFB7),
                              height: 1.4),
                        ),
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

class _ImageTile extends StatefulWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final VoidCallback onSecondary;
  const _ImageTile({
    required this.result,
    required this.onTap,
    required this.onSecondary,
  });

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Listener(
      onPointerDown: (e) {
        if (_isSecondary(e)) widget.onSecondary();
      },
      child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 190,
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.tile,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _hover ? AppColors.orange : const Color(0xFF171B20)),
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
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined, color: AppColors.muted),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
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
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onBrave;
  final VoidCallback onSettings;
  const _ErrorCard(
      {required this.message, required this.onBrave, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
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
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: onBrave,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white),
                child: const Text('Открыть на сайте Brave Search'),
              ),
              OutlinedButton(
                onPressed: onSettings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  side: const BorderSide(color: Color(0xFF2A3036)),
                ),
                child: const Text('Настройки'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

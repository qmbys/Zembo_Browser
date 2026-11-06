import 'dart:io';

import 'package:flutter/foundation.dart';

import 'strings_en.dart';
import 'strings_uk.dart';

class _Tpl {
  _Tpl(this.re, this.out);
  final RegExp re;
  final String out;
}

/// Язык интерфейса браузера. Строки в коде написаны по-русски: русский — это
/// «оригинал», украинский и английский берутся из словарей (strings_*.dart).
/// Для остальных языков интерфейс показывается по-английски.
class I18n {
  I18n._();

  /// Текущий язык интерфейса: ru, uk или en. Виджеты Text подписаны на него.
  static final ValueNotifier<String> lang = ValueNotifier<String>('ru');

  static final RegExp _cyrillic = RegExp('[А-Яа-яЁёІіЇїЄєҐґ]');
  static final RegExp _slot = RegExp(r'\{n?\}');

  /// Какой язык интерфейса соответствует коду языка из настроек.
  static String resolve(String code) {
    var c = code;
    if (c == 'system') {
      try {
        c = Platform.localeName;
      } catch (_) {
        c = 'en';
      }
    }
    final base = c.split(RegExp('[-_]')).first.toLowerCase();
    if (base == 'ru') return 'ru';
    if (base == 'uk') return 'uk';
    return 'en';
  }

  static void setLanguage(String code) {
    final r = resolve(code);
    if (lang.value != r) {
      _cache['en']!.clear();
      _cache['uk']!.clear();
      lang.value = r;
    }
  }

  static final Map<String, Map<String, String>> _cache = {'en': {}, 'uk': {}};
  static List<_Tpl>? _enTpl;
  static List<_Tpl>? _ukTpl;

  static List<_Tpl> _templates(String code) {
    if (code == 'uk') return _ukTpl ??= _build(kUk);
    return _enTpl ??= _build(kEn);
  }

  static List<_Tpl> _build(Map<String, String> map) {
    final list = <_Tpl>[];
    map.forEach((k, v) {
      if (!k.contains('{')) return;
      final buf = StringBuffer('^');
      var last = 0;
      for (final m in _slot.allMatches(k)) {
        buf.write(RegExp.escape(k.substring(last, m.start)));
        buf.write(m.group(0) == '{n}' ? r'(\d+)' : r'([\s\S]*?)');
        last = m.end;
      }
      buf.write(RegExp.escape(k.substring(last)));
      buf.write(r'$');
      list.add(_Tpl(RegExp(buf.toString()), v));
    });
    // Сначала самые длинные шаблоны: они точнее.
    list.sort((a, b) => b.re.pattern.length.compareTo(a.re.pattern.length));
    return list;
  }

  /// Переводит русскую строку на текущий язык интерфейса.
  static String tr(String s) {
    final code = lang.value;
    if (code == 'ru' || s.isEmpty || !_cyrillic.hasMatch(s)) return s;
    final map = code == 'uk' ? kUk : kEn;
    final hit = map[s];
    if (hit != null) return hit;
    final cache = _cache[code]!;
    final cached = cache[s];
    if (cached != null) return cached;
    var result = s;
    for (final t in _templates(code)) {
      final m = t.re.firstMatch(s);
      if (m == null) continue;
      var i = 0;
      result = t.out.replaceAllMapped(_slot, (slot) {
        i++;
        final g = m.group(i) ?? '';
        return slot.group(0) == '{n}' ? g : tr(g);
      });
      break;
    }
    if (cache.length > 3000) cache.clear();
    cache[s] = result;
    return result;
  }
}

/// Короткая запись: tr('Русская строка').
String tr(String s) => I18n.tr(s);

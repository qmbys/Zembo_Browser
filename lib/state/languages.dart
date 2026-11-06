/// Язык сайтов, доступный в настройках.
class LangInfo {
  const LangInfo(this.code, this.native, this.russian, this.flag);

  /// Код языка (BCP 47): ru, en-US, zh-CN …
  final String code;

  /// Название на самом языке.
  final String native;

  /// Название по-русски.
  final String russian;

  /// Какой флаг нарисовать (см. FlagIcon).
  final String flag;
}

class Languages {
  Languages._();

  /// Значение «как в системе».
  static const system = 'system';

  static const all = <LangInfo>[
    LangInfo('ru', 'Русский', 'Русский', 'ru'),
    LangInfo('uk', 'Українська', 'Украинский', 'ua'),
    LangInfo('en-US', 'English (US)', 'Английский (США)', 'us'),
    LangInfo('en-GB', 'English (UK)', 'Английский (Великобритания)', 'gb'),
    LangInfo('de', 'Deutsch', 'Немецкий', 'de'),
    LangInfo('fr', 'Français', 'Французский', 'fr'),
    LangInfo('es', 'Español', 'Испанский', 'es'),
    LangInfo('it', 'Italiano', 'Итальянский', 'it'),
    LangInfo('pt-BR', 'Português (Brasil)', 'Португальский (Бразилия)', 'br'),
    LangInfo('pl', 'Polski', 'Польский', 'pl'),
    LangInfo('cs', 'Čeština', 'Чешский', 'cz'),
    LangInfo('nl', 'Nederlands', 'Нидерландский', 'nl'),
    LangInfo('sv', 'Svenska', 'Шведский', 'se'),
    LangInfo('fi', 'Suomi', 'Финский', 'fi'),
    LangInfo('ro', 'Română', 'Румынский', 'ro'),
    LangInfo('bg', 'Български', 'Болгарский', 'bg'),
    LangInfo('hu', 'Magyar', 'Венгерский', 'hu'),
    LangInfo('el', 'Ελληνικά', 'Греческий', 'gr'),
    LangInfo('tr', 'Türkçe', 'Турецкий', 'tr'),
    LangInfo('be', 'Беларуская', 'Белорусский', 'by'),
    LangInfo('kk', 'Қазақша', 'Казахский', 'kz'),
    LangInfo('ar', 'العربية', 'Арабский', 'sa'),
    LangInfo('he', 'עברית', 'Иврит', 'il'),
    LangInfo('hi', 'हिन्दी', 'Хинди', 'in'),
    LangInfo('zh-CN', '中文 (简体)', 'Китайский (упрощённый)', 'cn'),
    LangInfo('ja', '日本語', 'Японский', 'jp'),
    LangInfo('ko', '한국어', 'Корейский', 'kr'),
    LangInfo('vi', 'Tiếng Việt', 'Вьетнамский', 'vn'),
    LangInfo('th', 'ไทย', 'Тайский', 'th'),
    LangInfo('id', 'Bahasa Indonesia', 'Индонезийский', 'id'),
  ];

  static LangInfo? byCode(String code) {
    for (final l in all) {
      if (l.code == code) return l;
    }
    return null;
  }

  /// Подходит ли код (защита от мусора в settings.json).
  static bool isKnown(String code) => code == system || byCode(code) != null;
}

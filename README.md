# Zembo_Browser

🇷🇺 Zembo Browser: лёгкий браузер для Windows на Flutter и WebView2 с блокировщиком рекламы, тёмной темой сайтов, менеджером паролей и собственным поиском Zembo Search.

🇬🇧 Zembo Browser: a lightweight Windows browser built with Flutter and WebView2, with an ad blocker, dark mode for sites, a password manager and its own Zembo Search.

<p align="center">
  <img src="windows/runner/resources/zembo_logo.png" width="120" alt="Zembo Browser">
</p>

## Скриншоты

<img width="738" height="456" alt="image" src="https://github.com/user-attachments/assets/e37287ac-420d-41f4-9e5d-d2f89195b741" />

<img width="742" height="456" alt="image" src="https://github.com/user-attachments/assets/39179a7e-1662-44a4-9be2-447040cdef48" />

<img width="742" height="459" alt="image" src="https://github.com/user-attachments/assets/3332a371-8516-48b2-90a0-f8a5ef4d6caf" />

## Возможности

- **Блокировщик рекламы** — сайты и видео YouTube, готовые списки фильтров (HaGeZi), SponsorBlock, скрытие элементов вручную.
- **Три уровня защиты** — отключена, стандартная, строгая (трекеры, вредоносные сайты, «Не отслеживать»).
- **Тёмная тема сайтов** — для всех сайтов, а сайты Google открываются тёмными сразу.
- **Менеджер паролей** — пароли шифруются средствами Windows (DPAPI), подсказка логинов под полем входа.
- **Настройки отдельных сайтов** — cookie, местоположение, микрофон, камера, уведомления.
- **Zembo Search** — собственный поиск на основе Brave Search с оформлением в стиле браузера, оценкой репутации сайтов и вкладками «Все / Новости / Изображения / Видео».
- **Безопасный DNS** (DNS-over-HTTPS), выбор сервера.
- **Картинка в картинке**, полноэкранное видео, плавная прокрутка.
- **Почта** — адреса и чтение писем (IMAP / Google) прямо в браузере.
- **Мои сайты** и ярлыки на стартовой странице, история, загрузки.
- **Интерфейс на русском, украинском и английском.**
- **Браузер по умолчанию** и установщик для Windows.

## Десктоп: постоянное переключение на DuckDuckGo, если Brave не ответил

Если Brave Search не отдал результаты, браузер берёт обычную выдачу с DuckDuckGo и **насовсем** переключается на него (настройка «Источник результатов», вернуть Brave можно вручную).

Источники — только из белого списка (Brave Search, DuckDuckGo), сторонние поисковики не подставляются.

## Изменённые файлы

- `app_settings.dart`
- `tabs_controller.dart`
- `settings_page.dart`
- `search_results_page.dart`
- `strings_en.dart`
- `strings_uk.dart`

## Telegram

Telegram channel with updates: https://t.me/Zembo_apps

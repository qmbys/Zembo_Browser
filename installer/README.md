# Установщик Zembo Browser

1. Установите Inno Setup 6.1+ (https://jrsoftware.org/isdl.php).
2. Из папки проекта выполните:

   powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1

3. Готовый файл: `installer\output\ZemboBrowser-Setup-1.0.0.exe`.

Версия задаётся в `zembo_browser.iss` (`#define AppVersion`) — меняйте её вместе с `version` в `pubspec.yaml`.

Установщик: выбор папки установки, ярлык на рабочем столе, русский/украинский/английский,
установка WebView2 при его отсутствии, удаление через «Приложения» (с вопросом про данные).

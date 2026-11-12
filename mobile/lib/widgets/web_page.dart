import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../i18n/i18n_core.dart';
import '../models/browser_tab.dart';
import '../state/app_keys.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Страница сайта в вкладке (Android WebView).
class WebPage extends StatelessWidget {
  final BrowserTab tab;
  final TabsController tabs;
  const WebPage({super.key, required this.tab, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(tab.url!)),
            initialUserScripts: UnmodifiableListView(tabs.userScripts()),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              // Каждый запрос страницы идёт через Dart — включаем только при блокировщике.
              useShouldInterceptRequest:
                  tabs.settings.adBlock && !tabs.network.active,
              textZoom: (tabs.settings.uiScale * 100).round(),
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
              algorithmicDarkeningAllowed: tabs.settings.darkSites,
              transparentBackground: false,
              preferredContentMode: tab.desktop
                  ? UserPreferredContentMode.DESKTOP
                  : UserPreferredContentMode.RECOMMENDED,
              userAgent: tab.desktop ? TabsController.desktopUa : '',
            ),
            onWebViewCreated: (c) {
              tab.web = c;
              // Скрипт SponsorBlock на YouTube просит отрезки для видео.
              c.addJavaScriptHandler(
                handlerName: 'zemboPw',
                callback: (args) {
                  tabs.passwordMessage(tab, args);
                  return null;
                },
              );
              c.addJavaScriptHandler(
                handlerName: 'zemboSB',
                callback: (args) {
                  tabs.sponsorMessage(tab, args);
                  return null;
                },
              );
            },
            onDownloadStartRequest: (c, req) async {
              final url = req.url.toString();
              if (!url.startsWith('http')) {
                toast('Этот тип загрузки пока не поддерживается');
                return;
              }
              var cookies = '';
              try {
                final list = await CookieManager.instance().getCookies(url: req.url);
                cookies = list.map((e) => '${e.name}=${e.value}').join('; ');
              } catch (_) {}
              tabs.downloads.start(
                url: url,
                suggestedName: req.suggestedFilename,
                mimeType: req.mimeType,
                userAgent: req.userAgent,
                referer: tab.url,
                cookies: cookies,
              );
            },
            onLoadStart: (c, url) => tabs.pageStarted(tab, url?.toString()),
            onLoadStop: (c, url) => tabs.pageFinished(tab, url?.toString()),
            onProgressChanged: (c, p) => tabs.pageProgress(tab, p / 100),
            onTitleChanged: (c, title) => tabs.pageTitle(tab, title),
            onUpdateVisitedHistory: (c, url, isReload) =>
                tabs.pageVisited(tab, url?.toString()),
            onReceivedError: (c, request, error) {
              if (request.isForMainFrame == true) {
                tabs.pageError(tab, '${error.description}\n(${error.type})');
              }
            },
            onEnterFullscreen: (c) => tabs.setFullscreen(true),
            onExitFullscreen: (c) => tabs.setFullscreen(false),
            // Блокировка рекламы и трекеров по спискам фильтров.
            shouldInterceptRequest: (c, request) async {
              if (tabs.shouldBlock(tab, request.url)) {
                return WebResourceResponse(
                  contentType: 'text/plain',
                  contentEncoding: 'utf-8',
                  data: Uint8List(0),
                );
              }
              return null;
            },
            // TODO: разрешения сайтов (камера, микрофон, геолокация) — site_permissions.
            onPermissionRequest: (c, request) async => PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.DENY,
            ),
          ),
        ),
        if (tab.error != null)
          Positioned.fill(
            child: Container(
              color: AppColors.background,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 42, color: AppColors.muted),
                  const SizedBox(height: 14),
                  Text(tr('Не удалось открыть страницу'),
                      style: TextStyle(fontSize: 18, color: AppColors.foreground)),
                  const SizedBox(height: 8),
                  Text(tab.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      tab.error = null;
                      tabs.reload(tab);
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white),
                    child: Text(tr('Повторить')),
                  ),
                ],
              ),
            ),
          ),
        if (tab.loading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: tab.progress > 0 && tab.progress < 1 ? tab.progress : null,
              minHeight: 2,
              color: AppColors.orange,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

import 'dart:convert';

/// Блокировщик рекламы: список доменов, косметические правила и скрипт для страниц.
class AdBlock {
  AdBlock._();

  /// Рекламные и трекерные домены (включая поддомены).
  static const domains = <String>[
    // Google / DoubleClick
    'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
    'googletagservices.com', 'google-analytics.com', 'adservice.google.com',
    '2mdn.net', 'admob.com', 'adsense.google.com',
    // Крупные рекламные сети
    'adnxs.com', 'adsrvr.org', 'rubiconproject.com', 'pubmatic.com',
    'openx.net', 'openx.com', 'casalemedia.com', 'indexww.com',
    'criteo.com', 'criteo.net', 'amazon-adsystem.com', 'adform.net',
    'smartadserver.com', 'advertising.com', 'adtech.com', 'yieldmo.com',
    'sharethrough.com', 'triplelift.com', '33across.com', 'bidswitch.net',
    'contextweb.com', 'lijit.com', 'sovrn.com', 'spotxchange.com',
    'spotx.tv', 'teads.tv', 'teads.com', 'adcolony.com', 'applovin.com',
    'unityads.unity3d.com', 'ads.yahoo.com', 'gemini.yahoo.com',
    'adtechus.com', 'serving-sys.com', 'everesttech.net', 'adroll.com',
    'rlcdn.com', 'bluekai.com', 'krxd.net', 'demdex.net', 'eyeota.net',
    'exelator.com', 'agkn.com', 'tapad.com', 'turn.com', 'mathtag.com',
    'rfihub.com', 'adblade.com', 'adsymptotic.com', 'zedo.com',
    'undertone.com', 'media.net', 'vidoomy.com', 'connatix.com',
    'primis.tech', 'kargo.com', 'nativo.com', 'adsafeprotected.com',
    'moatads.com', 'scorecardresearch.com', 'quantserve.com',
    'quantcount.com', 'adition.com', 'adscale.de', 'adspirit.de',
    'ad.gt', 'adgrx.com', 'adhigh.net', 'adkernel.com', 'admixer.net',
    'adsco.re', 'adspeed.net', 'adtelligent.com', 'adtng.com',
    'advertserve.com', 'bidtheatre.com', 'bttrack.com', 'clickcertain.com',
    'conversantmedia.com', 'cpmstar.com', 'emxdgt.com', 'gumgum.com',
    'imrworldwide.com', 'inmobi.com', 'ipredictive.com', 'lkqd.net',
    'loopme.com', 'mookie1.com', 'nexac.com', 'onetag-sys.com',
    'outbrain.com', 'taboola.com', 'revcontent.com', 'mgid.com',
    'zemanta.com', 'sitescout.com', 'smaato.net', 'stackadapt.com',
    'tidaltv.com', 'tremorhub.com', 'tribalfusion.com', 'viafoura.co',
    'yldbt.com', 'ib-ibi.com', 'adthrive.com', 'mediavine.com',
    'monumetric.com', 'ezoic.net', 'ezoic.com', 'cafemedia.com',
    // Видеореклама (VAST/IMA и видеосети)
    'imasdk.googleapis.com', 'springserve.com', 'freewheel.tv', 'fwmrm.net',
    'tubemogul.com', 'adap.tv', 'stickyadstv.com', 'innovid.com',
    'videoplaza.tv', 'vidazoo.com', 'anyclip.com', 'btrll.com',
    'jwpltx.com', 'brightroll.com', 'extremereach.io', 'bidtellect.com',
    'springserve.com', 'adotmob.com', 'viralize.tv', 'seedtag.com',
    // Всплывающая и «взрослая» реклама
    'popads.net', 'popcash.net', 'propellerads.com', 'exoclick.com',
    'exosrv.com', 'juicyads.com', 'trafficjunky.com', 'adsterra.com',
    'hilltopads.net', 'clickadu.com', 'onclickads.net', 'bidvertiser.com',
    'ad-maven.com', 'admaven.com', 'adcash.com', 'richads.com',
    'evadav.com', 'trafficstars.com', 'tsyndicate.com', 'a-ads.com',
    'coinzilla.com', 'bitmedia.io', 'mellowads.com', 'pushame.com',
    'pushwoosh.com', 'notix.io', 'ero-advertising.com',
    // Трекеры и аналитика поведения
    'hotjar.com', 'mouseflow.com', 'crazyegg.com', 'luckyorange.com',
    'inspectlet.com', 'smartlook.com', 'branch.io', 'adjust.com',
    'appsflyer.com', 'kochava.com', 'bat.bing.com', 'ads.linkedin.com',
    'analytics.tiktok.com', 'ads.tiktok.com', 'ads-twitter.com',
    'static.ads-twitter.com', 'ads.pinterest.com', 'ads.reddit.com',
    // Русскоязычные сети
    'an.yandex.ru', 'yandexadexchange.net', 'adfox.ru', 'adriver.ru',
    'begun.ru', 'ad.mail.ru', 'marketgid.com', 'relap.io',
    'mc.yandex.ru', 'mc.yandex.com', 'tns-counter.ru', 'adlooxtracking.com',
    'bidease.com', 'between.digital', 'buzzoola.com', 'getshop.ru',
    'hybrid.ai', 'mytarget.ru', 'target.my.com', 'soloway.ru',
  ];

  /// Сайты, чья реклама часто встречается в баннерах (букмекеры, казино).
  /// Блокируются только как сторонние ресурсы: на их собственных сайтах всё работает.
  static const thirdPartyDomains = <String>[
    'betking.com.ua', 'betking.com', 'betking.ua', 'vegas.ua', 'vegas.com.ua',
    'parimatch.ua', 'parimatch.com', 'favbet.ua', 'favbet.com', 'betano.ua',
    'vbet.ua', '1xbet.com', '1xbet.ua', 'melbet.com', 'melbet.ua',
    'pin-up.ua', 'pinup.ua', 'pin-up.casino', 'megapari.com', 'mostbet.com',
    'betwinner.com', 'linebet.com', '22bet.com', 'slottica.com',
    'vulkanvegas.com', 'vulkan-vegas.com', 'joycasino.com', 'azino777.ru',
    'leonbets.com', 'betcity.ru', 'fonbet.ru', 'winline.ru', 'olimp.bet',
    'marathonbet.com', 'bet365.com', 'williamhill.com', 'unibet.com',
  ];

  /// Казино и букмекеры: блокируются полностью (и баннеры, и сами сайты).
  static const gamblingDomains = <String>[
    '7k.casino', '7k100.casino', '7k137.casino', '7k676.casino', '7k740.casino',
    'kasino7k-official.info', 'daddycasino841.com', 'move2daddy.com',
    'move2motor.com', 'motorcasino832.com', 'titan-redirect.com',
    'clickboostersredirect.com', 'pin-up.casino', 'pinup.ru', 'mostbet.com',
    'mostbet-ru.com', '1xbet.com', '1x-bet.com', '1xstavka.ru', '1x-slot.com',
    'vulkan-casino.com', 'vulkan-slots.com', 'vulkan-royal.com',
    'vulkan-vegas.com', 'joycasino.com', 'joycasino-official.site',
    'casino-x.com', 'x-casino.com', 'vavada.com', 'vavada-official.site',
    'catcasino.com', 'goxbet.com', 'goxbet24.com', 'pokerdom.com',
    'pokerdom-official.ru', 'parimatch.ru', 'parimatch.com', 'melbet.com',
    'melbet.ru', 'fon.bet', 'fonbet.ru', 'betwinner.com', 'leon.bet',
    'leonbets.ru', 'riobet.com', 'cat-casino.com', 'starda.casino',
    'sol.casino', 'izzi.casino', 'fresh.casino', 'jet.casino', 'drip.casino',
    'monro.casino', 'flagman-casino.com', 'legzo.casino', 'roxbets.com',
    'fastpay-casino.com', 'bitstarz.com', 'slottica.com', 'allrightcasino.com',
    'spinamba.com', 'lucky-bird-casino.com', 'spinbounty.com',
    'supercatcasino.com',
  ];

  /// Дополнительные рекламные сети и трекеры.
  static const extraAdDomains = <String>[
    'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
    'adservice.google.com', 'google-analytics.com', 'an.yandex.ru',
    'mc.yandex.ru', 'adnxs.com', 'criteo.com', 'criteo.net', 'taboola.com',
    'outbrain.com', 'rubiconproject.com', 'pubmatic.com', 'popads.net',
    'popcash.net', 'exoclick.com', 'propellerads.com', 'adsterra.com',
    'mgid.com', 'clickadu.com', 'trafficjunky.com', 'zeropark.com',
    'hilltopads.com', 'richads.com', 'clickaine.com', 'adcash.com',
    'evadav.com', 'monetag.com', 'trafficstar.com', 'app-measurement.com',
    'adjust.com', 'appsflyer.com', 'scorecardresearch.com', 'smartclip.net',
  ];

  /// Все домены для сетевой блокировки (без повторов).
  static List<String> get allDomains =>
      {...domains, ...extraAdDomains, ...gamblingDomains}.toList();

  /// Домены, чьи баннеры-ссылки скрываются на страницах.
  static List<String> get thirdPartyAll =>
      {...thirdPartyDomains, ...gamblingDomains}.toList();

  /// Правила для Chromium: домены не будут находиться в DNS.
  static String get hostResolverRules => allDomains
      .expand((d) => ['MAP $d ~NOTFOUND', 'MAP *.$d ~NOTFOUND'])
      .join(', ');

  /// Скрипт блокировщика. [allowHosts] — сайты, где блокировка отключена.
  static String script(
      List<String> allowHosts, Map<String, List<String>> hidden) {
    final cfg = jsonEncode({
      'block': allDomains,
      'allow': allowHosts,
      'third': thirdPartyAll,
      'hide': hidden,
    });
    return _template.replaceFirst('__CFG__', cfg);
  }

  /// Выключает блокировщик на уже открытой странице.
  static const scriptOff = r'''
(function () {
  var S = window.__zemboAds;
  if (S && S.disable) S.disable();
})();
''';

  static const _template = r'''
(function () {
  var cfg = __CFG__;
  var host = location.hostname;

  function hostMatch(h, list) {
    for (var i = 0; i < list.length; i++) {
      var d = list[i];
      if (h === d || h.endsWith('.' + d)) return true;
    }
    return false;
  }

  // Рекламодатели: блокируем только когда они подгружаются на чужом сайте.
  function isThird(h) {
    for (var i = 0; i < cfg.third.length; i++) {
      var d = cfg.third[i];
      if (h === d || h.endsWith('.' + d)) {
        return !(host === d || host.endsWith('.' + d));
      }
    }
    return false;
  }

  // Правила «скрыть элемент», заданные пользователем для этого сайта.
  function customFor(c) {
    var out = [];
    var h = c.hide || {};
    for (var k in h) {
      if (host === k || host.endsWith('.' + k)) out = out.concat(h[k]);
    }
    return out;
  }

  // Повторный запуск: обновляем правила и включаем уже установленный блокировщик заново.
  if (window.__zemboAds) {
    window.__zemboAds.custom = customFor(cfg);
    if (!hostMatch(host, cfg.allow)) window.__zemboAds.enable();
    return;
  }
  if (hostMatch(host, cfg.allow)) return;

  var S = window.__zemboAds = { off: false, custom: customFor(cfg) };

  // Адреса видеорекламы (VAST/VMAP/IMA) по пути и параметрам запроса.
  var VAST = /(^|[\/._?&=-])(vast|vmap)([\/._?&=-]|$)|\/pubads\b|\/ima3\.js|\/adserver\b|\bvpaid\b/i;

  function blockedUrl(u) {
    try {
      if (!u) return false;
      var url = new URL(String(u), location.href);
      if (hostMatch(url.hostname, cfg.block)) return true;
      if (isThird(url.hostname)) return true;
      return VAST.test(url.pathname + url.search);
    } catch (e) { return false; }
  }

  // ---------- косметические правила ----------
  var CSS = [
    'ins.adsbygoogle', '.adsbygoogle', '[id^="google_ads_"]',
    '[id^="div-gpt-ad"]', '[id^="gpt_unit_"]', 'iframe[id^="google_ads_iframe"]',
    'iframe[src*="doubleclick.net"]', 'iframe[src*="googlesyndication.com"]',
    'iframe[src*="adnxs.com"]', 'iframe[src*="amazon-adsystem.com"]',
    '[data-ad-slot]', '[data-google-query-id]', 'amp-ad', 'amp-embed',
    '.OUTBRAIN', '[id^="taboola-"]', '.trc_rbox_container',
    '[id^="outbrain_widget"]', 'a[href*="doubleclick.net/"]',
    '.ima-ad-container', '.videoAdUi', '.jw-ad-wrapper',
    'a[rel~="sponsored"]', '.adbanner', '.ad-banner', '.banner-ad', '.bannerAd',
    '[class*="adfox" i]', '[id*="adfox" i]', '[class^="ads-"]', '[id^="ads-"]',
    '[class*="advert" i]:not(html):not(body)', '[id*="advert" i]:not(html):not(body)'
  ];
  var HAS = [];
  if (/(^|\.)youtube\.com$/.test(host)) {
    CSS.push('#masthead-ad', 'ytd-ad-slot-renderer', 'ytd-in-feed-ad-layout-renderer',
      'ytd-banner-promo-renderer', 'ytd-statement-banner-renderer', '#player-ads',
      '.ytp-ad-overlay-container', '.ytp-ad-image-overlay', 'ytd-display-ad-renderer',
      'ytd-promoted-sparkles-web-renderer', 'ytd-companion-slot-renderer',
      'ytd-action-companion-ad-renderer', '.video-ads.ytp-ad-module',
      'ytd-video-masthead-ad-v3-renderer', 'ytd-brand-video-singleton-renderer',
      'ytd-brand-video-shelf-renderer', 'ytd-search-pyv-renderer',
      'ytd-promoted-video-renderer', 'ytd-compact-promoted-video-renderer',
      'ytd-player-legacy-desktop-watch-ads-renderer', 'ad-slot-renderer',
      'ytm-promoted-sparkles-web-renderer', '#shorts-inner-container ytd-ad-slot-renderer');
    // Обёртки, в которых лежала реклама: иначе на её месте остаётся пустая клетка.
    // Каждое :has()-правило ставится отдельно, чтобы одно неизвестное не ломало остальные.
    HAS = [
      'ytd-rich-item-renderer:has(ytd-ad-slot-renderer)',
      'ytd-rich-item-renderer:has(ytd-in-feed-ad-layout-renderer)',
      'ytd-rich-item-renderer:has(ytd-display-ad-renderer)',
      'ytd-rich-item-renderer:has(ytd-promoted-sparkles-web-renderer)',
      'ytd-rich-item-renderer:has(ad-slot-renderer)',
      'ytd-rich-item-renderer:has(> #content:empty)',
      'ytd-rich-section-renderer:has(ytd-ad-slot-renderer)',
      'ytd-rich-section-renderer:has(ytd-statement-banner-renderer)',
      'ytd-rich-section-renderer:has(ytd-brand-video-singleton-renderer)',
      'ytd-rich-section-renderer:has(ytd-in-feed-ad-layout-renderer)',
      'ytd-item-section-renderer:has(> #contents > ytd-ad-slot-renderer:only-child)',
      'ytd-item-section-renderer:has(ytd-search-pyv-renderer)',
      'ytd-watch-next-secondary-results-renderer ytd-item-section-renderer:has(ytd-ad-slot-renderer)'];
  }

  function putCss() {
    if (S.off || document.getElementById('zembo-ads-css')) return true;
    var st = document.createElement('style');
    st.id = 'zembo-ads-css';
    var txt = CSS.join(',') + '{display:none!important}';
    // Каждое пользовательское правило отдельно: одно неверное не ломает остальные.
    for (var i = 0; i < S.custom.length; i++) {
      txt += '\n' + S.custom[i] + '{display:none!important}';
    }
    for (var h = 0; h < HAS.length; h++) txt += '\n' + HAS[h] + '{display:none!important}';
    st.textContent = txt;
    var r = document.head || document.documentElement;
    if (!r) return false;
    r.appendChild(st);
    return true;
  }
  if (!putCss()) {
    var mo0 = new MutationObserver(function () { if (putCss()) mo0.disconnect(); });
    mo0.observe(document, { childList: true, subtree: true });
  }

  S.enable = function () {
    S.off = false;
    var old = document.getElementById('zembo-ads-css');
    if (old) old.remove();
    putCss();
    hideAdLinks();
  };

  // Скрываем баннеры-ссылки на сайты рекламодателей (вместе с пустой обёрткой).
  function hideAdLinks() {
    if (S.off || !document.querySelectorAll) return;
    var links = document.querySelectorAll('a[href]');
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      if (a.__zc) continue;
      a.__zc = 1;
      var h;
      try { h = new URL(a.href, location.href).hostname; } catch (e) { continue; }
      if (!isThird(h)) continue;
      a.style.setProperty('display', 'none', 'important');
      S.hidden.push(a);
      var p = a.parentElement;
      if (p && p !== document.body && p !== document.documentElement &&
          p.children.length === 1 && !(p.textContent || '').trim()) {
        p.style.setProperty('display', 'none', 'important');
        p.__zc = 1;
        S.hidden.push(p);
      }
    }
  }
  var hideTimer = null;
  function scheduleHide() {
    clearTimeout(hideTimer);
    hideTimer = setTimeout(hideAdLinks, 400);
  }
  document.addEventListener('DOMContentLoaded', hideAdLinks);
  window.addEventListener('load', hideAdLinks);
  new MutationObserver(scheduleHide).observe(document, { childList: true, subtree: true });
  S.hidden = [];
  S.disable = function () {
    S.off = true;
    var e = document.getElementById('zembo-ads-css');
    if (e) e.remove();
    for (var i = 0; i < S.hidden.length; i++) {
      S.hidden[i].style.removeProperty('display');
      S.hidden[i].__zc = 0;
    }
    S.hidden = [];
  };

  // ---------- блокировка запросов из скриптов страницы ----------
  var oldFetch = window.fetch;
  if (oldFetch) {
    window.fetch = function (input) {
      var u = (typeof input === 'string') ? input : (input && input.url);
      if (!S.off && blockedUrl(u)) return Promise.reject(new TypeError('Failed to fetch'));
      return oldFetch.apply(this, arguments);
    };
  }

  var xhrOpen = XMLHttpRequest.prototype.open;
  var xhrSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) {
    this.__zembo = !S.off && blockedUrl(u);
    return xhrOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    if (this.__zembo) {
      var x = this;
      setTimeout(function () {
        try { x.dispatchEvent(new Event('error')); } catch (e) {}
      }, 0);
      return;
    }
    return xhrSend.apply(this, arguments);
  };

  if (navigator.sendBeacon) {
    var oldBeacon = navigator.sendBeacon;
    navigator.sendBeacon = function (u) {
      if (!S.off && blockedUrl(u)) return true;
      return oldBeacon.apply(navigator, arguments);
    };
  }

  function hookSrc(proto) {
    var d = Object.getOwnPropertyDescriptor(proto, 'src');
    if (!d || !d.set) return;
    Object.defineProperty(proto, 'src', {
      get: d.get,
      set: function (v) {
        if (!S.off && blockedUrl(v)) return;
        d.set.call(this, v);
      },
      configurable: true,
      enumerable: d.enumerable
    });
  }
  hookSrc(HTMLScriptElement.prototype);
  hookSrc(HTMLIFrameElement.prototype);
  hookSrc(HTMLImageElement.prototype);
  hookSrc(HTMLMediaElement.prototype);
  hookSrc(HTMLSourceElement.prototype);

  var oldSetAttr = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function (n, v) {
    if (!S.off && n && String(n).toLowerCase() === 'src' &&
        /^(SCRIPT|IFRAME|IMG|EMBED|SOURCE|VIDEO|AUDIO)$/.test(this.tagName) && blockedUrl(v)) {
      return;
    }
    return oldSetAttr.apply(this, arguments);
  };

  // Убираем уже добавленные в разметку элементы с рекламных доменов.
  function sweep(node) {
    if (S.off || !node || node.nodeType !== 1) return;
    var tag = node.tagName;
    if ((tag === 'SCRIPT' || tag === 'IFRAME' || tag === 'IMG') &&
        blockedUrl(node.getAttribute('src'))) {
      node.remove();
    }
  }
  new MutationObserver(function (muts) {
    for (var i = 0; i < muts.length; i++) {
      var added = muts[i].addedNodes;
      for (var j = 0; j < added.length; j++) sweep(added[j]);
    }
  }).observe(document, { childList: true, subtree: true });

  // ---------- реклама в других видеоплеерах (IMA, JW Player, Video.js и т.п.) ----------
  if (!/(^|\.)youtube\.com$/.test(host)) {
    var AD_CLASS = /(^|\s)(ad-showing|ad-interrupting|ad-playing|vjs-ad-playing|vjs-ad-loading|jw-flag-ads|jw-flag-ads-vpaid|jw-flag-ads-googleima|plyr--ad|ima-ad-container|is-ad-showing|ads-playing|advertising-active)(\s|$)/;
    // Более общие признаки рекламы в классах контейнера плеера (ad-mode, preroll, midroll и т.п.).
    var AD_CLASS2 = /(^|[\s_-])(ad|ads|advert|advertising)[-_]?(showing|playing|active|mode|break|running|overlay|container|video)($|[\s_-])|(^|[\s_-])(pre|mid|post)[-_]?roll/i;
    var SKIP_SEL = '.videoAdUiSkipButton, .jw-skip, [class*="skip-ad" i], [class*="ad-skip" i], [class*="skipAd" i]';

    var adBox = function (v) {
      var el = v, n = 0;
      while (el && n < 7) {
        var c = typeof el.className === 'string' ? el.className : '';
        if (AD_CLASS.test(c) || AD_CLASS2.test(c)) return el;
        el = el.parentElement;
        n++;
      }
      return null;
    };

    setInterval(function () {
      if (S.off) return;
      var vs = document.getElementsByTagName('video');
      for (var i = 0; i < vs.length; i++) {
        var v = vs[i];
        var box = adBox(v);
        if (box) {
          var sk = box.querySelector(SKIP_SEL);
          if (sk) { try { sk.click(); } catch (e) {} }
          if (!v.muted) { v.muted = true; v.__zMuted = true; }
          // Рекламные ролики короткие; длинные видео не трогаем.
          if (isFinite(v.duration) && v.duration > 0 && v.duration < 180) {
            try { v.currentTime = v.duration; } catch (e) {}
          }
          try { v.playbackRate = 16; v.__zFast = true; } catch (e) {}
        } else {
          if (v.__zMuted) { v.muted = false; v.__zMuted = false; }
          if (v.__zFast) { try { v.playbackRate = 1; } catch (e) {} v.__zFast = false; }
        }
      }
    }, 250);
  }

  // ---------- реклама в видео на YouTube ----------
  if (/(^|\.)youtube\.com$/.test(host)) {
    // 1) Вырезаем рекламу из ответов YouTube (как json-prune в uBlock Origin).
    var KEYS = ['adPlacements', 'playerAds', 'adSlots'];
    var prune = function (o, depth) {
      if (!o || typeof o !== 'object' || depth > 3) return;
      for (var i = 0; i < KEYS.length; i++) {
        if (KEYS[i] in o) { try { delete o[KEYS[i]]; } catch (e) {} }
      }
      if (o.playerResponse) prune(o.playerResponse, depth + 1);
      if (o.response) prune(o.response, depth + 1);
      if (Array.isArray(o)) {
        for (var j = 0; j < o.length && j < 5; j++) prune(o[j], depth + 1);
      }
    };

    var oldParse = JSON.parse;
    JSON.parse = function () {
      var r = oldParse.apply(this, arguments);
      if (!S.off) prune(r, 0);
      return r;
    };

    if (window.Response && Response.prototype.json) {
      var oldJson = Response.prototype.json;
      Response.prototype.json = function () {
        return oldJson.apply(this, arguments).then(function (r) {
          if (!S.off) prune(r, 0);
          return r;
        });
      };
    }

    try {
      var initial;
      Object.defineProperty(window, 'ytInitialPlayerResponse', {
        configurable: true,
        get: function () { return initial; },
        set: function (v) { if (!S.off) prune(v, 0); initial = v; }
      });
    } catch (e) {}

    // 2) Запасной вариант: если реклама всё же началась — пропускаем её.
    S.mutedByUs = false;
    setInterval(function () {
      if (S.off) return;

      // Окно «блокировщики рекламы запрещены» убираем и продолжаем видео.
      var enf = document.querySelector('ytd-enforcement-message-view-model');
      if (enf) {
        var dlg = enf.closest('tp-yt-paper-dialog') || enf;
        dlg.remove();
        var bd = document.querySelector('tp-yt-iron-overlay-backdrop');
        if (bd) bd.remove();
        var pv = document.querySelector('video');
        if (pv && pv.paused) { try { pv.play(); } catch (e) {} }
      }

      var player = document.querySelector('.html5-video-player');
      var v = document.querySelector('video.html5-main-video') ||
              document.querySelector('video');
      if (!v) return;
      var ad = player && (player.classList.contains('ad-showing') ||
                          player.classList.contains('ad-interrupting'));
      if (ad) {
        var skip = document.querySelector(
          '.ytp-skip-ad-button, .ytp-ad-skip-button, .ytp-ad-skip-button-modern, ' +
          '.ytp-ad-skip-button-container button');
        if (skip) skip.click();
        if (!v.muted) { v.muted = true; S.mutedByUs = true; }
        if (isFinite(v.duration) && v.duration > 0) {
          try { v.currentTime = v.duration; } catch (e) {}
        }
        v.playbackRate = 16;
      } else {
        if (S.mutedByUs) { v.muted = false; S.mutedByUs = false; }
        if (v.playbackRate === 16) v.playbackRate = 1;
      }
    }, 120);
  }
})();
''';
}

/// Перехват скачивания файлов: ссылка на файл не открывается в странице,
/// а передаётся браузеру, который скачивает её сам.
class DownloadScript {
  DownloadScript._();

  static const script = r'''
(function () {
  if (window.top !== window || window.__zemboDl) return;
  window.__zemboDl = true;
  var EXT = /\.(zip|rar|7z|tar|gz|tgz|bz2|xz|exe|msi|dmg|pkg|deb|rpm|apk|iso|img|torrent|docx?|xlsx?|pptx?|csv|jar|appimage)$/i;
  var bypass = false;

  function post(o) {
    try { window.chrome.webview.postMessage(JSON.stringify(o)); } catch (e) {}
  }

  // Любой клик по странице: возможно, сейчас начнётся загрузка файла.
  document.addEventListener('click', function () { post({ type: 'zembo-click' }); }, true);

  document.addEventListener('click', function (ev) {
    if (bypass) { bypass = false; return; }
    if (ev.defaultPrevented || ev.button !== 0 || ev.ctrlKey || ev.shiftKey || ev.metaKey) return;
    var a = ev.target && ev.target.closest ? ev.target.closest('a[href]') : null;
    if (!a) return;
    var href = a.href;
    if (!href) return;
    var hasDl = a.hasAttribute('download');

    if (/^(blob|data):/i.test(href) && hasDl) {
      ev.preventDefault();
      ev.stopPropagation();
      var name = a.getAttribute('download') || 'download';
      fetch(href).then(function (r) { return r.blob(); }).then(function (b) {
        if (b.size > 64 * 1024 * 1024) {
          // Слишком большой файл — отдаём обычной загрузке WebView.
          bypass = true;
          a.click();
          return;
        }
        var fr = new FileReader();
        fr.onload = function () {
          var s = String(fr.result);
          post({ type: 'zembo-dl-data', name: name, data: s.slice(s.indexOf(',') + 1) });
        };
        fr.readAsDataURL(b);
      }).catch(function () { bypass = true; a.click(); });
      return;
    }

    if (!/^https?:/i.test(href)) return;
    var path;
    try { path = new URL(href).pathname; } catch (e) { return; }
    if (hasDl || EXT.test(path)) {
      ev.preventDefault();
      ev.stopPropagation();
      post({ type: 'zembo-dl', url: href, name: a.getAttribute('download') || '', referer: location.href });
    }
  }, true);
})();
''';
}


/// Режим «Скрыть элемент»: пользователь выбирает баннер кликом.
class ElementPicker {
  ElementPicker._();

  static const script = r'''
(function () {
  if (window.top !== window) return;
  if (window.__zemboPick) window.__zemboPick.stop();

  var hl = document.createElement('div');
  hl.style.cssText = 'position:fixed;z-index:2147483647;pointer-events:none;' +
    'border:2px solid #ff5a1f;background:rgba(255,90,31,.18);left:0;top:0;' +
    'width:0;height:0;box-sizing:border-box';
  var tip = document.createElement('div');
  tip.style.cssText = 'position:fixed;z-index:2147483647;top:10px;left:50%;' +
    'transform:translateX(-50%);background:#14171b;color:#fff;font:13px sans-serif;' +
    'padding:8px 14px;border-radius:10px;border:1px solid #ff5a1f;pointer-events:none';
  tip.textContent = 'Нажми на баннер, чтобы скрыть его. Колесо мыши вверх — выбрать блок побольше. Esc — отмена';
  document.documentElement.appendChild(hl);
  document.documentElement.appendChild(tip);

  var cur = null, stack = [];

  function target(e) {
    var el = document.elementFromPoint(e.clientX, e.clientY);
    if (!el || el === hl || el === tip) return null;
    return el;
  }
  function draw() {
    if (!cur) { hl.style.width = '0'; hl.style.height = '0'; return; }
    var r = cur.getBoundingClientRect();
    hl.style.left = r.left + 'px';
    hl.style.top = r.top + 'px';
    hl.style.width = r.width + 'px';
    hl.style.height = r.height + 'px';
  }

  function selectorOf(el) {
    var parts = [];
    var node = el;
    while (node && node.nodeType === 1 && node !== document.documentElement) {
      var s = node.tagName.toLowerCase();
      if (node.id && /^[A-Za-z][\w-]*$/.test(node.id) && !/\d{3,}/.test(node.id)) {
        parts.unshift('#' + CSS.escape(node.id));
        var byId = parts.join(' > ');
        try { if (document.querySelectorAll(byId).length === 1) return byId; } catch (e) {}
        break;
      }
      var cls = [].slice.call(node.classList).filter(function (c) {
        return /^[A-Za-z_-][\w-]*$/.test(c) && c.length < 30 && !/\d{3,}/.test(c);
      }).slice(0, 2);
      if (cls.length) s += '.' + cls.map(function (c) { return CSS.escape(c); }).join('.');
      var p = node.parentElement;
      if (p) {
        var same = [].filter.call(p.children, function (ch) { return ch.tagName === node.tagName; });
        if (same.length > 1) s += ':nth-of-type(' + (same.indexOf(node) + 1) + ')';
      }
      parts.unshift(s);
      var sel = parts.join(' > ');
      try { if (document.querySelectorAll(sel).length === 1) return sel; } catch (e) {}
      node = node.parentElement;
    }
    return parts.join(' > ');
  }

  function block(e) { e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation(); }

  function onMove(e) {
    var t = target(e);
    if (t && t !== cur) { cur = t; stack = []; draw(); }
  }
  function onWheel(e) {
    if (!cur) return;
    e.preventDefault();
    if (e.deltaY < 0) {
      var p = cur.parentElement;
      if (p && p !== document.documentElement && p !== document.body) { stack.push(cur); cur = p; }
    } else if (stack.length) {
      cur = stack.pop();
    }
    draw();
  }
  function onClick(e) {
    block(e);
    if (!cur || cur === document.body || cur === document.documentElement) { stop(); return; }
    var sel = selectorOf(cur);
    cur.style.setProperty('display', 'none', 'important');
    try {
      window.chrome.webview.postMessage(JSON.stringify(
        { type: 'zembo-hide', host: location.hostname, selector: sel }));
    } catch (err) {}
    stop();
  }
  function onKey(e) { if (e.key === 'Escape') stop(); }

  function stop() {
    window.removeEventListener('mousemove', onMove, true);
    window.removeEventListener('wheel', onWheel, true);
    window.removeEventListener('click', onClick, true);
    window.removeEventListener('mousedown', block, true);
    window.removeEventListener('mouseup', block, true);
    window.removeEventListener('pointerdown', block, true);
    window.removeEventListener('keydown', onKey, true);
    hl.remove();
    tip.remove();
    delete window.__zemboPick;
  }

  window.addEventListener('mousemove', onMove, true);
  window.addEventListener('wheel', onWheel, { capture: true, passive: false });
  window.addEventListener('click', onClick, true);
  window.addEventListener('mousedown', block, true);
  window.addEventListener('mouseup', block, true);
  window.addEventListener('pointerdown', block, true);
  window.addEventListener('keydown', onKey, true);
  window.__zemboPick = { stop: stop };
})();
''';
}

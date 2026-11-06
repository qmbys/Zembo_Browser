/// «Картинка в картинке»: страница подстраивается так, что видео занимает всё окно,
/// а браузер показывает эту вкладку в маленьком окошке поверх остальных.
/// Скрипт ставится во все фреймы страницы (видео часто лежит во вложенном плеере).
class PipScript {
  PipScript._();

  static const support = r'''
(function () {
  if (window.__zpipInit) return;
  window.__zpipInit = true;

  var STYLE_ID = 'zembo-pip-style';
  var CSS =
    'html[data-zpip-on],html[data-zpip-on] body{background:#000!important;overflow:hidden!important}' +
    'html[data-zpip-on] body *{visibility:hidden!important}' +
    'html[data-zpip-on] [data-zpip-anc]{transform:none!important;filter:none!important;' +
    'perspective:none!important;contain:none!important;will-change:auto!important;' +
    'clip-path:none!important;overflow:visible!important}' +
    'html[data-zpip-on] [data-zpip]{visibility:visible!important;position:fixed!important;' +
    'left:0!important;top:0!important;width:100vw!important;height:100vh!important;' +
    'max-width:none!important;max-height:none!important;margin:0!important;padding:0!important;' +
    'z-index:2147483647!important;object-fit:contain!important;background:#000!important;' +
    'border:0!important;transform:none!important}';

  function depth() {
    var d = 0, w = window;
    while (w !== w.top && d < 10) { w = w.parent; d++; }
    return d;
  }

  function post(o) {
    try { window.chrome.webview.postMessage(JSON.stringify(o)); } catch (e) {}
  }

  function bestVideo() {
    var vs = document.getElementsByTagName('video');
    var best = null, area = 0;
    for (var i = 0; i < vs.length; i++) {
      var r = vs[i].getBoundingClientRect();
      var a = r.width * r.height;
      if (a > area && vs[i].readyState > 0) { best = vs[i]; area = a; }
    }
    return area > 2000 ? best : null;
  }

  function fill(el) {
    if (!document.getElementById(STYLE_ID)) {
      var st = document.createElement('style');
      st.id = STYLE_ID;
      st.textContent = CSS;
      (document.head || document.documentElement).appendChild(st);
    }
    el.setAttribute('data-zpip', '1');
    var n = el.parentElement;
    while (n && n !== document.documentElement) {
      n.setAttribute('data-zpip-anc', '1');
      n = n.parentElement;
    }
    document.documentElement.setAttribute('data-zpip-on', '1');
  }

  function children() {
    return document.querySelectorAll('iframe');
  }

  function enter(replyTo) {
    function done(ok) {
      if (replyTo) {
        try { replyTo.postMessage({ __zpip: 1, cmd: 'entered', ok: ok }, '*'); } catch (e) {}
      } else {
        post({ type: 'zembo-pip', ok: ok });
      }
    }

    var v = bestVideo();
    if (v) { fill(v); done(true); return; }

    var frames = children();
    if (!frames.length) { done(false); return; }

    var pending = frames.length, answered = false;
    function onMsg(e) {
      var d = e.data;
      if (!d || typeof d !== 'object' || !d.__zpip || d.cmd !== 'entered') return;
      for (var i = 0; i < frames.length; i++) {
        if (frames[i].contentWindow !== e.source) continue;
        if (d.ok && !answered) {
          answered = true;
          window.removeEventListener('message', onMsg);
          fill(frames[i]);
          done(true);
        } else if (!d.ok) {
          pending--;
          if (pending <= 0 && !answered) {
            answered = true;
            window.removeEventListener('message', onMsg);
            done(false);
          }
        }
      }
    }
    window.addEventListener('message', onMsg);
    for (var i = 0; i < frames.length; i++) {
      try { frames[i].contentWindow.postMessage({ __zpip: 1, cmd: 'enter' }, '*'); }
      catch (e) { pending--; }
    }
    setTimeout(function () {
      if (answered) return;
      answered = true;
      window.removeEventListener('message', onMsg);
      done(false);
    }, Math.max(150, 700 - depth() * 200));
  }

  function exit(pause) {
    var marked = document.querySelectorAll('[data-zpip],[data-zpip-anc]');
    for (var i = 0; i < marked.length; i++) {
      marked[i].removeAttribute('data-zpip');
      marked[i].removeAttribute('data-zpip-anc');
    }
    document.documentElement.removeAttribute('data-zpip-on');
    var st = document.getElementById(STYLE_ID);
    if (st) st.remove();
    if (pause) {
      var vs = document.getElementsByTagName('video');
      for (var j = 0; j < vs.length; j++) { try { vs[j].pause(); } catch (e) {} }
    }
    var fr = children();
    for (var k = 0; k < fr.length; k++) {
      try { fr[k].contentWindow.postMessage({ __zpip: 1, cmd: 'exit', pause: !!pause }, '*'); } catch (e) {}
    }
  }

  function toggle() {
    var v = document.querySelector('video[data-zpip]');
    if (v) {
      if (v.paused) { try { v.play(); } catch (e) {} } else { v.pause(); }
      return;
    }
    var fr = children();
    for (var k = 0; k < fr.length; k++) {
      try { fr[k].contentWindow.postMessage({ __zpip: 1, cmd: 'toggle' }, '*'); } catch (e) {}
    }
  }

  // Есть ли на странице видео: сообщаем наверх, браузер показывает кнопку только тогда.
  var childHas = [];
  var lastReported = null;

  function anyChild() {
    var fr = children(), out = false, keep = [];
    for (var i = 0; i < childHas.length; i++) {
      var ok = false;
      for (var j = 0; j < fr.length; j++) {
        if (fr[j].contentWindow === childHas[i].win) { ok = true; break; }
      }
      if (ok) { keep.push(childHas[i]); if (childHas[i].has) out = true; }
    }
    childHas = keep;
    return out;
  }

  function report() {
    var has = !!bestVideo() || anyChild();
    if (has === lastReported) return;
    lastReported = has;
    if (window === window.top) post({ type: 'zembo-video', has: has });
    else {
      try { window.parent.postMessage({ __zpip: 1, cmd: 'hasvideo', has: has }, '*'); } catch (e) {}
    }
  }
  setInterval(report, 1500);

  window.addEventListener('message', function (e) {
    var d = e.data;
    if (!d || typeof d !== 'object' || !d.__zpip) return;
    if (d.cmd === 'enter' && e.source === window.parent && window !== window.top) enter(window.parent);
    else if (d.cmd === 'exit') exit(d.pause);
    else if (d.cmd === 'toggle') toggle();
    else if (d.cmd === 'hasvideo') {
      var found = false;
      for (var i = 0; i < childHas.length; i++) {
        if (childHas[i].win === e.source) { childHas[i].has = !!d.has; found = true; }
      }
      if (!found) childHas.push({ win: e.source, has: !!d.has });
      report();
    }
  });

  if (window === window.top) {
    window.__zpipApi = {
      enter: function () { enter(null); },
      exit: exit,
      toggle: toggle
    };
  }
})();
''';

  static const enter = 'window.__zpipApi && window.__zpipApi.enter();';
  static const exit = 'window.__zpipApi && window.__zpipApi.exit(false);';
  static const exitAndPause = 'window.__zpipApi && window.__zpipApi.exit(true);';
  static const toggle = 'window.__zpipApi && window.__zpipApi.toggle();';
}

import 'dart:convert';
import 'dart:io';

import 'tabs_controller.dart';

/// Перенос файлов из проводника на окно браузера: файл читается и передаётся
/// странице так, будто его перетащили прямо на сайт (например, на VirusTotal).
class FileDrop {
  FileDrop._();

  /// Максимальный суммарный размер файлов за один раз.
  static const maxBytes = 100 * 1024 * 1024;

  /// Размер куска файла (в base64 он станет примерно на треть больше).
  static const _chunk = 384 * 1024;

  /// [x], [y] — точка на странице в пикселях сайта (с учётом масштаба страницы).
  static Future<void> send(
    TabsController tabs,
    List<String> paths, {
    required double x,
    required double y,
  }) async {
    final tab = tabs.active;
    final web = tab.web;
    if (!tab.isBrowsing || !tab.webReady || web == null) {
      tabs.showToast('Откройте сайт, чтобы загрузить на него файл');
      return;
    }

    final files = <File>[];
    var total = 0;
    for (final p in paths) {
      if (FileSystemEntity.isDirectorySync(p)) continue;
      final f = File(p);
      if (!f.existsSync()) continue;
      total += f.lengthSync();
      files.add(f);
    }
    if (files.isEmpty) return;
    if (total > maxBytes) {
      tabs.showToast('Файл слишком большой для переноса (максимум 100 МБ)');
      return;
    }

    tabs.showToast('Передаю файл странице…');
    try {
      await web.executeScript('window.__zdFiles = [];');
      for (final f in files) {
        final name = f.path.split(RegExp(r'[\\/]')).last;
        await web.executeScript(
            'window.__zdCur = {n: ${jsonEncode(name)}, p: []};');
        final raf = await f.open();
        try {
          while (true) {
            // Пока файл читается, пользователь мог уйти на другую вкладку.
            if (tabs.active != tab || tab.web != web) return;
            final bytes = await raf.read(_chunk);
            if (bytes.isEmpty) break;
            await web.executeScript(_chunkJs(base64Encode(bytes)));
          }
        } finally {
          await raf.close();
        }
        await web.executeScript(_endFile);
      }
      if (tabs.active != tab || tab.web != web) return;
      final res = await web.executeScript(_finish(x, y));
      if (res.toString().contains('none')) {
        tabs.showToast('На странице нет места, куда можно загрузить файл');
      }
    } catch (_) {
      tabs.showToast('Не удалось передать файл странице');
    }
  }

  static String _chunkJs(String b64) =>
      '(function(b){var s=atob(b),a=new Uint8Array(s.length);'
      'for(var i=0;i<s.length;i++)a[i]=s.charCodeAt(i);'
      'window.__zdCur.p.push(a);})("$b64");';

  static const _endFile =
      '(function(){var c=window.__zdCur;if(!c)return;'
      'window.__zdFiles.push(new File(c.p,c.n));window.__zdCur=null;})();';

  /// Сначала имитируем настоящее перетаскивание (dragenter, dragover, drop) на
  /// элементе под курсором. Если сайт его не обработал — кладём файл в поле
  /// выбора файла (input type=file).
  static String _finish(double x, double y) => _finishJs
      .replaceAll('__X__', x.toStringAsFixed(1))
      .replaceAll('__Y__', y.toStringAsFixed(1));

  static const _finishJs = r'''
(function (x, y) {
  var files = window.__zdFiles || [];
  window.__zdFiles = null;
  if (!files.length) return 'none';

  var dt = new DataTransfer();
  for (var i = 0; i < files.length; i++) dt.items.add(files[i]);

  // Элемент под курсором, включая вложенные shadow DOM.
  var el = document.elementFromPoint(x, y) || document.body;
  while (el && el.shadowRoot) {
    var n = el.shadowRoot.elementFromPoint(x, y);
    if (!n || n === el) break;
    el = n;
  }
  if (!el) return 'none';

  function fire(type) {
    try {
      var e = new DragEvent(type, {
        bubbles: true, cancelable: true, composed: true,
        dataTransfer: dt, clientX: x, clientY: y
      });
      el.dispatchEvent(e);
      return e;
    } catch (err) { return null; }
  }
  fire('dragenter');
  fire('dragover');
  var drop = fire('drop');
  if (drop && drop.defaultPrevented) return 'drop';

  // Запасной вариант: поле выбора файла (в том числе внутри shadow DOM).
  var inputs = [];
  (function walk(root) {
    var all = root.querySelectorAll('*');
    for (var i = 0; i < all.length; i++) {
      var node = all[i];
      if (node.tagName === 'INPUT' && node.type === 'file' && !node.disabled) inputs.push(node);
      if (node.shadowRoot) walk(node.shadowRoot);
    }
  })(document);
  if (!inputs.length) return 'none';

  var input = inputs[0];
  for (var k = 0; k < inputs.length; k++) {
    if (inputs[k].getRootNode() === el.getRootNode()) { input = inputs[k]; break; }
  }
  var out = dt;
  if (!input.multiple && files.length > 1) {
    out = new DataTransfer();
    out.items.add(files[0]);
  }
  try {
    input.files = out.files;
    input.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    input.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
    return 'input';
  } catch (err) { return 'none'; }
})(__X__, __Y__);
''';
}

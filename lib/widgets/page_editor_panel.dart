import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';

import '../state/page_edits.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Редактор кода страницы (F12): HTML, свои стили и свой скрипт.
class PageEditorPanel extends StatefulWidget {
  final TabsController tabs;
  final PageEdits edits;
  final VoidCallback onClose;
  const PageEditorPanel({
    super.key,
    required this.tabs,
    required this.edits,
    required this.onClose,
  });

  @override
  State<PageEditorPanel> createState() => _PageEditorPanelState();
}

class _PageEditorPanelState extends State<PageEditorPanel> {
  static const _maxHtml = 300000;

  final _html = TextEditingController();
  final _css = TextEditingController();
  final _js = TextEditingController();

  int _tab = 1; // 0 — HTML, 1 — CSS, 2 — JS
  String _host = '';
  String _origHtml = '';
  bool _htmlCut = false;
  bool _loading = true;
  bool _canEdit = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _html.dispose();
    _css.dispose();
    _js.dispose();
    super.dispose();
  }

  static String _asString(dynamic r) {
    if (r == null) return '';
    if (r is String) {
      if (r.length >= 2 && r.startsWith('"') && r.endsWith('"')) {
        try {
          final d = jsonDecode(r);
          if (d is String) return d;
        } catch (_) {}
      }
      return r;
    }
    return r.toString();
  }

  Future<void> _load() async {
    final tab = widget.tabs.active;
    _host = PageEdits.hostKey(tab.url);
    final saved = widget.edits.forHost(_host);
    _css.text = saved?.css ?? '';
    _js.text = saved?.js ?? '';

    final web = tab.web;
    _canEdit = tab.isBrowsing && tab.webReady && web != null && _host.isNotEmpty;
    if (_canEdit && web != null) {
      try {
        var s = _asString(await web.executeScript(PageEdits.getHtml));
        _htmlCut = s.length > _maxHtml;
        if (_htmlCut) s = s.substring(0, _maxHtml);
        _origHtml = s;
        _html.text = s;
      } catch (_) {
        _html.text = '';
      }
    } else {
      _html.text = '';
      _status = 'Откройте сайт, чтобы изменить его код';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _run(String script) async {
    final web = widget.tabs.active.web;
    if (web == null) return false;
    try {
      final r = _asString(await web.executeScript(script));
      return !r.startsWith('err');
    } catch (_) {
      return false;
    }
  }

  /// Применить правки на открытой странице; [forever] — ещё и сохранить навсегда.
  Future<void> _apply({required bool forever}) async {
    if (!_canEdit) return;
    var ok = true;

    // Код страницы заменяется первым: после этого стили и скрипт накладываются заново.
    if (_html.text != _origHtml && !_htmlCut) {
      ok = await _run(PageEdits.htmlApply(_html.text)) && ok;
      _origHtml = _html.text;
    }
    ok = await _run(PageEdits.cssApply(_css.text)) && ok;
    if (_js.text.trim().isNotEmpty) {
      ok = await _run(PageEdits.jsRun(_js.text)) && ok;
    }

    if (forever) {
      await widget.edits.set(_host, _css.text, _js.text);
      await widget.tabs.reapplyAllScripts();
    }
    if (!mounted) return;
    setState(() {
      _status = !ok
          ? 'Не удалось применить изменения'
          : forever
              ? 'Сохранено навсегда для этого сайта'
              : 'Применено на этой странице';
    });
  }

  /// Убрать все свои правки этого сайта и вернуть страницу как была.
  Future<void> _reset() async {
    if (!_canEdit) return;
    await widget.edits.remove(_host);
    await widget.tabs.reapplyAllScripts();
    _css.clear();
    _js.clear();
    widget.tabs.reload();
    setState(() {
      _status = 'Правки сайта сброшены, страница перезагружена';
      _loading = true;
    });
    // Ждём, пока страница загрузится заново, и показываем её исходный код.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final keep = _status;
    await _load();
    if (mounted) setState(() => _status = keep);
  }

  @override
  Widget build(BuildContext context) {
    final ctl = switch (_tab) {
      0 => _html,
      1 => _css,
      _ => _js,
    };
    final hint = switch (_tab) {
      0 => 'HTML меняется только на этой странице и пропадёт после перезагрузки',
      1 => 'Стили сохраняются для всего сайта и применяются при каждом открытии',
      _ => 'Скрипт сохраняется для всего сайта и запускается при каждом открытии',
    };

    return Material(
      color: const Color(0xFF14171B),
      elevation: 12,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFF252A30))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(children: [
                const Text('Редактор страницы',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                for (final (i, name) in const ['HTML', 'CSS', 'JS'].indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: _tab == i,
                      onSelected: (_) => setState(() => _tab = i),
                      selectedColor: const Color(0x33FF5A1F),
                      backgroundColor: const Color(0xFF1B1F24),
                      labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _tab == i
                              ? AppColors.orange
                              : AppColors.foreground),
                      side: BorderSide.none,
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(hint,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ),
            if (_tab == 0 && _htmlCut)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                    'Страница слишком большая: HTML показан не полностью, его нельзя применить',
                    style: TextStyle(fontSize: 11.5, color: AppColors.orange)),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.orange),
                        ),
                      )
                    : TextField(
                        key: ValueKey('editor-$_tab'),
                        controller: ctl,
                        enabled: _canEdit,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontFamilyFallback: ['Courier New', 'monospace'],
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.foreground),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0E1013),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_status,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(children: [
                TextButton(
                  onPressed: _canEdit ? _reset : null,
                  child: const Text('Сбросить',
                      style: TextStyle(color: AppColors.muted)),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _canEdit ? () => _apply(forever: false) : null,
                  child: const Text('Сохранить'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _canEdit ? () => _apply(forever: true) : null,
                  child: const Text('Сохранить навсегда'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

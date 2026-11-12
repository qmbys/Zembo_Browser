import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import 'package:flutter/services.dart';

import '../state/suggest_service.dart';
import '../theme/app_theme.dart';

/// Выпадающий список подсказок под полем ввода (адресная строка и поиск на главной).
class SuggestAnchor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final SuggestService service;
  final ValueChanged<Suggestion> onPick;
  final Widget child;

  const SuggestAnchor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.service,
    required this.onPick,
    required this.child,
  });

  @override
  State<SuggestAnchor> createState() => _SuggestAnchorState();
}

class _SuggestAnchorState extends State<SuggestAnchor> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  List<Suggestion> _items = [];
  int _hi = -1;
  String _typed = '';
  String _lastText = '';
  double _width = 400;
  Timer? _debounce;
  Timer? _blurTimer;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _blurTimer?.cancel();
    widget.controller.removeListener(_onText);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus) {
      _blurTimer?.cancel();
      _lastText = widget.controller.text;
    } else {
      // Небольшая задержка: щелчок по подсказке не должен закрывать список раньше времени.
      _blurTimer?.cancel();
      _blurTimer = Timer(const Duration(milliseconds: 150), _close);
    }
  }

  void _onText() {
    if (!widget.focusNode.hasFocus) return;
    final text = widget.controller.text;
    if (text == _lastText) return; // изменилось только выделение
    _lastText = text;
    _typed = text;
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      _close();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 180), () => _load(text));
  }

  Future<void> _load(String text) async {
    final id = ++_req;
    final res = await widget.service.suggest(text);
    if (!mounted || id != _req || !widget.focusNode.hasFocus) return;
    setState(() {
      _items = res;
      _hi = -1;
    });
    if (res.isEmpty) {
      _hide();
    } else if (!_portal.isShowing) {
      _portal.show();
    }
  }

  void _hide() {
    if (_portal.isShowing) _portal.hide();
  }

  void _close() {
    _req++;
    _debounce?.cancel();
    if (!mounted) return;
    setState(() {
      _items = [];
      _hi = -1;
    });
    _hide();
  }

  void _pick(Suggestion s) {
    _close();
    widget.onPick(s);
  }

  /// Стрелки вверх/вниз: подсвечиваем вариант и подставляем его в строку.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (!_portal.isShowing || _items.isEmpty) return KeyEventResult.ignored;

    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowDown && key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }

    var next = _hi + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
    if (next >= _items.length) next = -1;
    if (next < -1) next = _items.length - 1;
    setState(() => _hi = next);

    final text = next == -1 ? _typed : _items[next].text;
    _lastText = text; // не запрашиваем подсказки заново
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        return CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _width,
              child: TextFieldTapRegion(child: _list()),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: LayoutBuilder(
          builder: (context, box) {
            _width = box.maxWidth;
            return Focus(
              canRequestFocus: false,
              onKeyEvent: _onKey,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }

  Widget _list() {
    return Material(
      color: const Color(0xFF14171B),
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF252A30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _items.length; i++)
              _Row(
                item: _items[i],
                highlighted: i == _hi,
                onTap: () => _pick(_items[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  final Suggestion item;
  final bool highlighted;
  final VoidCallback onTap;
  const _Row({required this.item, required this.highlighted, required this.onTap});

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => widget.onTap(),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (widget.highlighted || _hover)
                ? const Color(0xFF1C2026)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(s.fromHistory ? Icons.history : Icons.search,
                  size: 17, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: s.fromHistory
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.subtitle ?? s.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.foreground),
                          ),
                          Text(
                            s.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      )
                    : Text(
                        s.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.foreground),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

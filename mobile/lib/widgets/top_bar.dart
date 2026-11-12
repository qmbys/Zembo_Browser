import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../models/browser_tab.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Верхняя строка: адресная строка → расширения → почта → меню.
class BrowserTopBar extends StatelessWidget {
  final TabsController tabs;
  final VoidCallback onExtensions;
  final VoidCallback onMail;
  final VoidCallback onMenu;

  const BrowserTopBar({
    super.key,
    required this.tabs,
    required this.onExtensions,
    required this.onMail,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final tab = tabs.active;
    final k = tabs.settings.uiScale;
    return Container(
      height: 60 * k,
      color: tabs.settings.blackBars ? Colors.black : AppColors.chrome,
      padding: const EdgeInsets.only(left: 10, right: 6),
      child: Row(
        children: [
          Expanded(child: AddressBar(tabs: tabs, tab: tab)),
          const SizedBox(width: 4),
          _BarIcon(icon: Icons.extension_outlined, onTap: onExtensions, scale: k),
          _BarIcon(icon: Icons.mail_outline, onTap: onMail, scale: k),
          _BarIcon(icon: Icons.more_vert, onTap: onMenu, scale: k),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double scale;
  const _BarIcon(
      {required this.icon, required this.onTap, this.scale = 1.0});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44 * scale,
        height: 44 * scale,
        child: IconButton(
          onPressed: onTap,
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: AppColors.foreground, size: 24 * scale),
          splashRadius: 22 * scale,
        ),
      );
}

/// Адресная строка / поиск.
class AddressBar extends StatefulWidget {
  final TabsController tabs;
  final BrowserTab tab;
  const AddressBar({super.key, required this.tabs, required this.tab});

  @override
  State<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<AddressBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  static String pretty(String url) =>
      url.replaceFirst(RegExp(r'^https?://(www\.)?'), '').replaceFirst(RegExp(r'/$'), '');

  @override
  void initState() {
    super.initState();
    _controller.text = pretty(widget.tab.address);
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      _controller.text = widget.tab.address;
      _controller.selection =
          TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    } else {
      _controller.text = pretty(widget.tab.address);
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant AddressBar old) {
    super.didUpdateWidget(old);
    final changedTab = old.tab.id != widget.tab.id;
    if (changedTab) _focus.unfocus();
    if (!_focus.hasFocus) {
      final text = pretty(widget.tab.address);
      if (_controller.text != text) _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final v = value.trim();
    _focus.unfocus();
    if (v.isEmpty) return;
    widget.tabs.open(v);
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final secure = (tab.url ?? '').startsWith('https://');
    final browsing = tab.url != null;
    return Container(
      height: 44 * widget.tabs.settings.uiScale,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            tab.url == null || _focus.hasFocus
                ? Icons.search
                : (secure ? Icons.lock_outline : Icons.info_outline),
            size: 19,
            color: const Color(0xFFC4CBD2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onSubmitted: _submit,
              textInputAction: TextInputAction.go,
              keyboardType: TextInputType.url,
              maxLines: 1,
              style: const TextStyle(color: AppColors.foreground, fontSize: 15),
              cursorColor: AppColors.orange,
              decoration: InputDecoration(
                hintText: tr('Поиск или адрес сайта'),
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_focus.hasFocus && _controller.text.isNotEmpty)
            _small(Icons.close, () => _controller.clear())
          else if (browsing)
            _small(tab.loading ? Icons.close : Icons.refresh,
                () => tab.loading ? widget.tabs.stop(tab) : widget.tabs.reload(tab)),
        ],
      ),
    );
  }

  Widget _small(IconData icon, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 19, color: const Color(0xFFADB6C0)),
        splashRadius: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      );
}

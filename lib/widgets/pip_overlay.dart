import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import 'package:webview_windows/webview_windows.dart';

import '../models/browser_tab.dart';
import '../state/tabs_controller.dart';
import '../theme/app_theme.dart';

/// Окошко «картинка в картинке» в правом нижнем углу.
class PipOverlay extends StatelessWidget {
  final TabsController tabs;
  const PipOverlay({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tabs,
      builder: (context, _) {
        BrowserTab? source;
        for (final t in tabs.tabs) {
          if (t.pip && t.id != tabs.activeId && t.webReady && t.web != null) {
            source = t;
            break;
          }
        }
        if (source == null) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned(
              right: 16,
              bottom: 16,
              width: 400,
              height: 225,
              child: _PipWindow(key: ValueKey('pip-${source.id}'), tab: source, tabs: tabs),
            ),
          ],
        );
      },
    );
  }
}

class _PipWindow extends StatefulWidget {
  final BrowserTab tab;
  final TabsController tabs;
  const _PipWindow({super.key, required this.tab, required this.tabs});

  @override
  State<_PipWindow> createState() => _PipWindowState();
}

class _PipWindowState extends State<_PipWindow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A3036)),
          boxShadow: const [
            BoxShadow(color: Color(0xAA000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(
                child: Webview(widget.tab.web!, filterQuality: FilterQuality.medium),
              ),
              if (_hover)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                    child: Row(
                      children: [
                        _Btn(
                          icon: Icons.open_in_full,
                          tooltip: tr('Вернуть на страницу'),
                          onTap: () => widget.tabs.select(widget.tab.id),
                        ),
                        const Spacer(),
                        _Btn(
                          icon: Icons.play_arrow,
                          tooltip: tr('Пауза / воспроизведение'),
                          onTap: () => widget.tabs.pipTogglePlay(widget.tab),
                        ),
                        _Btn(
                          icon: Icons.close,
                          tooltip: tr('Закрыть'),
                          onTap: () => widget.tabs.closePip(widget.tab),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        splashRadius: 15,
        icon: Icon(icon, size: 18, color: AppColors.foreground),
      ),
    );
  }
}

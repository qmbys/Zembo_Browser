import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Свернуть / развернуть / закрыть — вместо стандартных кнопок Windows.
class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Button(
          icon: Icons.remove,
          onTap: () => windowManager.minimize(),
        ),
        _Button(
          icon: _maximized ? Icons.filter_none : Icons.crop_square,
          iconSize: _maximized ? 14 : 16,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _Button(
          icon: Icons.close,
          hoverColor: const Color(0xFFE81123),
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _Button extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color hoverColor;
  final VoidCallback onTap;

  const _Button({
    required this.icon,
    required this.onTap,
    this.iconSize = 16,
    this.hoverColor = const Color(0x1FFFFFFF),
  });

  @override
  State<_Button> createState() => _ButtonState();
}

class _ButtonState extends State<_Button> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 52,
          color: _hover ? widget.hoverColor : Colors.transparent,
          child: Icon(widget.icon,
              size: widget.iconSize, color: const Color(0xFFD5D9DE)),
        ),
      ),
    );
  }
}

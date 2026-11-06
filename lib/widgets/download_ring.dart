import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Кольцо вокруг значка загрузок: часть круга оранжевая и крутится, пока идёт загрузка.
class DownloadRing extends StatefulWidget {
  final bool active;
  final double size;
  const DownloadRing({super.key, required this.active, this.size = 36});

  @override
  State<DownloadRing> createState() => _DownloadRingState();
}

class _DownloadRingState extends State<DownloadRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(DownloadRing old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      // Останавливаем после того, как кольцо плавно погаснет.
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted && !widget.active) _c.stop();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: widget.active ? 1 : 0,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _RingPainter(_c.value),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  _RingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final r = (math.min(size.width, size.height) - 3) / 2;
    final center = size.center(Offset.zero);

    // Бледное кольцо целиком.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.orange.withValues(alpha: 0.22),
    );

    // Оранжевая дуга, которая бежит по кругу.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2 + t * 2 * math.pi,
      2 * math.pi * 0.28,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.orange,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}

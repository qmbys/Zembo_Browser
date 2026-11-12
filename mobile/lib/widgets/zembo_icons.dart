import 'package:flutter/material.dart';

/// Значок меню «Мои сайты»: четыре скруглённые плитки в цвете остальных значков панели.
class ZemboGridIcon extends StatelessWidget {
  final bool active;
  final double size;
  const ZemboGridIcon({super.key, this.active = false, this.size = 20});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GridPainter(active)),
      );
}

class _GridPainter extends CustomPainter {
  final bool active;
  _GridPainter(this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width * 0.14;
    final cell = (size.width - gap) / 2;
    final radius = Radius.circular(cell * 0.32);

    final base = Paint()
      ..color = active ? const Color(0xFFFFFFFF) : const Color(0xFFCAD0D7);

    RRect cellAt(int col, int row) => RRect.fromRectAndRadius(
          Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell),
          radius,
        );

    canvas.drawRRect(cellAt(0, 0), base);
    canvas.drawRRect(cellAt(0, 1), base);
    canvas.drawRRect(cellAt(1, 1), base);
    canvas.drawRRect(cellAt(1, 0), base);
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.active != active;
}

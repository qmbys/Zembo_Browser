import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ZemboMark extends StatelessWidget {
  final double size;
  const ZemboMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _ZemboMarkPainter()),
  );
}

class _ZemboMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.orange;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .22)
      ..lineTo(size.width * .88, size.height * .22)
      ..lineTo(size.width * .55, size.height * .48)
      ..lineTo(size.width * .82, size.height * .48)
      ..lineTo(size.width * .18, size.height * .82)
      ..lineTo(size.width * .43, size.height * .53)
      ..lineTo(size.width * .16, size.height * .53)
      ..lineTo(size.width * .48, size.height * .22)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

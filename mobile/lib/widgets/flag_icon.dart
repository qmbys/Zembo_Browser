import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Флаг страны, нарисованный кодом. В Windows нет эмодзи-флагов
/// (вместо них показываются буквы), поэтому флаги рисуем сами.
class FlagIcon extends StatelessWidget {
  final String flag;
  final double width;
  final double height;
  const FlagIcon(this.flag, {super.key, this.width = 30, this.height = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0x33FFFFFF), width: 0.6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: CustomPaint(painter: _FlagPainter(flag), size: Size(width, height)),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  final String flag;
  _FlagPainter(this.flag);

  static const _white = Color(0xFFFFFFFF);

  @override
  bool shouldRepaint(covariant _FlagPainter old) => old.flag != flag;

  Paint _p(Color c) => Paint()..color = c;

  void _h(Canvas c, Size s, List<Color> cols, [List<double>? w]) {
    final weights = w ?? List<double>.filled(cols.length, 1);
    final total = weights.fold<double>(0, (a, b) => a + b);
    var y = 0.0;
    for (var i = 0; i < cols.length; i++) {
      final hh = s.height * weights[i] / total;
      c.drawRect(Rect.fromLTWH(0, y, s.width, hh + 0.5), _p(cols[i]));
      y += hh;
    }
  }

  void _v(Canvas c, Size s, List<Color> cols, [List<double>? w]) {
    final weights = w ?? List<double>.filled(cols.length, 1);
    final total = weights.fold<double>(0, (a, b) => a + b);
    var x = 0.0;
    for (var i = 0; i < cols.length; i++) {
      final ww = s.width * weights[i] / total;
      c.drawRect(Rect.fromLTWH(x, 0, ww + 0.5, s.height), _p(cols[i]));
      x += ww;
    }
  }

  void _star(Canvas c, Offset center, double r, Color col, {double rot = -math.pi / 2}) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.4;
      final a = rot + i * math.pi / 5;
      final pt = Offset(center.dx + rad * math.cos(a), center.dy + rad * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    c.drawPath(path, _p(col));
  }

  void _cross(Canvas c, Size s, Color col, double cx, double thick) {
    c.drawRect(Rect.fromLTWH(s.width * cx - s.height * thick / 2, 0,
        s.height * thick, s.height), _p(col));
    c.drawRect(Rect.fromLTWH(0, s.height / 2 - s.height * thick / 2, s.width,
        s.height * thick), _p(col));
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    switch (flag) {
      case 'ru':
        _h(c, s, const [_white, Color(0xFF0039A6), Color(0xFFD52B1E)]);
      case 'ua':
        _h(c, s, const [Color(0xFF0057B7), Color(0xFFFFD700)]);
      case 'de':
        _h(c, s, const [Color(0xFF000000), Color(0xFFDD0000), Color(0xFFFFCE00)]);
      case 'fr':
        _v(c, s, const [Color(0xFF0055A4), _white, Color(0xFFEF4135)]);
      case 'es':
        _h(c, s, const [Color(0xFFAA151B), Color(0xFFF1BF00), Color(0xFFAA151B)],
            const [1, 2, 1]);
      case 'it':
        _v(c, s, const [Color(0xFF009246), _white, Color(0xFFCE2B37)]);
      case 'pl':
        _h(c, s, const [_white, Color(0xFFDC143C)]);
      case 'nl':
        _h(c, s, const [Color(0xFFAE1C28), _white, Color(0xFF21468B)]);
      case 'hu':
        _h(c, s, const [Color(0xFFCE2939), _white, Color(0xFF477050)]);
      case 'bg':
        _h(c, s, const [_white, Color(0xFF00966E), Color(0xFFD62612)]);
      case 'id':
        _h(c, s, const [Color(0xFFCE1126), _white]);
      case 'ro':
        _v(c, s, const [Color(0xFF002B7F), Color(0xFFFCD116), Color(0xFFCE1126)]);
      case 'th':
        _h(c, s, const [
          Color(0xFFA51931),
          _white,
          Color(0xFF2D2A4A),
          _white,
          Color(0xFFA51931),
        ], const [1, 1, 2, 1, 1]);
      case 'cz':
        _h(c, s, const [_white, Color(0xFFD7141A)]);
        final czP = Path()
          ..moveTo(0, 0)
          ..lineTo(w * 0.5, h / 2)
          ..lineTo(0, h)
          ..close();
        c.drawPath(czP, _p(const Color(0xFF11457E)));
      case 'se':
        c.drawRect(Offset.zero & s, _p(const Color(0xFF006AA7)));
        c.drawRect(Rect.fromLTWH(w * 0.3125 - h * 0.1, 0, h * 0.2, h),
            _p(const Color(0xFFFECC00)));
        c.drawRect(Rect.fromLTWH(0, h * 0.4, w, h * 0.2), _p(const Color(0xFFFECC00)));
      case 'fi':
        c.drawRect(Offset.zero & s, _p(_white));
        c.drawRect(Rect.fromLTWH(w * 0.3125 - h * 0.1, 0, h * 0.2, h),
            _p(const Color(0xFF003580)));
        c.drawRect(Rect.fromLTWH(0, h * 0.4, w, h * 0.2), _p(const Color(0xFF003580)));
      case 'jp':
        c.drawRect(Offset.zero & s, _p(_white));
        c.drawCircle(Offset(w / 2, h / 2), h * 0.3, _p(const Color(0xFFBC002D)));
      case 'br':
        c.drawRect(Offset.zero & s, _p(const Color(0xFF009C3B)));
        final brR = Path()
          ..moveTo(w / 2, h * 0.1)
          ..lineTo(w * 0.9, h / 2)
          ..lineTo(w / 2, h * 0.9)
          ..lineTo(w * 0.1, h / 2)
          ..close();
        c.drawPath(brR, _p(const Color(0xFFFFDF00)));
        c.drawCircle(Offset(w / 2, h / 2), h * 0.26, _p(const Color(0xFF002776)));
      case 'tr':
        c.drawRect(Offset.zero & s, _p(const Color(0xFFE30A17)));
        c.drawCircle(Offset(w * 0.38, h / 2), h * 0.28, _p(_white));
        c.drawCircle(Offset(w * 0.44, h / 2), h * 0.23, _p(const Color(0xFFE30A17)));
        _star(c, Offset(w * 0.6, h / 2), h * 0.14, _white);
      case 'cn':
        c.drawRect(Offset.zero & s, _p(const Color(0xFFDE2910)));
        const gold = Color(0xFFFFDE00);
        _star(c, Offset(w * 0.17, h * 0.28), h * 0.19, gold);
        _star(c, Offset(w * 0.34, h * 0.1), h * 0.06, gold);
        _star(c, Offset(w * 0.4, h * 0.22), h * 0.06, gold);
        _star(c, Offset(w * 0.4, h * 0.36), h * 0.06, gold);
        _star(c, Offset(w * 0.34, h * 0.48), h * 0.06, gold);
      case 'vn':
        c.drawRect(Offset.zero & s, _p(const Color(0xFFDA251D)));
        _star(c, Offset(w / 2, h / 2), h * 0.32, const Color(0xFFFFFF00));
      case 'kr':
        c.drawRect(Offset.zero & s, _p(_white));
        final center = Offset(w / 2, h / 2);
        final rr = h * 0.25;
        c.drawArc(Rect.fromCircle(center: center, radius: rr), math.pi, math.pi, true,
            _p(const Color(0xFFCD2E3A)));
        c.drawArc(Rect.fromCircle(center: center, radius: rr), 0, math.pi, true,
            _p(const Color(0xFF0047A0)));
        final bar = Paint()
          ..color = const Color(0xFF000000)
          ..strokeWidth = h * 0.09
          ..strokeCap = StrokeCap.butt;
        for (final sx in [-1.0, 1.0]) {
          for (final sy in [-1.0, 1.0]) {
            final o = Offset(w / 2 + sx * w * 0.3, h / 2 + sy * h * 0.3);
            final d = Offset(sx * sy * h * 0.1, h * 0.1);
            c.drawLine(o - d, o + d, bar);
          }
        }
      case 'sa':
        c.drawRect(Offset.zero & s, _p(const Color(0xFF006C35)));
        final line = Paint()
          ..color = _white
          ..strokeWidth = h * 0.08;
        c.drawLine(Offset(w * 0.25, h * 0.7), Offset(w * 0.75, h * 0.7), line);
        c.drawLine(Offset(w * 0.3, h * 0.38), Offset(w * 0.7, h * 0.38), line);
      case 'in':
        _h(c, s, const [Color(0xFFFF9933), _white, Color(0xFF138808)]);
        final ring = Paint()
          ..color = const Color(0xFF000080)
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.06;
        c.drawCircle(Offset(w / 2, h / 2), h * 0.14, ring);
      case 'kz':
        c.drawRect(Offset.zero & s, _p(const Color(0xFF00AFCA)));
        c.drawCircle(Offset(w / 2, h / 2), h * 0.2, _p(const Color(0xFFFEC50C)));
      case 'by':
        c.drawRect(Rect.fromLTWH(0, 0, w, h * 0.67), _p(const Color(0xFFCF101A)));
        c.drawRect(Rect.fromLTWH(0, h * 0.67, w, h * 0.33 + 0.5),
            _p(const Color(0xFF007C30)));
        c.drawRect(Rect.fromLTWH(0, 0, w * 0.12, h), _p(_white));
        c.drawRect(Rect.fromLTWH(w * 0.04, 0, w * 0.04, h), _p(const Color(0xFFCF101A)));
      case 'il':
        c.drawRect(Offset.zero & s, _p(_white));
        const ilBlue = Color(0xFF0038B8);
        c.drawRect(Rect.fromLTWH(0, h * 0.1, w, h * 0.13), _p(ilBlue));
        c.drawRect(Rect.fromLTWH(0, h * 0.77, w, h * 0.13), _p(ilBlue));
        final ilSt = Paint()
          ..color = ilBlue
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.05;
        final ilR = h * 0.2;
        for (final dir in [-1.0, 1.0]) {
          final ilP = Path();
          for (var i = 0; i < 3; i++) {
            final a = -math.pi / 2 * dir + i * 2 * math.pi / 3;
            final pt = Offset(w / 2 + ilR * math.cos(a), h / 2 + ilR * math.sin(a));
            if (i == 0) {
              ilP.moveTo(pt.dx, pt.dy);
            } else {
              ilP.lineTo(pt.dx, pt.dy);
            }
          }
          ilP.close();
          c.drawPath(ilP, ilSt);
        }
      case 'gr':
        const grBlue = Color(0xFF0D5EAF);
        for (var i = 0; i < 9; i++) {
          c.drawRect(Rect.fromLTWH(0, h * i / 9, w, h / 9 + 0.5),
              _p(i.isEven ? grBlue : _white));
        }
        c.drawRect(Rect.fromLTWH(0, 0, w * 0.37, h * 5 / 9), _p(grBlue));
        c.drawRect(Rect.fromLTWH(w * 0.37 / 2 - h * 0.05, 0, h * 0.1, h * 5 / 9), _p(_white));
        c.drawRect(Rect.fromLTWH(0, h * 5 / 18 - h * 0.05, w * 0.37, h * 0.1), _p(_white));
      case 'us':
        const usRed = Color(0xFFB22234);
        for (var i = 0; i < 13; i++) {
          c.drawRect(Rect.fromLTWH(0, h * i / 13, w, h / 13 + 0.5),
              _p(i.isEven ? usRed : _white));
        }
        c.drawRect(Rect.fromLTWH(0, 0, w * 0.42, h * 7 / 13), _p(const Color(0xFF3C3B6E)));
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 4; col++) {
            c.drawCircle(Offset(w * (0.06 + col * 0.095), h * (0.1 + row * 0.15)),
                h * 0.03, _p(_white));
          }
        }
      case 'gb':
        const gbBlue = Color(0xFF012169);
        const gbRed = Color(0xFFC8102E);
        c.drawRect(Offset.zero & s, _p(gbBlue));
        final wide = Paint()
          ..color = _white
          ..strokeWidth = h * 0.22;
        final thin = Paint()
          ..color = gbRed
          ..strokeWidth = h * 0.1;
        c.drawLine(Offset.zero, Offset(w, h), wide);
        c.drawLine(Offset(w, 0), Offset(0, h), wide);
        c.drawLine(Offset.zero, Offset(w, h), thin);
        c.drawLine(Offset(w, 0), Offset(0, h), thin);
        _cross(c, s, _white, 0.5, 0.36);
        _cross(c, s, gbRed, 0.5, 0.2);
      default:
        c.drawRect(Offset.zero & s, _p(const Color(0xFF2A3036)));
    }
  }
}

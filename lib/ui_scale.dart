import 'package:flutter/material.dart';

/// Размер окна (логические пиксели): 1000x620 по центру экрана.
const double kWindowWidth = 1000;
const double kWindowHeight = 620;

/// Масштаб интерфейса. 1000 / 1536 ≈ 0.65 — тогда интерфейс в окне выглядит
/// по пропорциям как на макете (скриншот 1536 px шириной). 1.0 — крупно, 0.5 — мелко.
const double kUiScale = 0.85;

/// Рисует весь интерфейс в "виртуальном" размере (окно / scale)
/// и уменьшает его целиком, поэтому раскладка остаётся такой же, как при 1000x620.
class UiScale extends StatelessWidget {
  final double scale;
  final Widget child;
  const UiScale({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    if (scale == 1.0) return child;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth / scale;
        final h = box.maxHeight / scale;
        final mq = MediaQuery.of(context);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: w,
            maxWidth: w,
            minHeight: h,
            maxHeight: h,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: MediaQuery(
                data: mq.copyWith(size: Size(w, h)),
                child: SizedBox(width: w, height: h, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Масштаб содержимого страницы (Ctrl + / Ctrl -) для страниц, нарисованных самим браузером.
class ZoomBox extends StatelessWidget {
  final double zoom;
  final Widget child;
  const ZoomBox({super.key, required this.zoom, required this.child});

  @override
  Widget build(BuildContext context) {
    // Структура дерева одинакова при любом масштабе — прокрутка и ввод не сбрасываются.
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth / zoom;
        final h = box.maxHeight / zoom;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: w,
            maxWidth: w,
            minHeight: h,
            maxHeight: h,
            child: Transform.scale(
              scale: zoom,
              alignment: Alignment.topLeft,
              child: SizedBox(width: w, height: h, child: child),
            ),
          ),
        );
      },
    );
  }
}

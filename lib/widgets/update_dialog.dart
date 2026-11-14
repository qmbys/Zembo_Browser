import 'package:flutter/material.dart' hide Text;

import '../app_version.dart';
import '../i18n/i18n.dart';
import '../state/updater.dart';
import '../theme/app_theme.dart';

/// Чёрное окно обновления поверх браузера: всё позади затемняется.
class UpdateDialog extends StatelessWidget {
  final UpdateController controller;
  const UpdateDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        if (c.phase == UpdatePhase.idle) return const SizedBox.shrink();
        return Stack(
          children: [
            // Затемнение и защита от кликов по странице под окном.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.72)),
              ),
            ),
            Center(
              child: Container(
                width: 420,
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x99000000), blurRadius: 40),
                  ],
                ),
                child: _content(c),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _content(UpdateController c) {
    switch (c.phase) {
      case UpdatePhase.available:
        return _col([
          const Icon(Icons.bolt_rounded, size: 34, color: AppColors.orange),
          const SizedBox(height: 14),
          _title('Вышла новая версия браузера'),
          const SizedBox(height: 6),
          _sub('Zembo Browser ${c.newVersion} (у вас $kAppVersion)'),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: _primary('Обновить сейчас', c.start)),
            const SizedBox(width: 10),
            Expanded(child: _secondary('Обновить позже', c.later)),
          ]),
        ]);
      case UpdatePhase.downloading:
        final pct = (c.progress * 100).round();
        return _col([
          _title('Обновление Zembo Browser'),
          const SizedBox(height: 6),
          _sub('Версия ${c.newVersion}'),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: c.total > 0 ? c.progress : null,
              minHeight: 6,
              color: AppColors.orange,
              backgroundColor: AppColors.field,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sub(c.total > 0 ? '$pct%' : '...'),
              _sub('${_mb(c.received)} / ${_mb(c.total)} MB'),
            ],
          ),
        ]);
      case UpdatePhase.ready:
        return _col([
          const Icon(Icons.check_circle_rounded,
              size: 34, color: AppColors.orange),
          const SizedBox(height: 14),
          _title('Обновление готово'),
          const SizedBox(height: 6),
          _sub('Перезапустите браузер, чтобы начать работу с версией ${c.newVersion}'),
          const SizedBox(height: 22),
          SizedBox(
              width: double.infinity,
              child: _primary('Перезапустить', c.restart)),
        ]);
      case UpdatePhase.error:
        return _col([
          const Icon(Icons.error_outline_rounded,
              size: 34, color: AppColors.muted),
          const SizedBox(height: 14),
          _title('Не удалось обновить'),
          const SizedBox(height: 6),
          _sub(c.error ?? ''),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: _primary('Повторить', c.start)),
            const SizedBox(width: 10),
            Expanded(child: _secondary('Закрыть', c.later)),
          ]),
        ]);
      case UpdatePhase.idle:
        return const SizedBox.shrink();
    }
  }

  static String _mb(int bytes) => (bytes / 1048576).toStringAsFixed(1);

  static Widget _col(List<Widget> children) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );

  static Widget _title(String s) => Text(s,
      style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: AppColors.foreground));

  static Widget _sub(String s) => Text(s,
      style: const TextStyle(fontSize: 13.5, color: AppColors.muted));

  static Widget _primary(String s, VoidCallback onTap) => SizedBox(
        height: 42,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(s,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );

  static Widget _secondary(String s, VoidCallback onTap) => SizedBox(
        height: 42,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.foreground,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(s, style: const TextStyle(fontSize: 14)),
        ),
      );
}

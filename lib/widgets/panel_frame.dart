import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import '../theme/app_theme.dart';

/// Оформление выпадающей панели (расширения, загрузки).
class PanelFrame extends StatelessWidget {
  final String title;
  final Widget? action;
  final Widget child;
  final double width;
  final double maxHeight;
  const PanelFrame({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.width = 360,
    this.maxHeight = 520,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: const Color(0xFF14171B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF252A30)),
          boxShadow: const [
            BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

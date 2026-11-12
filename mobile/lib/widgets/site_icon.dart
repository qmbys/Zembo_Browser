import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import '../theme/app_theme.dart';

/// Значок сайта: настоящая иконка страницы -> иконка из сервиса Google -> первая буква.
class SiteIcon extends StatelessWidget {
  final String? iconUrl;
  final String url;
  final String label;
  final double size;
  final double letterSize;

  const SiteIcon({
    super.key,
    required this.url,
    required this.label,
    this.iconUrl,
    this.size = 32,
    this.letterSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final letter = Text(
      label.isEmpty ? '?' : label.characters.first.toUpperCase(),
      style: TextStyle(
        fontSize: letterSize,
        fontWeight: FontWeight.w600,
        color: AppColors.foreground,
      ),
    );

    final host = Uri.tryParse(url)?.host ?? '';
    Widget fromGoogle() {
      if (host.isEmpty) return letter;
      return Image.network(
        'https://www.google.com/s2/favicons?sz=64&domain=$host',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => letter,
      );
    }

    final own = iconUrl;
    if (own != null && own.isNotEmpty) {
      return Image.network(
        own,
        key: ValueKey(own),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => fromGoogle(),
      );
    }
    return fromGoogle();
  }
}

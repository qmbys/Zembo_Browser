/// Ссылки сайтов, которые можно открыть в установленном приложении
/// (например, страница канала t.me → Telegram).
class AppLink {
  final String app;
  final String url;
  const AppLink(this.app, this.url);
}

class AppLinks {
  AppLinks._();

  static final _id = RegExp(r'^[A-Za-z0-9_\-+]{1,128}$');

  static AppLink? forUrl(String? raw) {
    if (raw == null) return null;
    final u = Uri.tryParse(raw);
    if (u == null || !(u.scheme == 'https' || u.scheme == 'http')) return null;
    final host = u.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final seg = u.pathSegments.where((s) => s.isNotEmpty).toList();

    if (host == 't.me' || host == 'telegram.me' || host == 'telegram.dog') {
      if (seg.isEmpty) return null;
      var parts = seg;
      if (parts.first == 's' && parts.length > 1) parts = parts.sublist(1);
      final first = parts.first;
      if (first == 'joinchat' && parts.length > 1 && _id.hasMatch(parts[1])) {
        return AppLink('Telegram', 'tg://join?invite=${parts[1]}');
      }
      if (first.startsWith('+') && _id.hasMatch(first)) {
        return AppLink('Telegram', 'tg://join?invite=${first.substring(1)}');
      }
      if (!_id.hasMatch(first)) return null;
      final post = parts.length > 1 && RegExp(r'^\d+$').hasMatch(parts[1])
          ? '&post=${parts[1]}'
          : '';
      return AppLink('Telegram', 'tg://resolve?domain=$first$post');
    }
    if (host == 'discord.gg' && seg.isNotEmpty && _id.hasMatch(seg[0])) {
      return AppLink('Discord', 'discord://-/invite/${seg[0]}');
    }
    if ((host == 'discord.com' || host == 'discordapp.com') &&
        seg.length >= 2 &&
        seg[0] == 'invite' &&
        _id.hasMatch(seg[1])) {
      return AppLink('Discord', 'discord://-/invite/${seg[1]}');
    }
    if (host == 'open.spotify.com' && seg.length >= 2) {
      final i = seg[0].startsWith('intl-') && seg.length >= 3 ? 1 : 0;
      final type = seg[i], id = seg[i + 1 < seg.length ? i + 1 : i];
      const types = {'track', 'album', 'artist', 'playlist', 'episode', 'show'};
      if (types.contains(type) && _id.hasMatch(id)) {
        return AppLink('Spotify', 'spotify:$type:$id');
      }
    }
    if (host == 'store.steampowered.com' &&
        seg.length >= 2 &&
        seg[0] == 'app' &&
        RegExp(r'^\d+$').hasMatch(seg[1])) {
      return AppLink('Steam', 'steam://store/${seg[1]}');
    }
    return null;
  }
}

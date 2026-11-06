import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'filter_lists.dart';

/// Локальный прокси: пропускает запросы страниц и блокирует домены из списков.
/// Заодно сам определяет адреса сайтов через выбранный DNS-сервер (DoH).
class FilterProxy extends ChangeNotifier {
  FilterProxy(this.settings, this.lists);

  final AppSettings settings;
  final FilterLists lists;

  ServerSocket? _server;
  int get port => _server?.port ?? 0;

  int _blocked = 0;
  int get blockedCount => _blocked;
  Timer? _notifyTimer;
  bool _disposed = false;

  Future<bool> start() async {
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      server.listen(_onClient, onError: (_) {});
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    _server?.close();
    _doh.close();
    super.dispose();
  }

  void _countBlocked() {
    _blocked++;
    _notifyTimer ??= Timer(const Duration(milliseconds: 800), () {
      _notifyTimer = null;
      if (!_disposed) notifyListeners();
    });
  }

  bool _isBlocked(String host) {
    if (!settings.adBlock) return false;
    final h = host.toLowerCase();
    if (lists.blocks(h)) {
      _countBlocked();
      return true;
    }
    return false;
  }

  // ---------- подключения от браузера ----------

  void _onClient(Socket client) {
    client.setOption(SocketOption.tcpNoDelay, true);
    final buf = BytesBuilder(copy: false);
    var handled = false;
    late final StreamSubscription<Uint8List> sub;

    sub = client.listen(
      (data) {
        if (handled) return;
        buf.add(data);
        final bytes = buf.toBytes();
        final end = _headerEnd(bytes);
        if (end < 0) {
          if (bytes.length > 65536) client.destroy();
          return;
        }
        handled = true;
        sub.pause();
        _handle(client, sub, bytes, end);
      },
      onError: (_) => client.destroy(),
      onDone: () {
        if (!handled) client.destroy();
      },
      cancelOnError: true,
    );
  }

  static int _headerEnd(Uint8List b) {
    for (var i = 0; i + 3 < b.length; i++) {
      if (b[i] == 13 && b[i + 1] == 10 && b[i + 2] == 13 && b[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  Future<void> _handle(Socket client, StreamSubscription<Uint8List> sub,
      Uint8List bytes, int headerEnd) async {
    try {
      final head = latin1.decode(bytes.sublist(0, headerEnd));
      final lines = head.split('\r\n');
      final first = lines.first.split(' ');
      if (first.length < 3) return _reply(client, sub, 400, 'Bad Request');

      final method = first[0].toUpperCase();
      final target = first[1];
      final rest = Uint8List.sublistView(bytes, headerEnd + 4);

      if (method == 'CONNECT') {
        final idx = target.lastIndexOf(':');
        final host = (idx > 0 ? target.substring(0, idx) : target)
            .replaceAll(RegExp(r'^\[|\]$'), '');
        final port = idx > 0 ? (int.tryParse(target.substring(idx + 1)) ?? 443) : 443;

        if (_isBlocked(host)) return _reply(client, sub, 403, 'Forbidden');

        final remote = await _connect(host, port);
        client.add(ascii.encode('HTTP/1.1 200 Connection Established\r\n\r\n'));
        _pipe(client, sub, remote, rest);
        return;
      }

      // Обычный http: запрос с полным адресом.
      final uri = Uri.tryParse(target);
      if (uri == null || !uri.hasAuthority || uri.scheme != 'http') {
        return _reply(client, sub, 400, 'Bad Request');
      }
      if (_isBlocked(uri.host)) return _reply(client, sub, 403, 'Forbidden');

      final remote = await _connect(uri.host, uri.hasPort ? uri.port : 80);
      final path = (uri.path.isEmpty ? '/' : uri.path) +
          (uri.hasQuery ? '?${uri.query}' : '');
      final sb = StringBuffer('$method $path ${first[2]}\r\n');
      for (final l in lines.skip(1)) {
        final low = l.toLowerCase();
        if (l.isEmpty ||
            low.startsWith('proxy-connection:') ||
            low.startsWith('connection:') ||
            low.startsWith('proxy-authorization:')) {
          continue;
        }
        sb.write('$l\r\n');
      }
      // Закрываем соединение после ответа, чтобы следующий запрос шёл отдельно.
      sb.write('Connection: close\r\n\r\n');
      remote.add(latin1.encode(sb.toString()));
      _pipe(client, sub, remote, rest);
    } catch (_) {
      _reply(client, sub, 502, 'Bad Gateway');
    }
  }

  void _reply(Socket client, StreamSubscription<Uint8List> sub, int code,
      String text) {
    try {
      client.add(ascii.encode(
          'HTTP/1.1 $code $text\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'));
      client.flush().whenComplete(client.destroy);
    } catch (_) {
      client.destroy();
    }
    sub.cancel();
  }

  void _pipe(Socket client, StreamSubscription<Uint8List> sub, Socket remote,
      Uint8List initial) {
    remote.setOption(SocketOption.tcpNoDelay, true);
    if (initial.isNotEmpty) remote.add(initial);

    sub.onData((d) {
      try {
        remote.add(d);
      } catch (_) {}
    });
    sub.onError((_) {
      client.destroy();
      remote.destroy();
    });
    sub.onDone(remote.destroy);

    remote.listen(
      (d) {
        try {
          client.add(d);
        } catch (_) {}
      },
      onDone: client.destroy,
      onError: (_) {
        client.destroy();
        remote.destroy();
      },
      cancelOnError: true,
    );
    sub.resume();
  }

  // ---------- подключение к сайту ----------

  final _doh = _DohResolver();
  final Map<String, _CachedAddrs> _cache = {};
  String _cacheDns = '';

  Future<Socket> _connect(String host, int port) async {
    final addrs = await _resolve(host);
    Object? lastError;
    for (final a in addrs) {
      try {
        return await Socket.connect(a, port, timeout: const Duration(seconds: 8));
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? const SocketException('no address');
  }

  Future<List<InternetAddress>> _resolve(String host) async {
    final ip = InternetAddress.tryParse(host);
    if (ip != null) return [ip];
    if (host == 'localhost') return [InternetAddress.loopbackIPv4];

    // Сменили DNS-сервер — сбрасываем кэш.
    if (_cacheDns != settings.dns) {
      _cache.clear();
      _cacheDns = settings.dns;
    }
    final key = host.toLowerCase();
    final hit = _cache[key];
    if (hit != null && hit.expires.isAfter(DateTime.now())) return hit.addrs;

    List<InternetAddress> addrs = [];
    final template = AppSettings.dnsTemplates[settings.dns];
    if (template != null) {
      addrs = await _doh.resolve(template, key);
    }
    if (addrs.isEmpty) {
      // Системный DNS: выбран «Системный» или DoH-сервер не ответил.
      addrs = await InternetAddress.lookup(key);
    }
    _cache[key] = _CachedAddrs(addrs, DateTime.now().add(const Duration(minutes: 5)));
    if (_cache.length > 4000) _cache.clear();
    return addrs;
  }
}

class _CachedAddrs {
  _CachedAddrs(this.addrs, this.expires);
  final List<InternetAddress> addrs;
  final DateTime expires;
}

/// DNS-over-HTTPS (RFC 8484): запрос в формате DNS через HTTPS GET.
class _DohResolver {
  HttpClient? _client;

  HttpClient get _http {
    return _client ??= HttpClient()
      ..findProxy = ((_) => 'DIRECT')
      ..connectionTimeout = const Duration(seconds: 6)
      ..idleTimeout = const Duration(seconds: 30);
  }

  void close() => _client?.close(force: true);

  Future<List<InternetAddress>> resolve(String template, String host) async {
    try {
      final a = await _query(template, host, 1);
      if (a.isNotEmpty) return a;
      return await _query(template, host, 28);
    } catch (_) {
      return [];
    }
  }

  Future<List<InternetAddress>> _query(String template, String host, int type) async {
    final b = BytesBuilder();
    b.add([0, 0, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0]); // заголовок: RD, 1 вопрос
    for (final label in host.split('.')) {
      final bytes = utf8.encode(label);
      if (bytes.isEmpty || bytes.length > 63) return [];
      b.addByte(bytes.length);
      b.add(bytes);
    }
    b.addByte(0);
    b.add([0, type, 0, 1]); // тип и класс IN

    final q = base64Url.encode(b.toBytes()).replaceAll('=', '');
    final req = await _http.getUrl(Uri.parse('$template?dns=$q'));
    req.headers.set('accept', 'application/dns-message');
    final res = await req.close().timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      await res.drain<void>();
      return [];
    }
    final body = BytesBuilder(copy: false);
    await for (final c in res) {
      body.add(c);
    }
    return _parse(body.toBytes());
  }

  static List<InternetAddress> _parse(Uint8List d) {
    if (d.length < 12) return [];
    final an = (d[6] << 8) | d[7];
    var p = 12;

    int skipName(int pos) {
      while (pos < d.length) {
        final l = d[pos];
        if (l == 0) return pos + 1;
        if ((l & 0xC0) == 0xC0) return pos + 2;
        pos += l + 1;
      }
      return pos;
    }

    final qd = (d[4] << 8) | d[5];
    for (var i = 0; i < qd; i++) {
      p = skipName(p) + 4;
    }

    final out = <InternetAddress>[];
    for (var i = 0; i < an && p + 10 <= d.length; i++) {
      p = skipName(p);
      if (p + 10 > d.length) break;
      final type = (d[p] << 8) | d[p + 1];
      final rdlen = (d[p + 8] << 8) | d[p + 9];
      p += 10;
      if (p + rdlen > d.length) break;
      if (type == 1 && rdlen == 4) {
        out.add(InternetAddress.fromRawAddress(
            Uint8List.fromList(d.sublist(p, p + 4)),
            type: InternetAddressType.IPv4));
      } else if (type == 28 && rdlen == 16) {
        out.add(InternetAddress.fromRawAddress(
            Uint8List.fromList(d.sublist(p, p + 16)),
            type: InternetAddressType.IPv6));
      }
      p += rdlen;
    }
    return out;
  }
}

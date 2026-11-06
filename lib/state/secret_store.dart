import 'dart:convert';
import 'dart:io';

/// Защищённое хранение паролей: шифрование средствами Windows (DPAPI).
/// Зашифрованное значение можно расшифровать только в учётной записи Windows,
/// где оно было создано.
class SecretStore {
  SecretStore._();

  static const _protectScript =
      r'$b = [Console]::In.ReadLine(); '
      r'$s = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b)); '
      r'ConvertTo-SecureString $s -AsPlainText -Force | ConvertFrom-SecureString';

  static const _unprotectScript =
      r'$e = [Console]::In.ReadLine(); '
      r'$ss = ConvertTo-SecureString $e; '
      r'$p = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss); '
      r'$t = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($p); '
      r'[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p); '
      r'[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($t))';

  static Future<String> _run(String script, String input) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
          'Защищённое хранение паролей работает только в Windows');
    }
    final p = await Process.start(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
    );
    p.stdin.writeln(input);
    await p.stdin.close();
    final results = await Future.wait([
      p.stdout.transform(utf8.decoder).join(),
      p.stderr.transform(utf8.decoder).join(),
      p.exitCode,
    ]);
    final out = (results[0] as String).trim();
    if (results[2] != 0 || out.isEmpty) {
      throw StateError('Не удалось обработать пароль');
    }
    return out;
  }

  static Future<String> protect(String plain) =>
      _run(_protectScript, base64Encode(utf8.encode(plain)));

  static Future<String> unprotect(String encrypted) async {
    final b64 = await _run(_unprotectScript, encrypted);
    return utf8.decode(base64Decode(b64));
  }
}

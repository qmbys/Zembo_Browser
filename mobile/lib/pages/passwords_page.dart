import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';
import '../state/app_keys.dart';
import '../state/passwords_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/site_icon.dart';

class PasswordsPage extends StatelessWidget {
  final PasswordsController passwords;
  const PasswordsPage({super.key, required this.passwords});

  void _confirmDeleteAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Точно удалить все пароли?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      passwords.deleteAll();
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD64545),
                        foregroundColor: Colors.white),
                    child: const Text('Удалить все пароли'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.chrome,
        title: const Text('Управление паролями'),
        actions: [
          ListenableBuilder(
            listenable: passwords,
            builder: (context, _) => passwords.count == 0
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: tr('Удалить все пароли'),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _confirmDeleteAll(context),
                  ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: passwords,
        builder: (context, _) {
          final items = passwords.items;
          final never = passwords.neverHosts;
          if (items.isEmpty && never.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Войдите на любой сайт — браузер предложит сохранить пароль',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }
          return ListView(
            children: [
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                  child: Text('Сохранённые пароли (${items.length})',
                      style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ),
              for (final l in items)
                ListTile(
                  leading: SiteIcon(
                    url: 'https://${l.host}',
                    label: l.host,
                    iconUrl:
                        'https://www.google.com/s2/favicons?sz=64&domain=${l.host}',
                    size: 28,
                  ),
                  title: Text(l.host, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    l.username.isEmpty ? '(без логина)' : l.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => _openLogin(context, l),
                ),
              if (never.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 6),
                  child: Text('Пароли не сохраняются для',
                      style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ),
                for (final h in never)
                  ListTile(
                    title: Text(h),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
                      onPressed: () => passwords.removeNever(h),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _openLogin(BuildContext context, SavedLogin l) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LoginSheet(passwords: passwords, login: l),
    );
  }
}

class _LoginSheet extends StatefulWidget {
  final PasswordsController passwords;
  final SavedLogin login;
  const _LoginSheet({required this.passwords, required this.login});

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  String? _password;
  bool _shown = false;
  Timer? _clip;

  @override
  void dispose() {
    _clip?.cancel();
    super.dispose();
  }

  Future<String?> _load() async {
    _password ??= await widget.passwords.reveal(widget.login.id);
    if (_password == null) toast('Не удалось расшифровать пароль');
    return _password;
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    // Буфер обмена очищаем через полминуты.
    _clip?.cancel();
    _clip = Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.login;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.host,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.username.isEmpty ? '(без логина)' : l.username,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              if (l.username.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copy(l.username),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _shown ? (_password ?? '') : '••••••••••',
                  style: const TextStyle(fontSize: 15, letterSpacing: 1),
                ),
              ),
              IconButton(
                tooltip: tr(_shown ? 'Скрыть пароль' : 'Показать пароль'),
                icon: Icon(_shown ? Icons.visibility_off : Icons.visibility,
                    size: 20),
                onPressed: () async {
                  if (_shown) {
                    setState(() => _shown = false);
                    return;
                  }
                  final p = await _load();
                  if (p != null && mounted) setState(() => _shown = true);
                },
              ),
              IconButton(
                tooltip: tr('Скопировать пароль'),
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () async {
                  final p = await _load();
                  if (p != null) _copy(p);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                widget.passwords.delete(l.id);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
              label: const Text('Удалить',
                  style: TextStyle(color: Color(0xFFFF6B6B))),
            ),
          ),
        ],
      ),
    );
  }
}

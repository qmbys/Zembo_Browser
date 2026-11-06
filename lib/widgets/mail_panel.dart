import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';

import '../state/app_settings.dart';
import '../state/mail_controller.dart';
import '../theme/app_theme.dart';
import 'panel_frame.dart';

enum _MailView { accounts, add, inbox, message }

/// Панель «Почта»: привязка ящиков, входящие письма, чтение письма.
class MailPanel extends StatefulWidget {
  final MailController mail;
  final AppSettings settings;
  final void Function(String url) onOpenUrl;
  const MailPanel({
    super.key,
    required this.mail,
    required this.settings,
    required this.onOpenUrl,
  });

  @override
  State<MailPanel> createState() => _MailPanelState();
}

class _MailPanelState extends State<MailPanel> {
  _MailView _view = _MailView.accounts;
  MailAccount? _account;
  MailItem? _item;

  // форма добавления
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '993');
  late final TextEditingController _gId =
      TextEditingController(text: widget.settings.googleClientId);
  late final TextEditingController _gSecret =
      TextEditingController(text: widget.settings.googleClientSecret);
  bool _showGoogleSetup = false;
  bool _showReading = false;
  MailProvider _provider = MailController.providers.first;
  bool _auto = true;
  bool _secure = true;
  bool _showPass = false;
  bool _busy = false;
  String? _error;

  MailController get mail => widget.mail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _host.dispose();
    _port.dispose();
    _gId.dispose();
    _gSecret.dispose();
    super.dispose();
  }

  // ---------- действия ----------

  void _openAdd() {
    setState(() {
      _view = _MailView.add;
      _error = null;
      _email.clear();
      _password.clear();
      _auto = true;
      _showReading = false;
      _provider = MailController.providers.first;
    });
  }

  /// Только адрес: без пароля.
  Future<void> _submitAddress() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await mail.addAddressOnly(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) _view = _MailView.accounts;
    });
  }

  /// Для сохранённого адреса подключаем чтение писем.
  void _upgrade(MailAccount a) {
    _openAdd();
    setState(() {
      _email.text = a.email;
      final p = MailController.providerForEmail(a.email);
      if (p != null) _provider = p;
      _showReading = true;
    });
  }

  void _openInbox(MailAccount a) {
    setState(() {
      _account = a;
      _view = _MailView.inbox;
    });
    mail.refresh(a.id);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await mail.addAccount(
      email: _email.text,
      password: _password.text,
      providerId: _provider.id,
      host: _host.text,
      port: int.tryParse(_port.text.trim()) ?? 993,
      secure: _secure,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) {
        _view = _MailView.accounts;
        _password.clear();
      }
    });
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await mail.addGoogleAccount();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) _view = _MailView.accounts;
    });
  }

  Widget _googleBlock() {
    final s = widget.settings;
    final ready = s.googleClientId.isNotEmpty && s.googleClientSecret.isNotEmpty;
    final showSetup = !ready || _showGoogleSetup;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF171B20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 18, color: AppColors.orange),
              SizedBox(width: 8),
              Text('Вход через Google без пароля',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Страница входа Google откроется в обычном браузере. Подтверждение придёт так же, как при любом входе в Google: на телефон или другим способом. Пароль в Zembo вводить не нужно.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
          if (showSetup) ...[
            const SizedBox(height: 10),
            const Text(
              'Один раз настрой вход (бесплатно, около 3 минут):\n'
              '1. Открой Google Cloud Console и создай проект.\n'
              '2. «Credentials» → «Create credentials» → «OAuth client ID», тип «Desktop app». '
              'Если попросят настроить экран согласия: тип External, свою почту добавь в Test users.\n'
              '3. Вставь Client ID и Client secret ниже.',
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45),
            ),
            TextButton(
              onPressed: () => widget
                  .onOpenUrl('https://console.cloud.google.com/apis/credentials'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  alignment: Alignment.centerLeft),
              child: const Text('Открыть Google Cloud Console'),
            ),
            _field(_gId, 'Client ID', onChanged: (v) {
              s.googleClientId = v;
              setState(() {});
            }),
            const SizedBox(height: 8),
            _field(_gSecret, 'Client secret', onChanged: (v) {
              s.googleClientSecret = v;
              setState(() {});
            }),
            const SizedBox(height: 6),
            const Text(
              'Пока приложение в режиме Testing, Google может просить входить заново раз в 7 дней. Чтобы этого не было, на экране согласия нажми «Publish app» — для личного использования проверка Google не нужна.',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
            ),
          ] else
            TextButton(
              onPressed: () => setState(() => _showGoogleSetup = true),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  alignment: Alignment.centerLeft),
              child: const Text('Данные приложения Google'),
            ),
          const SizedBox(height: 10),
          _PrimaryButton(
            label: _busy ? 'Жду вход в браузере…' : 'Войти через Google',
            onTap: (_busy || !ready) ? null : _submitGoogle,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(MailAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14171B),
        title: const Text('Отвязать почту?',
            style: TextStyle(color: AppColors.foreground, fontSize: 16)),
        content: Text(
          '${a.email} исчезнет из браузера. Сами письма на сервере не удаляются.',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Отвязать')),
        ],
      ),
    );
    if (ok == true) {
      await mail.removeAccount(a.id);
      if (mounted) setState(() => _view = _MailView.accounts);
    }
  }

  // ---------- оформление ----------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mail,
      builder: (context, _) {
        switch (_view) {
          case _MailView.accounts:
            return PanelFrame(
              title: 'Почта',
              width: 420,
              action: mail.hasAccounts
                  ? _IconBtn(
                      icon: Icons.add, tooltip: tr('Добавить почту'), onTap: _openAdd)
                  : null,
              child: _accounts(),
            );
          case _MailView.add:
            return PanelFrame(title: 'Добавить почту', width: 420, child: _add());
          case _MailView.inbox:
            return PanelFrame(
              title: 'Входящие',
              width: 420,
              action: _inboxActions(),
              child: _inbox(),
            );
          case _MailView.message:
            return PanelFrame(title: 'Письмо', width: 420, child: _message());
        }
      },
    );
  }

  Widget _back(VoidCallback onTap, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onTap,
            style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12.5)),
          ),
        ),
      );

  // ---------- список ящиков ----------

  Widget _accounts() {
    if (!mail.hasAccounts) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text('Почта не привязана',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground)),
            const SizedBox(height: 6),
            const Text(
              'Привяжи почту, чтобы читать входящие и выбирать адрес при входе на сайтах.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            _PrimaryButton(label: 'Добавить почту', onTap: _openAdd),
          ],
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        for (final a in mail.accounts) _accountTile(a),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.fromLTRB(6, 6, 6, 0),
          child: Text(
            'При входе на сайтах браузер предложит эти адреса.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _accountTile(MailAccount a) {
    final box = mail.boxOf(a.id);
    final provider = MailController.providerById(a.providerId);
    final unseen = box.unseen ?? 0;
    String sub;
    if (a.authType == 'none') {
      sub = 'Только адрес · письма не читаются';
    } else if (box.loading && box.updated == null) {
      sub = 'Проверяю…';
    } else if (box.error != null) {
      sub = 'Не удалось получить письма';
    } else if (box.unseen != null) {
      sub = unseen > 0 ? 'Непрочитанных: $unseen' : 'Новых писем нет';
    } else {
      sub = provider.name;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF171B20)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openInbox(a),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.orange.withValues(alpha: 0.16),
                child: Text(
                  a.email.isEmpty ? '?' : a.email[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.orange, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, color: AppColors.foreground)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: box.error != null
                                ? const Color(0xFFFF6B6B)
                                : (unseen > 0
                                    ? AppColors.orange
                                    : AppColors.muted))),
                  ],
                ),
              ),
              _IconBtn(
                  icon: Icons.delete_outline,
                  tooltip: tr('Отвязать почту'),
                  onTap: () => _confirmRemove(a)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- добавление ----------

  Widget _field(TextEditingController c, String hint,
      {bool obscure = false,
      Widget? suffix,
      ValueChanged<String>? onChanged,
      TextInputType? type}) {
    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: c,
              obscureText: obscure,
              onChanged: onChanged,
              keyboardType: type,
              cursorColor: AppColors.orange,
              style: const TextStyle(fontSize: 14, color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    const TextStyle(fontSize: 14, color: AppColors.muted),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  Widget _add() {
    final other = _provider.id == 'other';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mail.hasAccounts)
            Transform.translate(
              offset: const Offset(-8, 0),
              child: _back(() => setState(() => _view = _MailView.accounts),
                  'К списку'),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in MailController.providers)
                GestureDetector(
                  onTap: () => setState(() {
                    _provider = p;
                    _auto = false;
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.id == _provider.id
                          ? AppColors.orange.withValues(alpha: 0.16)
                          : AppColors.field,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: p.id == _provider.id
                              ? AppColors.orange
                              : AppColors.border),
                    ),
                    child: Text(p.name,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: p.id == _provider.id
                                ? AppColors.orange
                                : AppColors.foreground)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _field(_email, 'Адрес почты',
              type: TextInputType.emailAddress, onChanged: (v) {
            if (!_auto) return;
            final p = MailController.providerForEmail(v);
            if (p != null && p.id != _provider.id) setState(() => _provider = p);
          }),
          const SizedBox(height: 12),
          _PrimaryButton(
            label: 'Добавить адрес',
            onTap: _busy ? null : _submitAddress,
          ),
          const SizedBox(height: 8),
          const Text(
            'Без пароля: адрес будет предлагаться при входе на сайтах. Письма в Zembo при этом не читаются, их можно открыть в веб-почте.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFFFF6B6B), height: 1.4)),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => setState(() => _showReading = !_showReading),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 34),
                alignment: Alignment.centerLeft),
            icon: Icon(
                _showReading ? Icons.expand_less : Icons.expand_more,
                size: 18),
            label: const Text('Читать письма в Zembo (нужен доступ к почте)'),
          ),
          if (_showReading) ...[
            if (_provider.id == 'gmail') ...[
              _googleBlock(),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text('Или пароль приложения',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            ],
            const SizedBox(height: 10),
            _field(
              _password,
              _provider.id == 'other' ? 'Пароль' : 'Пароль приложения',
              obscure: !_showPass,
              onChanged: (_) => setState(() {}),
              suffix: IconButton(
                onPressed: () => setState(() => _showPass = !_showPass),
                tooltip: _showPass ? 'Скрыть' : 'Показать',
                splashRadius: 16,
                icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility,
                    size: 18, color: AppColors.muted),
              ),
            ),
            if (_provider.id == 'gmail' &&
                _password.text.isNotEmpty &&
                _password.text.replaceAll(RegExp(r'\s'), '').length != 16)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Похоже на обычный пароль. Gmail по нему не пустит: нужен пароль приложения из 16 букв.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.orange, height: 1.35),
                ),
              ),
            if (other) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _field(_host, 'IMAP-сервер (imap.example.com)')),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 84,
                      child: _field(_port, 'Порт', type: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text('Защищённое соединение (SSL)',
                        style:
                            TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ),
                  Switch(
                    value: _secure,
                    onChanged: (v) => setState(() => _secure = v),
                    activeThumbColor: AppColors.orange,
                  ),
                ],
              ),
            ],
            if (_provider.hint.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_provider.hint,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted, height: 1.4)),
            ],
            if (_provider.helpUrl != null)
              TextButton(
                onPressed: () => widget.onOpenUrl(_provider.helpUrl!),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    alignment: Alignment.centerLeft),
                child: const Text('Как получить пароль приложения'),
              ),
            const SizedBox(height: 12),
            _PrimaryButton(
              label: _busy ? 'Проверяю вход…' : 'Добавить с чтением писем',
              outlined: true,
              onTap: _busy ? null : _submit,
            ),
            const SizedBox(height: 8),
            const Text(
              'Пароль хранится на этом компьютере в зашифрованном виде (защита Windows) и отправляется только твоему почтовому серверу.',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- входящие ----------

  Widget _inboxActions() {
    final a = _account;
    if (a == null) return const SizedBox.shrink();
    final box = mail.boxOf(a.id);
    final web = MailController.providerById(a.providerId).webUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (web != null)
          _IconBtn(
              icon: Icons.open_in_new,
              tooltip: tr('Открыть веб-почту'),
              onTap: () => widget.onOpenUrl(web)),
        if (a.authType != 'none')
          box.loading
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.orange)),
              )
            : _IconBtn(
                icon: Icons.refresh,
                tooltip: tr('Обновить'),
                onTap: () => mail.refresh(a.id)),
      ],
    );
  }

  static String _date(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    if (l.year == now.year && l.month == now.month && l.day == now.day) {
      return '${two(l.hour)}:${two(l.minute)}';
    }
    return '${two(l.day)}.${two(l.month)}';
  }

  Widget _inbox() {
    final a = _account;
    if (a == null) return const SizedBox.shrink();
    if (a.authType == 'none') {
      final web = MailController.providerById(a.providerId).webUrl;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _back(() => setState(() => _view = _MailView.accounts), a.email),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Для этой почты сохранён только адрес: он предлагается при входе на сайтах. Чтобы читать письма прямо в Zembo, нужен доступ к ящику.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.muted, height: 1.45),
                ),
                const SizedBox(height: 14),
                if (web != null) ...[
                  _PrimaryButton(
                      label: 'Открыть веб-почту',
                      onTap: () => widget.onOpenUrl(web)),
                  const SizedBox(height: 8),
                ],
                _PrimaryButton(
                    label: 'Подключить чтение писем',
                    outlined: true,
                    onTap: () => _upgrade(a)),
              ],
            ),
          ),
        ],
      );
    }
    final box = mail.boxOf(a.id);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _back(() => setState(() => _view = _MailView.accounts), a.email),
        if (box.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
            child: Text(box.error!,
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFFFF6B6B), height: 1.4)),
          )
        else if (box.items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            child: Center(
              child: Text(box.loading ? 'Загружаю письма…' : 'Входящие пусты',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: box.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) => _mailRow(box.items[i]),
            ),
          ),
      ],
    );
  }

  Widget _mailRow(MailItem m) {
    final snippet = m.body.replaceAll(RegExp(r'\s+'), ' ');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _item = m;
        _view = _MailView.message;
      }),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          color: AppColors.tile,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF171B20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: m.seen ? Colors.transparent : AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(m.sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    m.seen ? FontWeight.w400 : FontWeight.w600,
                                color: AppColors.foreground)),
                      ),
                      Text(_date(m.date),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(m.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: m.seen ? FontWeight.w400 : FontWeight.w500,
                          color: const Color(0xFFCAD0D7))),
                  if (snippet.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(snippet,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- письмо ----------

  Widget _message() {
    final m = _item;
    if (m == null) return const SizedBox.shrink();
    final from = m.fromName.isNotEmpty && m.fromEmail.isNotEmpty
        ? '${m.fromName} <${m.fromEmail}>'
        : m.sender;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _back(() => setState(() => _view = _MailView.inbox), 'Входящие'),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(m.subject,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground)),
              const SizedBox(height: 6),
              Text(from,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              if (m.date != null)
                Text(
                    '${m.date!.toLocal().day.toString().padLeft(2, '0')}.${m.date!.toLocal().month.toString().padLeft(2, '0')}.${m.date!.toLocal().year} '
                    '${m.date!.toLocal().hour.toString().padLeft(2, '0')}:${m.date!.toLocal().minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF22272D)),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  m.body.isEmpty ? '(в письме нет текста)' : m.body,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFFCAD0D7)),
                ),
                if (m.hasAttachments)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                        'В письме есть вложения — открой его в веб-почте, чтобы их скачать.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          splashRadius: 16,
          icon: Icon(icon, size: 18, color: const Color(0xFFCAD0D7)),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 40,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor:
                outlined ? Colors.transparent : AppColors.orange,
            side: outlined
                ? BorderSide(
                    color: onTap == null
                        ? AppColors.orange.withValues(alpha: 0.4)
                        : AppColors.orange)
                : null,
            disabledBackgroundColor:
                outlined ? Colors.transparent : AppColors.orange.withValues(alpha: 0.4),
            foregroundColor: outlined ? AppColors.orange : Colors.white,
            disabledForegroundColor:
                outlined ? AppColors.orange.withValues(alpha: 0.5) : Colors.white70,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
      );
}
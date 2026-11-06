import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import '../state/suggest_service.dart';
import '../theme/app_theme.dart';
import 'suggest_anchor.dart';

class SearchField extends StatefulWidget {
  final ValueChanged<String>? onSubmit;
  final SuggestService? service;
  final String initialText;
  const SearchField({
    super.key,
    this.onSubmit,
    this.service,
    this.initialText = '',
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController controller =
      TextEditingController(text: widget.initialText);
  final focus = FocusNode();

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  void submit() {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    widget.onSubmit?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final field = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 19),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFFC4CBD2), size: 23),
          const SizedBox(width: 17),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              onSubmitted: (_) => submit(),
              style: const TextStyle(color: AppColors.foreground, fontSize: 15),
              cursorColor: AppColors.orange,
              decoration: InputDecoration(
                hintText: tr('Поиск в интернете или введите адрес'),
                hintStyle: TextStyle(color: AppColors.muted, fontSize: 15),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          IconButton(
            onPressed: submit,
            icon: const Icon(Icons.arrow_forward, color: Color(0xFFADB6C0)),
            splashRadius: 20,
          ),
        ],
      ),
    );

    final service = widget.service;
    if (service == null) return field;

    // Подсказки под строкой поиска.
    return SuggestAnchor(
      controller: controller,
      focusNode: focus,
      service: service,
      onPick: (s) {
        focus.unfocus();
        widget.onSubmit?.call(s.url ?? s.text);
      },
      child: field,
    );
  }
}

import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../state/history_controller.dart';
import '../theme/app_theme.dart';

class HistoryPage extends StatelessWidget {
  final HistoryController history;
  final ValueChanged<String> onOpen;
  const HistoryPage({super.key, required this.history, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.chrome,
        title: const Text('История'),
        actions: [
          TextButton(
            onPressed: () => history.clear(),
            child: const Text('Очистить',
                style: TextStyle(color: AppColors.orange)),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: history,
        builder: (context, _) {
          final items = history.items;
          if (items.isEmpty) {
            return const Center(
              child: Text('История пуста',
                  style: TextStyle(color: AppColors.muted)),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFF16191D)),
            itemBuilder: (context, i) {
              final e = items[i];
              return ListTile(
                title: Text(e.title.isEmpty ? e.url : e.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(e.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                  onPressed: () => history.remove(e),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onOpen(e.url);
                },
              );
            },
          );
        },
      ),
    );
  }
}

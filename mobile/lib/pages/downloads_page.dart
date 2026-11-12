import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../state/downloads_controller.dart';
import '../theme/app_theme.dart';

class DownloadsPage extends StatelessWidget {
  final DownloadsController downloads;
  const DownloadsPage({super.key, required this.downloads});

  String _status(DownloadItem e) {
    switch (e.status) {
      case DlStatus.running:
        return 'Скачивание… ${(e.progress * 100).round()}%';
      case DlStatus.done:
        return 'Сохранено в «Загрузки»';
      case DlStatus.canceled:
        return 'Отменено';
      case DlStatus.failed:
        return e.error ?? 'Не удалось скачать';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.chrome,
        title: const Text('Загрузки'),
        actions: [
          TextButton(
            onPressed: downloads.clearFinished,
            child: const Text('Очистить',
                style: TextStyle(color: AppColors.orange)),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: downloads,
        builder: (context, _) {
          final items = downloads.items;
          if (items.isEmpty) {
            return const Center(
              child: Text('Загрузок пока нет',
                  style: TextStyle(color: AppColors.muted)),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFF16191D)),
            itemBuilder: (context, i) {
              final e = items[i];
              final running = e.status == DlStatus.running;
              return ListTile(
                leading: Icon(
                  e.status == DlStatus.done
                      ? Icons.insert_drive_file_outlined
                      : (running ? Icons.downloading : Icons.error_outline),
                  color: e.status == DlStatus.failed
                      ? const Color(0xFFFF6B6B)
                      : AppColors.orange,
                ),
                title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (running)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: LinearProgressIndicator(
                          value: e.progress > 0 ? e.progress : null,
                          minHeight: 3,
                          color: AppColors.orange,
                          backgroundColor: const Color(0xFF2B3036),
                        ),
                      ),
                    Text(
                      _status(e),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(running ? Icons.close : Icons.delete_outline,
                      size: 20, color: AppColors.muted),
                  onPressed: () =>
                      running ? downloads.cancel(e) : downloads.remove(e),
                ),
                onTap: e.status == DlStatus.done ? () => downloads.open(e) : null,
              );
            },
          );
        },
      ),
    );
  }
}

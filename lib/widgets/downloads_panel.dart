import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n/i18n.dart';
import '../state/downloads_controller.dart';
import '../theme/app_theme.dart';
import 'panel_frame.dart';

/// Панель «Загрузки».
class DownloadsPanel extends StatelessWidget {
  final DownloadsController downloads;
  const DownloadsPanel({super.key, required this.downloads});

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: 'Загрузки',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TextAction(label: 'Папка', onTap: downloads.openDownloadsFolder),
          _TextAction(label: 'Очистить', onTap: downloads.clearFinished),
        ],
      ),
      child: DownloadsList(downloads: downloads),
    );
  }
}

/// Список загрузок (используется в панели и на странице настроек).
class DownloadsList extends StatefulWidget {
  final DownloadsController downloads;

  /// false — список без своей прокрутки (внутри страницы настроек).
  final bool scrollable;
  const DownloadsList({
    super.key,
    required this.downloads,
    this.scrollable = true,
  });

  @override
  State<DownloadsList> createState() => _DownloadsListState();
}

class _DownloadsListState extends State<DownloadsList> {
  Timer? _timer;

  DownloadsController get downloads => widget.downloads;

  @override
  void initState() {
    super.initState();
    // Пока список открыт, следим, не удалили ли файлы вне браузера.
    downloads.refreshMissing();
    _timer = Timer.periodic(
        const Duration(seconds: 3), (_) => downloads.refreshMissing());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: downloads,
      builder: (context, _) {
        final items = downloads.items;
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Center(
              child: Text('Загрузок пока нет',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: widget.scrollable ? null : const NeverScrollableScrollPhysics(),
          padding: widget.scrollable
              ? const EdgeInsets.fromLTRB(12, 0, 12, 12)
              : EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              _DownloadRow(item: items[i], downloads: downloads),
        );
      },
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: AppColors.muted,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  final DownloadItem item;
  final DownloadsController downloads;
  const _DownloadRow({required this.item, required this.downloads});

  static String _size(int bytes) {
    final units = [tr('Б'), tr('КБ'), tr('МБ'), tr('ГБ')];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  String get _status {
    switch (item.status) {
      case DownloadStatus.inProgress:
        final t = item.total;
        final parts = <String>[];
        if (t != null && t > 0) {
          final pct = (item.received * 100 / t).floor();
          parts.add('${_size(item.received)} из ${_size(t)}');
          parts.add('$pct%');
        } else {
          parts.add(_size(item.received));
        }
        if (item.speed > 0) parts.add(DownloadsController.formatSpeed(item.speed));
        final eta = item.eta;
        if (eta != null) parts.add('ещё ${DownloadsController.formatEta(eta)}');
        return parts.join(' · ');
      case DownloadStatus.completed:
        if (item.missing) return 'Файл удалён или перемещён';
        return 'Завершено · ${_size(item.total ?? item.received)}';
      case DownloadStatus.failed:
        return 'Не удалось скачать';
      case DownloadStatus.cancelled:
        return 'Отменено';
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = item.status == DownloadStatus.completed;
    final bad = item.status == DownloadStatus.failed;
    final gone = done && item.missing;
    final canAgain = downloads.canRedownload(item);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF171B20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                bad ? Icons.error_outline : Icons.insert_drive_file_outlined,
                size: 22,
                color: bad ? const Color(0xFFFF6B6B) : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: gone ? AppColors.muted : AppColors.foreground,
                        decoration: gone ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: bad ? const Color(0xFFFF6B6B) : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (done && !gone) ...[
                _IconAction(
                    icon: Icons.open_in_new,
                    tooltip: tr('Открыть'),
                    onTap: () => downloads.openFile(item.id)),
                _IconAction(
                    icon: Icons.folder_open,
                    tooltip: tr('Показать в папке'),
                    onTap: () => downloads.showInFolder(item.id)),
              ],
              // Файла нет или загрузка не удалась — можно скачать снова.
              if ((gone || item.status == DownloadStatus.failed ||
                      item.status == DownloadStatus.cancelled) &&
                  canAgain)
                _IconAction(
                    icon: Icons.refresh,
                    tooltip: tr('Скачать снова'),
                    onTap: () => downloads.redownload(item.id)),
              if (item.status == DownloadStatus.inProgress && !item.external)
                _IconAction(
                    icon: Icons.stop_circle_outlined,
                    tooltip: tr('Отменить'),
                    onTap: () => downloads.cancel(item.id))
              else if (item.status == DownloadStatus.inProgress)
                _IconAction(
                    icon: Icons.close,
                    tooltip: tr('Убрать из списка'),
                    onTap: () => downloads.remove(item.id))
              else if (done)
                // Корзина: удаляет файл и запись; если файла нет — только запись.
                _IconAction(
                    icon: Icons.delete_outline,
                    tooltip: gone ? 'Убрать из списка' : 'Удалить файл',
                    onTap: () => downloads.deleteFile(item.id))
              else
                _IconAction(
                    icon: Icons.close,
                    tooltip: tr('Убрать из списка'),
                    onTap: () => downloads.remove(item.id)),
            ],
          ),
          if (item.status == DownloadStatus.inProgress) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 3,
                  color: AppColors.orange,
                  backgroundColor: AppColors.field,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconAction(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        splashRadius: 15,
        icon: Icon(icon, size: 17, color: const Color(0xFFCAD0D7)),
      ),
    );
  }
}

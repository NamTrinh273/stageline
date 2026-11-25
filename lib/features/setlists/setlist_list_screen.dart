import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/storage/storage.dart';
import '../../core/theme/stageline_theme.dart';
import '../concert_mode/concert_mode_screen.dart';
import '../share/share.dart';
import 'demo_setlist_seed.dart';
import 'setlist_detail_screen.dart';

/// Home screen listing all offline concert setlists.
class SetlistListScreen extends ConsumerWidget {
  const SetlistListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.graphic_eq,
              color: StageLineColors.singAlongGold,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'StageLine',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('home_scan_qr_btn'),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Quét QR bài hát',
            onPressed: () => _scanSongQr(context, ref),
          ),
          IconButton(
            key: const ValueKey('home_import_file_btn'),
            icon: const Icon(Icons.file_open_outlined),
            tooltip: 'Nhập tệp .concert / .lrc / .txt',
            onPressed: () => _importFromFile(context, ref),
          ),
          IconButton(
            key: const ValueKey('home_seed_demo_btn'),
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Nạp Setlist Demo',
            onPressed: () async {
              await ref
                  .read(setlistsProvider.notifier)
                  .saveSetlist(buildDemoSetlist());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã nạp Setlist Demo V-Pop & US-UK.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: setlistsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Lỗi đọc dữ liệu offline: $err',
              style: const TextStyle(color: StageLineColors.danger),
            ),
          ),
        ),
        data: (setlists) {
          if (setlists.isEmpty) {
            return _EmptyHomeState(
              onCreateNew: () => _showCreateSetlistDialog(context, ref),
              onLoadDemo: () => ref
                  .read(setlistsProvider.notifier)
                  .saveSetlist(buildDemoSetlist()),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: setlists.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final setlist = setlists[index];
              return Card(
                key: ValueKey('setlist_card_${setlist.id}'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SetlistDetailScreen(setlistId: setlist.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                setlist.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: StageLineColors.primaryText,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (setlist.artist.isNotEmpty) setlist.artist,
                                  '${setlist.songs.length} bài hát',
                                ].join(' • '),
                                style: const TextStyle(
                                  color: StageLineColors.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (setlist.songs.isNotEmpty)
                          IconButton(
                            key: ValueKey('quick_play_${setlist.id}'),
                            icon: const Icon(
                              Icons.play_circle_fill,
                              color: StageLineColors.singAlongGold,
                              size: 32,
                            ),
                            tooltip: 'Vào Concert Mode ngay',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ConcertModeScreen(setlist: setlist),
                                ),
                              );
                            },
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: StageLineColors.translationText,
                          ),
                          tooltip: 'Xóa Setlist',
                          onPressed: () =>
                              _confirmDeleteSetlist(context, ref, setlist),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('home_create_setlist_fab'),
        onPressed: () => _showCreateSetlistDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tạo Setlist'),
      ),
    );
  }

  Future<void> _showCreateSetlistDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final titleCtrl = TextEditingController();
    final artistCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StageLineColors.surface,
        title: const Text('Tạo Concert Setlist mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('create_setlist_title'),
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên Concert / Setlist',
                hintText: 'VD: Tour 2026 - Đêm 1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('create_setlist_artist'),
              controller: artistCtrl,
              decoration: const InputDecoration(
                labelText: 'Nghệ sĩ (tùy chọn)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const ValueKey('create_setlist_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    final title = titleCtrl.text.trim();
    final artist = artistCtrl.text.trim();
    titleCtrl.dispose();
    artistCtrl.dispose();

    if (created == true && title.isNotEmpty) {
      final id =
          'setlist-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      final setlist = Setlist(
        id: id,
        title: title,
        artist: artist,
        songs: const [],
      );
      await ref.read(setlistsProvider.notifier).saveSetlist(setlist);
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SetlistDetailScreen(setlistId: id),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteSetlist(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StageLineColors.surface,
        title: const Text('Xóa Setlist?'),
        content: Text('Xóa "${setlist.title}" khỏi máy?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: StageLineColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(setlistsProvider.notifier).deleteSetlist(setlist.id);
    }
  }

  Future<void> _scanSongQr(BuildContext context, WidgetRef ref) async {
    final scannedSong = await Navigator.of(context).push<Song>(
      MaterialPageRoute<Song>(builder: (_) => const QrScannerScreen()),
    );
    if (scannedSong == null || !context.mounted) return;
    await _assignAndSaveSong(context, ref, scannedSong);
  }

  Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
    const shareService = StageLineShareService();
    try {
      final result = await shareService.pickAndImportFile();
      if (result == null || !context.mounted) return;

      switch (result) {
        case ImportedSetlist(:final setlist):
          await ref.read(setlistsProvider.notifier).saveSetlist(setlist);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đã nhập setlist "${setlist.title}" (${setlist.songs.length} bài).',
                ),
              ),
            );
          }
        case ImportedSong(:final song):
          await _assignAndSaveSong(context, ref, song);
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không thể nhập tệp: $e')));
      }
    }
  }

  Future<void> _assignAndSaveSong(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) async {
    final existing = ref.read(setlistsProvider).value ?? const <Setlist>[];
    final target = await showAssignSongToSetlistDialog(
      context,
      existingSetlists: existing,
      song: song,
    );
    if (target == null) return;
    await ref.read(setlistsProvider.notifier).saveSetlist(target);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm "${song.title}" vào "${target.title}".'),
        ),
      );
    }
  }
}

class _EmptyHomeState extends StatelessWidget {
  const _EmptyHomeState({required this.onCreateNew, required this.onLoadDemo});

  final VoidCallback onCreateNew;
  final VoidCallback onLoadDemo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.queue_music,
              size: 56,
              color: StageLineColors.singAlongGold,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sẵn sàng cho đêm concert',
              style: TextStyle(
                color: StageLineColors.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tạo setlist riêng hoặc nạp ngay bộ demo V-Pop & US-UK để trải nghiệm Concert Mode OLED chống chói.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: StageLineColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('empty_load_demo_btn'),
              onPressed: onLoadDemo,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Nạp Setlist Demo ngay'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCreateNew,
              icon: const Icon(Icons.add),
              label: const Text('Tạo Setlist mới'),
            ),
          ],
        ),
      ),
    );
  }
}

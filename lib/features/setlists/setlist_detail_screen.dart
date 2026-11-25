import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/storage/storage.dart';
import '../../core/theme/stageline_theme.dart';
import '../concert_mode/concert_mode_screen.dart';
import '../share/share.dart';
import 'quick_lyrics_editor_screen.dart';

/// Displays songs in a [Setlist] with drag-to-reorder, quick edit, and 1-tap Concert Mode launch.
class SetlistDetailScreen extends ConsumerWidget {
  const SetlistDetailScreen({super.key, required this.setlistId});

  final String setlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistsProvider);

    return setlistsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Setlist')),
        body: Center(child: Text('Không thể tải setlist: $err')),
      ),
      data: (setlists) {
        final match = setlists.where((s) => s.id == setlistId);
        if (match.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Setlist')),
            body: const Center(child: Text('Setlist không còn tồn tại.')),
          );
        }
        final setlist = match.first;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (setlist.artist.isNotEmpty)
                  Text(
                    setlist.artist,
                    style: const TextStyle(
                      color: StageLineColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                key: const ValueKey('detail_export_concert_btn'),
                icon: const Icon(Icons.ios_share),
                tooltip: 'Xuất tệp .concert',
                onPressed: () => _exportSetlist(context, setlist),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Sửa tên Setlist',
                onPressed: () => _editSetlistMetadata(context, ref, setlist),
              ),
              if (setlist.songs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.icon(
                    key: const ValueKey('detail_start_concert_btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: StageLineColors.singAlongGold,
                      foregroundColor: StageLineColors.background,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => _openConcertMode(context, setlist, 0),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text(
                      'Concert',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          body: setlist.songs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.music_note_outlined,
                          size: 48,
                          color: StageLineColors.translationText,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có bài hát nào trong setlist này.',
                          style: TextStyle(
                            color: StageLineColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _addSong(context, ref, setlist),
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm bài hát đầu tiên'),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: setlist.songs.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    final songs = List<Song>.from(setlist.songs);
                    final moved = songs.removeAt(oldIndex);
                    songs.insert(newIndex, moved);
                    await ref
                        .read(setlistsProvider.notifier)
                        .saveSetlist(setlist.copyWith(songs: songs));
                  },
                  itemBuilder: (context, index) {
                    final song = setlist.songs[index];
                    final singAlongCount = song.sections
                        .where((s) => s.singAlong)
                        .length;

                    return Card(
                      key: ValueKey('song_row_${song.id}'),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: StageLineColors.activeSurface,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: StageLineColors.singAlongGold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: StageLineColors.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${song.sections.length} đoạn • ${song.totalLines} dòng'
                          '${singAlongCount > 0 ? ' • $singAlongCount sing-along' : ''}',
                          style: const TextStyle(
                            color: StageLineColors.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => _openConcertMode(context, setlist, index),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey('song_qr_btn_${song.id}'),
                              icon: const Icon(Icons.qr_code_2, size: 20),
                              color: StageLineColors.singAlongGold,
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Chia sẻ QR bài hát',
                              onPressed: () => showSongQrSheet(
                                context,
                                song: song,
                                onExportSetlistFallback: () =>
                                    _exportSetlist(context, setlist),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: StageLineColors.secondaryText,
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Sửa lời',
                              onPressed: () =>
                                  _editSong(context, ref, setlist, index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: StageLineColors.secondaryText,
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Xóa bài',
                              onPressed: () =>
                                  _deleteSong(context, ref, setlist, index),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.drag_handle,
                                  color: StageLineColors.translationText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            key: const ValueKey('detail_add_song_fab'),
            onPressed: () => _addSong(context, ref, setlist),
            icon: const Icon(Icons.add),
            label: const Text('Thêm bài'),
          ),
        );
      },
    );
  }

  void _openConcertMode(BuildContext context, Setlist setlist, int songIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ConcertModeScreen(setlist: setlist, initialSongIndex: songIndex),
      ),
    );
  }

  Future<void> _addSong(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final created = await Navigator.of(context).push<Song>(
      MaterialPageRoute<Song>(builder: (_) => const QuickLyricsEditorScreen()),
    );
    if (created == null) return;
    final updatedSongs = [...setlist.songs, created];
    await ref
        .read(setlistsProvider.notifier)
        .saveSetlist(setlist.copyWith(songs: updatedSongs));
  }

  Future<void> _editSong(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    int index,
  ) async {
    final edited = await Navigator.of(context).push<Song>(
      MaterialPageRoute<Song>(
        builder: (_) =>
            QuickLyricsEditorScreen(initialSong: setlist.songs[index]),
      ),
    );
    if (edited == null) return;
    final updatedSongs = List<Song>.from(setlist.songs)..[index] = edited;
    await ref
        .read(setlistsProvider.notifier)
        .saveSetlist(setlist.copyWith(songs: updatedSongs));
  }

  Future<void> _deleteSong(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    int index,
  ) async {
    final updatedSongs = List<Song>.from(setlist.songs)..removeAt(index);
    await ref
        .read(setlistsProvider.notifier)
        .saveSetlist(setlist.copyWith(songs: updatedSongs));
  }

  Future<void> _editSetlistMetadata(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final titleCtrl = TextEditingController(text: setlist.title);
    final artistCtrl = TextEditingController(text: setlist.artist);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StageLineColors.surface,
        title: const Text('Sửa thông tin Setlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên Concert / Setlist',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistCtrl,
              decoration: const InputDecoration(labelText: 'Nghệ sĩ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (saved == true && titleCtrl.text.trim().isNotEmpty) {
      await ref
          .read(setlistsProvider.notifier)
          .saveSetlist(
            setlist.copyWith(
              title: titleCtrl.text.trim(),
              artist: artistCtrl.text.trim(),
            ),
          );
    }
    titleCtrl.dispose();
    artistCtrl.dispose();
  }

  Future<void> _exportSetlist(BuildContext context, Setlist setlist) async {
    const shareService = StageLineShareService();
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await shareService.exportSetlist(setlist, sharePositionOrigin: origin);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không thể xuất tệp: $e')));
      }
    }
  }
}

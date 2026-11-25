import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/parser/parser.dart';
import '../../core/theme/stageline_theme.dart';

/// Result of importing a local `.concert`, `.json`, `.lrc`, or `.txt` file.
sealed class ImportedConcertData {
  const ImportedConcertData();
}

/// An entire [Setlist] decoded from a `.concert` or `.json` file.
final class ImportedSetlist extends ImportedConcertData {
  const ImportedSetlist(this.setlist);

  final Setlist setlist;
}

/// A single [Song] parsed from a `.lrc` or `.txt` lyrics file.
final class ImportedSong extends ImportedConcertData {
  const ImportedSong(this.song);

  final Song song;
}

/// Offline export & file import helper for StageLine setlists and lyrics.
class StageLineShareService {
  const StageLineShareService({
    this.concertCodec = const ConcertCodec(),
    this.lyricsParser = const LyricsParser(),
  });

  final ConcertCodec concertCodec;
  final LyricsParser lyricsParser;

  /// Encodes [setlist] as plain UTF-8 `.concert` JSON, writes it to a temporary
  /// `<slug>.concert` file, and invokes the native share sheet.
  Future<void> exportSetlist(
    Setlist setlist, {
    Rect? sharePositionOrigin,
  }) async {
    final bytes = concertCodec.encodeSetlistBytes(setlist, compressed: false);
    final tempDir = await getTemporaryDirectory();
    final fileName = '${_slugifyFilename(setlist.title)}.concert';
    final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, name: fileName)],
        subject: setlist.title,
        title: setlist.title,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Opens the native file picker with [FileType.any] so `.concert`, `.json`,
  /// `.lrc`, and `.txt` files work reliably on Android & iOS without MIME blocks.
  ///
  /// Returns `null` if the user cancels the picker.
  /// Throws [FormatException] with a clear Vietnamese message on unsupported
  /// extensions or corrupt payloads.
  Future<ImportedConcertData?> pickAndImportFile() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) {
      return null;
    }

    List<int> bytes;
    try {
      bytes = await picked.readAsBytes();
    } on Object {
      final path = picked.path;
      if (path != null && path.isNotEmpty) {
        bytes = await File(path).readAsBytes();
      } else {
        throw const FormatException(
          'Không thể đọc dữ liệu từ tệp đã chọn. Vui lòng thử lại.',
        );
      }
    }

    return parseImportedBytes(fileName: picked.name, bytes: bytes);
  }

  /// Pure parser for raw imported file bytes, usable directly in unit tests.
  ///
  /// Supports `.concert`, `.json` (decoded into [ImportedSetlist]) and `.lrc`,
  /// `.txt` (parsed into [ImportedSong]).
  /// Throws [FormatException] with a Vietnamese message for unsupported formats
  /// or invalid/corrupt content.
  ImportedConcertData parseImportedBytes({
    required String fileName,
    required List<int> bytes,
  }) {
    final baseName = _extractBaseName(fileName);
    final extension = _extractLowerExtension(baseName);

    if (bytes.isEmpty) {
      throw const FormatException('Tệp được chọn đang trống.');
    }

    switch (extension) {
      case 'concert':
      case 'json':
        try {
          final setlist = concertCodec.decodeSetlistBytes(bytes);
          return ImportedSetlist(setlist);
        } on ConcertFormatException catch (e) {
          throw FormatException(
            'Tệp .$extension không hợp lệ hoặc bị hỏng: ${e.message}',
          );
        } on FormatException catch (e) {
          throw FormatException(
            'Tệp .$extension không đúng định dạng StageLine: ${e.message}',
          );
        }

      case 'lrc':
      case 'txt':
        final String text;
        try {
          text = utf8.decode(bytes);
        } on FormatException {
          throw FormatException(
            'Tệp .$extension không phải văn bản UTF-8 hợp lệ.',
          );
        }

        if (text.trim().isEmpty) {
          throw const FormatException('Tệp lời bài hát không có nội dung.');
        }

        final fallbackTitle = _stripExtension(baseName);
        final song = lyricsParser.parseRawText(
          text,
          fallbackTitle: fallbackTitle.isEmpty ? 'Bài hát mới' : fallbackTitle,
        );
        if (song.sections.isEmpty) {
          throw const FormatException(
            'Không tìm thấy đoạn lời nào trong tệp đã chọn.',
          );
        }
        return ImportedSong(song);

      default:
        final extLabel = extension.isEmpty
            ? 'không có phần mở rộng'
            : '.$extension';
        throw FormatException(
          'Định dạng tệp không được hỗ trợ ($extLabel). '
          'Vui lòng chọn tệp .concert, .json, .lrc hoặc .txt.',
        );
    }
  }

  static String _slugifyFilename(String title) {
    final lower = title.toLowerCase().trim();
    final ascii = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = ascii.replaceAll(RegExp(r'^-+|-+$'), '');
    if (trimmed.isEmpty) {
      return 'stageline-setlist';
    }
    return trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed;
  }

  static String _extractBaseName(String fileName) {
    final normalized = fileName.replaceAll('\\', '/');
    final slashIndex = normalized.lastIndexOf('/');
    return slashIndex >= 0 ? normalized.substring(slashIndex + 1) : normalized;
  }

  static String _extractLowerExtension(String baseName) {
    final dotIndex = baseName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == baseName.length - 1) {
      return '';
    }
    return baseName.substring(dotIndex + 1).toLowerCase();
  }

  static String _stripExtension(String baseName) {
    final dotIndex = baseName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return baseName.trim();
    }
    return baseName.substring(0, dotIndex).trim();
  }
}

/// Shows an OLED dialog allowing the user to assign an imported/scanned [song]
/// to one of [existingSetlists] or create a brand-new [Setlist] titled after
/// [song].
///
/// Returns the updated or newly created [Setlist] ready to be persisted, or
/// `null` if cancelled.
Future<Setlist?> showAssignSongToSetlistDialog(
  BuildContext context, {
  required List<Setlist> existingSetlists,
  required Song song,
}) {
  return showDialog<Setlist>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: StageLineColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: StageLineColors.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Lưu bài hát vào Setlist',
              style: TextStyle(
                color: StageLineColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              song.artist != null && song.artist!.isNotEmpty
                  ? '${song.title} • ${song.artist}'
                  : song.title,
              style: const TextStyle(
                color: StageLineColors.singAlongGold,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CreateNewSetlistTile(
                    songTitle: song.title,
                    onTap: () {
                      final newSetlist = _createSetlistForSong(song);
                      Navigator.of(dialogContext).pop<Setlist>(newSetlist);
                    },
                  ),
                  if (existingSetlists.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Hoặc thêm vào setlist hiện có',
                      style: TextStyle(
                        color: StageLineColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final setlist in existingSetlists) ...[
                      _ExistingSetlistTile(
                        setlist: setlist,
                        onTap: () {
                          final updated = _appendSongToSetlist(setlist, song);
                          Navigator.of(dialogContext).pop<Setlist>(updated);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop<Setlist>(),
            child: const Text(
              'Hủy',
              style: TextStyle(color: StageLineColors.secondaryText),
            ),
          ),
        ],
      );
    },
  );
}

Setlist _createSetlistForSong(Song song) {
  final slug = song.title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final prefix = slug.isEmpty ? 'setlist' : slug;
  final uniqueId =
      '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  return Setlist(
    id: uniqueId,
    title: song.title,
    artist: song.artist ?? '',
    songs: <Song>[song],
    updatedAt: DateTime.now().toUtc(),
  );
}

Setlist _appendSongToSetlist(Setlist setlist, Song song) {
  final existingIds = setlist.songs.map((s) => s.id).toSet();
  final resolvedSong = existingIds.contains(song.id)
      ? song.copyWith(
          id: '${song.id}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
        )
      : song;

  return setlist.copyWith(
    songs: <Song>[...setlist.songs, resolvedSong],
    updatedAt: DateTime.now().toUtc(),
  );
}

class _CreateNewSetlistTile extends StatelessWidget {
  const _CreateNewSetlistTile({required this.songTitle, required this.onTap});

  final String songTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StageLineColors.singAlongSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: StageLineColors.singAlongGold),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                color: StageLineColors.singAlongGold,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tạo setlist mới',
                      style: TextStyle(
                        color: StageLineColors.singAlongGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      songTitle,
                      style: const TextStyle(
                        color: StageLineColors.secondaryText,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExistingSetlistTile extends StatelessWidget {
  const _ExistingSetlistTile({required this.setlist, required this.onTap});

  final Setlist setlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StageLineColors.activeSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: StageLineColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.queue_music,
                color: StageLineColors.primaryText,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setlist.title,
                      style: const TextStyle(
                        color: StageLineColors.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${setlist.songs.length} bài hát',
                      style: const TextStyle(
                        color: StageLineColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: StageLineColors.secondaryText,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

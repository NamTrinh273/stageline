import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/parser/parser.dart';
import '../../core/theme/stageline_theme.dart';

/// Fast paste & edit screen for creating or fixing a concert [Song].
/// Supports `[Verse 1]`, `[Chorus]`, `[Sing-along]`, `.lrc` timestamps, and `> translation`.
class QuickLyricsEditorScreen extends StatefulWidget {
  const QuickLyricsEditorScreen({super.key, this.initialSong});

  final Song? initialSong;

  @override
  State<QuickLyricsEditorScreen> createState() =>
      _QuickLyricsEditorScreenState();
}

class _QuickLyricsEditorScreenState extends State<QuickLyricsEditorScreen> {
  static const _parser = LyricsParser();
  static const _qrCodec = QrSongCodec();

  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _lyricsController;

  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSong;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _artistController = TextEditingController(text: initial?.artist ?? '');
    _lyricsController = TextEditingController(
      text: initial != null ? _parser.toEditableText(initial) : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Song _buildParsedSong() {
    return _parser.parseRawText(
      _lyricsController.text,
      fallbackTitle: _titleController.text.trim().isEmpty
          ? 'Bài hát mới'
          : _titleController.text.trim(),
      id: widget.initialSong?.id,
      artist: _artistController.text.trim().isEmpty
          ? null
          : _artistController.text.trim(),
    );
  }

  void _insertSnippet(String snippet) {
    final text = _lyricsController.text;
    final selection = _lyricsController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final prefix = start > 0 && text[start - 1] != '\n' ? '\n' : '';
    final insert = '$prefix$snippet';
    final updated = text.replaceRange(start, end, insert);
    _lyricsController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    setState(() {});
  }

  void _save() {
    final song = _buildParsedSong();
    if (song.sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy nhập ít nhất 1 dòng lời bài hát.')),
      );
      return;
    }
    Navigator.of(context).pop(song);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _buildParsedSong();
    final qrLen = parsed.sections.isEmpty
        ? 0
        : _qrCodec.estimateEncodedLength(parsed);
    final qrFits = qrLen <= QrSongCodec.maxEncodedChars;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialSong == null ? 'Thêm bài hát' : 'Sửa lời bài hát',
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            child: Text(_showPreview ? 'Soạn lời' : 'Xem trước'),
          ),
          TextButton(
            key: const ValueKey('editor_save_btn'),
            onPressed: _save,
            child: const Text(
              'Lưu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      key: const ValueKey('editor_title_field'),
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tên bài hát',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _artistController,
                      decoration: const InputDecoration(
                        labelText: 'Nghệ sĩ (tùy chọn)',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Live status bar: sections, lines, and single-QR budget indicator.
              Row(
                children: [
                  Text(
                    '${parsed.sections.length} đoạn • ${parsed.totalLines} dòng',
                    style: const TextStyle(
                      color: StageLineColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: qrFits
                          ? StageLineColors.surface
                          : const Color(0xFF2B1414),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: qrFits
                            ? StageLineColors.border
                            : StageLineColors.danger,
                      ),
                    ),
                    child: Text(
                      qrFits
                          ? 'QR: $qrLen/${QrSongCodec.maxEncodedChars}'
                          : 'Vượt QR ($qrLen) → dùng file .concert',
                      style: TextStyle(
                        color: qrFits
                            ? StageLineColors.secondaryText
                            : StageLineColors.danger,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (!_showPreview) ...[
                // Quick-insert concert tags
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final tag in const [
                        '[Verse 1]\n',
                        '[Pre-Chorus]\n',
                        '[Chorus]\n',
                        '[Sing-along]\n',
                        '[Bridge]\n',
                        '> ',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              tag.trim(),
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    tag.contains('Chorus') &&
                                            !tag.contains('Pre') ||
                                        tag.contains('Sing-along')
                                    ? StageLineColors.singAlongGold
                                    : StageLineColors.primaryText,
                              ),
                            ),
                            backgroundColor: StageLineColors.surface,
                            side: const BorderSide(
                              color: StageLineColors.border,
                            ),
                            onPressed: () => _insertSnippet(tag),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TextField(
                    key: const ValueKey('editor_lyrics_field'),
                    controller: _lyricsController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: StageLineColors.primaryText,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Dán lời bài hát (.txt hoặc .lrc)...\n\n'
                          '[Verse 1]\n'
                          'Câu lời gốc\n'
                          '> Dòng dịch ngắn (tùy chọn)\n\n'
                          '[Chorus]\n'
                          'Đoạn hát chung sẽ tự highlight vàng!',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ] else
                Expanded(
                  child: parsed.sections.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có nội dung để xem trước.',
                            style: TextStyle(
                              color: StageLineColors.secondaryText,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: parsed.sections.length,
                          itemBuilder: (context, idx) {
                            final sec = parsed.sections[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: sec.singAlong
                                    ? StageLineColors.singAlongSurface
                                    : StageLineColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sec.singAlong
                                      ? StageLineColors.singAlongGold
                                      : StageLineColors.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${sec.tag.toUpperCase()} (${sec.shortLabel})'
                                    '${sec.singAlong ? ' ★ SING-ALONG' : ''}',
                                    style: TextStyle(
                                      color: sec.singAlong
                                          ? StageLineColors.singAlongGold
                                          : StageLineColors.secondaryText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  for (final line in sec.lines) ...[
                                    Text(
                                      line.text,
                                      style: const TextStyle(
                                        color: StageLineColors.primaryText,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (line.hasTranslation)
                                      Text(
                                        line.translation!,
                                        style: const TextStyle(
                                          color:
                                              StageLineColors.translationText,
                                          fontSize: 13,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

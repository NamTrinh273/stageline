import '../models/models.dart';

/// Parses raw `.txt` and `.lrc` lyrics into structured concert [Song] models.
class LyricsParser {
  const LyricsParser();

  static final RegExp _lrcTimestampPrefix = RegExp(
    r'^\s*(?:\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\])+\s*',
  );

  static final RegExp _lrcMetaTag = RegExp(
    r'^\[(ti|ar|al|au|by|offset|length|re|ve):(.*)\]$',
    caseSensitive: false,
  );

  static final RegExp _sectionHeader = RegExp(r'^\[(.+)\]$');

  static final RegExp _preChorusPattern = RegExp(
    r'\bpre[\s-]?chorus\b',
    caseSensitive: false,
  );

  static final RegExp _singAlongPattern = RegExp(
    r'(chorus|sing[\s-]?along|crowd|hook|fan|điệp\s*khúc|hát\s*chung)',
    caseSensitive: false,
  );

  /// Parses raw `.txt` or `.lrc` text into a [Song].
  ///
  /// - Strips UTF-8 BOM and normalizes `\r\n` / `\r` line endings.
  /// - Extracts `[ti:...]` and `[ar:...]` from `.lrc` metadata if present.
  /// - Strips leading `.lrc` timestamps (`[01:23.45]`).
  /// - Recognizes `[Section]` headers and auto-flags `singAlong` for chorus /
  ///   sing-along / crowd / hook / fan tags (excluding `Pre-Chorus`).
  /// - Attaches lines starting with `>` or `|` as concise translations (`tr`)
  ///   to the immediately preceding lyric line.
  Song parseRawText(
    String raw, {
    required String fallbackTitle,
    String? id,
    String? artist,
    bool splitUntaggedParagraphs = true,
  }) {
    var normalized = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
    normalized = normalized.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final rawLines = normalized.split('\n');

    String? lrcTitle;
    String? lrcArtist;
    var hasExplicitHeader = false;

    final cleanedEntries = <_ParsedToken>[];

    for (final rawLine in rawLines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        cleanedEntries.add(const _ParsedToken.blank());
        continue;
      }

      // Check LRC metadata headers like [ti:Song Name], [ar:Artist].
      final metaMatch = _lrcMetaTag.firstMatch(trimmed);
      if (metaMatch != null) {
        final key = metaMatch.group(1)!.toLowerCase();
        final value = metaMatch.group(2)!.trim();
        if (key == 'ti' && value.isNotEmpty) {
          lrcTitle = value;
        } else if (key == 'ar' && value.isNotEmpty) {
          lrcArtist = value;
        }
        continue;
      }

      // Strip leading LRC timestamps (supports stacked tags like [00:10.00][01:20.00]).
      final withoutTs = trimmed.replaceFirst(_lrcTimestampPrefix, '').trim();
      if (withoutTs.isEmpty) {
        // Timestamp-only spacer line in .lrc.
        cleanedEntries.add(const _ParsedToken.blank());
        continue;
      }

      // Check section header [Verse 1], [Chorus], [Sing-along], etc.
      final headerMatch = _sectionHeader.firstMatch(withoutTs);
      if (headerMatch != null) {
        final tag = headerMatch.group(1)!.trim();
        if (tag.isNotEmpty) {
          hasExplicitHeader = true;
          cleanedEntries.add(_ParsedToken.header(tag));
          continue;
        }
      }

      // Check inline translation marker: `> Translation` or `| Translation`.
      if (withoutTs.startsWith('>') || withoutTs.startsWith('|')) {
        final trText = withoutTs.substring(1).trim();
        if (trText.isNotEmpty) {
          cleanedEntries.add(_ParsedToken.translation(trText));
        }
        continue;
      }

      cleanedEntries.add(_ParsedToken.lyric(withoutTs));
    }

    final sections = <LyricSection>[];
    String currentTag = 'Verse 1';
    bool currentSingAlong = false;
    var currentLines = <LyricLine>[];
    var untaggedVerseCounter = 1;

    void flushSection() {
      if (currentLines.isNotEmpty) {
        sections.add(
          LyricSection(
            tag: currentTag,
            singAlong: currentSingAlong,
            lines: currentLines,
          ),
        );
        currentLines = <LyricLine>[];
      }
    }

    for (final token in cleanedEntries) {
      switch (token.kind) {
        case _TokenKind.header:
          flushSection();
          currentTag = token.value!;
          currentSingAlong = isSingAlongTag(currentTag);
        case _TokenKind.blank:
          if (!hasExplicitHeader &&
              splitUntaggedParagraphs &&
              currentLines.isNotEmpty) {
            flushSection();
            untaggedVerseCounter++;
            currentTag = 'Verse $untaggedVerseCounter';
            currentSingAlong = false;
          }
        case _TokenKind.lyric:
          currentLines.add(LyricLine(text: token.value!));
        case _TokenKind.translation:
          if (currentLines.isNotEmpty) {
            final last = currentLines.removeLast();
            final combinedTr = last.hasTranslation
                ? '${last.translation} ${token.value!}'
                : token.value!;
            currentLines.add(last.copyWith(translation: combinedTr));
          }
      }
    }
    flushSection();

    final resolvedTitle = (lrcTitle != null && lrcTitle.isNotEmpty)
        ? lrcTitle
        : (fallbackTitle.trim().isEmpty
              ? 'Untitled Song'
              : fallbackTitle.trim());
    final resolvedArtist = (artist != null && artist.trim().isNotEmpty)
        ? artist.trim()
        : lrcArtist;
    final resolvedId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : _generateSongId(resolvedTitle);

    return Song(
      id: resolvedId,
      title: resolvedTitle,
      artist: resolvedArtist,
      sections: sections,
    );
  }

  /// Determines whether a section header tag should auto-highlight as sing-along.
  static bool isSingAlongTag(String tag) {
    final trimmed = tag.trim();
    if (_preChorusPattern.hasMatch(trimmed)) {
      return false;
    }
    return _singAlongPattern.hasMatch(trimmed);
  }

  /// Converts a structured [Song] back into clean editable plain text for the quick editor.
  String toEditableText(Song song) {
    final buf = StringBuffer();
    for (var sIdx = 0; sIdx < song.sections.length; sIdx++) {
      final section = song.sections[sIdx];
      if (sIdx > 0) buf.writeln();
      final header = section.singAlong && !isSingAlongTag(section.tag)
          ? '[${section.tag} - Sing-along]'
          : '[${section.tag}]';
      buf.writeln(header);
      for (final line in section.lines) {
        buf.writeln(line.text);
        if (line.hasTranslation) {
          buf.writeln('> ${line.translation!}');
        }
      }
    }
    return buf.toString().trimRight();
  }

  static String _generateSongId(String title) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'song' : slug;
    return '$base-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
  }
}

enum _TokenKind { blank, header, lyric, translation }

class _ParsedToken {
  const _ParsedToken._(this.kind, [this.value]);

  const _ParsedToken.blank() : this._(_TokenKind.blank);
  const _ParsedToken.header(String tag) : this._(_TokenKind.header, tag);
  const _ParsedToken.lyric(String text) : this._(_TokenKind.lyric, text);
  const _ParsedToken.translation(String tr)
    : this._(_TokenKind.translation, tr);

  final _TokenKind kind;
  final String? value;
}

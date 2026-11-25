import 'package:flutter/foundation.dart';

import 'lyric_line.dart';

/// A named section inside a song (e.g. Verse 1, Chorus, Bridge, Sing-along).
@immutable
class LyricSection {
  LyricSection({
    required this.tag,
    required List<LyricLine> lines,
    this.singAlong = false,
  }) : lines = List<LyricLine>.unmodifiable(lines);

  /// Section label shown in Quick Section Jump (e.g. `Verse 1`, `Chorus`).
  final String tag;

  /// Whether this section is highlighted for crowd sing-along.
  final bool singAlong;

  /// Ordered immutable list of lyric lines in this section.
  final List<LyricLine> lines;

  /// Compact pill label for the Quick Section Jump bar.
  String get shortLabel {
    final clean = tag.trim();
    final lower = clean.toLowerCase();

    final verseMatch = RegExp(r'^verse\s*(\d+)?$').firstMatch(lower);
    if (verseMatch != null) {
      final numPart = verseMatch.group(1);
      return numPart != null ? 'V$numPart' : 'V';
    }
    if (lower.startsWith('pre-chorus') ||
        lower.startsWith('pre chorus') ||
        lower.startsWith('prechorus')) {
      return 'Pre';
    }
    if (lower.startsWith('post-chorus') || lower.startsWith('post chorus')) {
      return 'Post';
    }
    if (lower.contains('chorus') || lower.contains('điệp khúc')) {
      return 'CHORUS';
    }
    if (lower.contains('sing-along') ||
        lower.contains('singalong') ||
        lower.contains('hát chung') ||
        lower.contains('crowd')) {
      return 'SING';
    }
    if (lower.startsWith('bridge')) return 'Bridge';
    if (lower.startsWith('intro')) return 'Intro';
    if (lower.startsWith('outro')) return 'Outro';
    if (lower.startsWith('rap')) return 'Rap';
    if (clean.length <= 8) return clean;
    return clean.substring(0, 8);
  }

  LyricSection copyWith({
    String? tag,
    bool? singAlong,
    List<LyricLine>? lines,
  }) {
    return LyricSection(
      tag: tag ?? this.tag,
      singAlong: singAlong ?? this.singAlong,
      lines: lines ?? this.lines,
    );
  }

  factory LyricSection.fromJson(Map<String, dynamic> json) {
    final rawTag = json['tag'];
    final rawLines = json['lines'];
    if (rawTag is! String || rawTag.trim().isEmpty) {
      throw const FormatException('LyricSection requires non-empty "tag".');
    }
    if (rawLines is! List) {
      throw const FormatException('LyricSection requires list field "lines".');
    }
    final parsedLines = rawLines
        .map((e) {
          if (e is! Map<String, dynamic>) {
            throw const FormatException('Each lyric line must be a JSON map.');
          }
          return LyricLine.fromJson(e);
        })
        .toList(growable: false);

    return LyricSection(
      tag: rawTag.trim(),
      singAlong: json['singAlong'] == true,
      lines: parsedLines,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tag': tag,
      'singAlong': singAlong,
      'lines': lines.map((l) => l.toJson()).toList(growable: false),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricSection &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          singAlong == other.singAlong &&
          listEquals(lines, other.lines);

  @override
  int get hashCode => Object.hash(tag, singAlong, Object.hashAll(lines));

  @override
  String toString() =>
      'LyricSection(tag: $tag, singAlong: $singAlong, lines: ${lines.length})';
}

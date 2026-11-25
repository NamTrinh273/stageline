import 'package:flutter/foundation.dart';

import 'lyric_line.dart';
import 'lyric_section.dart';

/// Flattened pointer to a single line inside a [Song] for O(1) Tap-to-Advance.
@immutable
class FlatLyricEntry {
  const FlatLyricEntry({
    required this.flatIndex,
    required this.sectionIndex,
    required this.lineIndexInSection,
    required this.section,
    required this.line,
  });

  final int flatIndex;
  final int sectionIndex;
  final int lineIndexInSection;
  final LyricSection section;
  final LyricLine line;

  bool get isSectionStart => lineIndexInSection == 0;
}

/// A single song with structured sections for concert reading.
@immutable
class Song {
  Song({
    required this.id,
    required this.title,
    required List<LyricSection> sections,
    this.artist,
  }) : sections = List<LyricSection>.unmodifiable(sections);

  final String id;
  final String title;

  /// Optional per-song artist override (useful for multi-artist concerts).
  final String? artist;

  final List<LyricSection> sections;

  int get totalLines =>
      sections.fold<int>(0, (sum, section) => sum + section.lines.length);

  bool get hasTranslations =>
      sections.any((s) => s.lines.any((l) => l.hasTranslation));

  /// Returns a flat list of all lines with their section metadata.
  List<FlatLyricEntry> flattenLines() {
    final entries = <FlatLyricEntry>[];
    var flatIdx = 0;
    for (var sIdx = 0; sIdx < sections.length; sIdx++) {
      final section = sections[sIdx];
      for (var lIdx = 0; lIdx < section.lines.length; lIdx++) {
        entries.add(
          FlatLyricEntry(
            flatIndex: flatIdx++,
            sectionIndex: sIdx,
            lineIndexInSection: lIdx,
            section: section,
            line: section.lines[lIdx],
          ),
        );
      }
    }
    return entries;
  }

  /// Returns the starting flat line index for [sectionIndex], or 0 if invalid.
  int firstLineIndexForSection(int sectionIndex) {
    if (sectionIndex <= 0 || sectionIndex >= sections.length) return 0;
    var offset = 0;
    for (var i = 0; i < sectionIndex; i++) {
      offset += sections[i].lines.length;
    }
    return offset;
  }

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    bool clearArtist = false,
    List<LyricSection>? sections,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: clearArtist ? null : (artist ?? this.artist),
      sections: sections ?? this.sections,
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawTitle = json['title'];
    final rawSections = json['sections'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('Song requires non-empty string "id".');
    }
    if (rawTitle is! String || rawTitle.trim().isEmpty) {
      throw const FormatException('Song requires non-empty string "title".');
    }
    if (rawSections is! List) {
      throw const FormatException('Song requires list field "sections".');
    }
    final rawArtist = json['artist'];
    final parsedArtist = rawArtist is String && rawArtist.trim().isNotEmpty
        ? rawArtist.trim()
        : null;

    final parsedSections = rawSections
        .map((e) {
          if (e is! Map<String, dynamic>) {
            throw const FormatException('Each section must be a JSON map.');
          }
          return LyricSection.fromJson(e);
        })
        .toList(growable: false);

    return Song(
      id: rawId.trim(),
      title: rawTitle.trim(),
      artist: parsedArtist,
      sections: parsedSections,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      'sections': sections.map((s) => s.toJson()).toList(growable: false),
    };
    if (artist != null && artist!.trim().isNotEmpty) {
      map['artist'] = artist!.trim();
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          artist == other.artist &&
          listEquals(sections, other.sections);

  @override
  int get hashCode => Object.hash(id, title, artist, Object.hashAll(sections));

  @override
  String toString() =>
      'Song(id: $id, title: $title, sections: ${sections.length})';
}

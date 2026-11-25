import 'package:flutter/foundation.dart';

import 'song.dart';

/// A concert setlist containing an ordered list of [Song]s.
/// Matches canonical `.concert` schema v1.
@immutable
class Setlist {
  Setlist({
    required this.id,
    required this.title,
    required List<Song> songs,
    this.artist = '',
    DateTime? updatedAt,
    this.schemaVersion = currentSchemaVersion,
  }) : songs = List<Song>.unmodifiable(songs),
       updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  static const int currentSchemaVersion = 1;

  /// Schema version integer (JSON key: `v`).
  final int schemaVersion;

  final String id;

  /// Concert / setlist title (JSON key: `setlist`).
  final String title;

  /// Primary artist name (JSON key: `artist`).
  final String artist;

  /// Last modified timestamp in UTC (JSON key: `updatedAt`).
  final DateTime updatedAt;

  /// Ordered songs in the concert setlist.
  final List<Song> songs;

  Setlist copyWith({
    String? id,
    String? title,
    String? artist,
    DateTime? updatedAt,
    List<Song>? songs,
    int? schemaVersion,
  }) {
    return Setlist(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      updatedAt: updatedAt ?? this.updatedAt,
      songs: songs ?? this.songs,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  factory Setlist.fromJson(Map<String, dynamic> json) {
    final version = json['v'];
    if (version is! int) {
      throw const FormatException('Setlist requires integer field "v".');
    }
    if (version != currentSchemaVersion) {
      throw FormatException(
        'Unsupported .concert schema version: $version '
        '(supported: $currentSchemaVersion).',
      );
    }

    final rawTitle = json['setlist'];
    if (rawTitle is! String || rawTitle.trim().isEmpty) {
      throw const FormatException(
        'Setlist requires non-empty string field "setlist".',
      );
    }

    final rawId = json['id'];
    final resolvedId = rawId is String && rawId.trim().isNotEmpty
        ? rawId.trim()
        : _slugify(rawTitle);

    final rawArtist = json['artist'];
    final artist = rawArtist is String ? rawArtist.trim() : '';

    final rawUpdatedAt = json['updatedAt'];
    DateTime updatedAt;
    if (rawUpdatedAt is String && rawUpdatedAt.trim().isNotEmpty) {
      updatedAt =
          DateTime.tryParse(rawUpdatedAt)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      updatedAt = DateTime.now().toUtc();
    }

    final rawSongs = json['songs'];
    if (rawSongs is! List) {
      throw const FormatException('Setlist requires list field "songs".');
    }
    final parsedSongs = rawSongs
        .map((e) {
          if (e is! Map<String, dynamic>) {
            throw const FormatException('Each song must be a JSON map.');
          }
          return Song.fromJson(e);
        })
        .toList(growable: false);

    return Setlist(
      schemaVersion: version,
      id: resolvedId,
      title: rawTitle.trim(),
      artist: artist,
      updatedAt: updatedAt,
      songs: parsedSongs,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'v': schemaVersion,
      'id': id,
      'setlist': title,
      'artist': artist,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'songs': songs.map((s) => s.toJson()).toList(growable: false),
    };
  }

  static String _slugify(String input) {
    final lower = input.toLowerCase().trim();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final trimmed = replaced.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.isEmpty ? 'setlist' : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Setlist &&
          runtimeType == other.runtimeType &&
          schemaVersion == other.schemaVersion &&
          id == other.id &&
          title == other.title &&
          artist == other.artist &&
          updatedAt == other.updatedAt &&
          listEquals(songs, other.songs);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    id,
    title,
    artist,
    updatedAt,
    Object.hashAll(songs),
  );

  @override
  String toString() =>
      'Setlist(id: $id, title: $title, songs: ${songs.length})';
}

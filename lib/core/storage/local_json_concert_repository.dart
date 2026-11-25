import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../parser/parser.dart';
import 'concert_repository.dart';

/// Plain-JSON offline [ConcertRepository] backed by `dart:io` files.
///
/// Stores each setlist as `<root>/setlists/<safe_id>.concert` with atomic
/// temp-file writes to prevent corruption if the app is killed mid-write.
class LocalJsonConcertRepository implements ConcertRepository {
  LocalJsonConcertRepository({
    Future<Directory> Function()? baseDirectoryProvider,
    this.codec = const ConcertCodec(),
    this.lyricsParser = const LyricsParser(),
  }) : _baseDirectoryProvider =
           baseDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectoryProvider;
  final ConcertCodec codec;
  final LyricsParser lyricsParser;

  static const String fileExtension = '.concert';

  Future<Directory> _setlistsDir() async {
    final baseDir = await _baseDirectoryProvider();
    final dir = Directory('${baseDir.path}${Platform.pathSeparator}setlists');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File _fileForId(Directory dir, String id) {
    final safeId = _sanitizeFileName(id);
    return File('${dir.path}${Platform.pathSeparator}$safeId$fileExtension');
  }

  @override
  Future<List<Setlist>> loadAll() async {
    final dir = await _setlistsDir();
    final entities = await dir.list(followLinks: false).toList();
    final setlists = <Setlist>[];

    for (final entity in entities) {
      if (entity is! File || !entity.path.endsWith(fileExtension)) {
        continue;
      }
      try {
        final bytes = await entity.readAsBytes();
        setlists.add(codec.decodeSetlistBytes(bytes));
      } on Object {
        // Skip corrupted files rather than crashing the whole app at a concert.
        continue;
      }
    }

    setlists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return setlists;
  }

  @override
  Future<Setlist?> loadById(String id) async {
    final dir = await _setlistsDir();
    final file = _fileForId(dir, id);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      return codec.decodeSetlistBytes(bytes);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(Setlist setlist) async {
    final dir = await _setlistsDir();
    final targetFile = _fileForId(dir, setlist.id);
    final tempFile = File('${targetFile.path}.tmp');

    final normalized = setlist.copyWith(updatedAt: setlist.updatedAt.toUtc());
    final bytes = codec.encodeSetlistBytes(normalized, compressed: false);

    await tempFile.writeAsBytes(bytes, flush: true);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetFile.path);
  }

  @override
  Future<void> delete(String id) async {
    final dir = await _setlistsDir();
    final file = _fileForId(dir, id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<File> exportToFile(
    Setlist setlist, {
    required Directory targetDir,
    bool compressed = false,
  }) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final safeName = _sanitizeFileName(
      setlist.title.isNotEmpty ? setlist.title : setlist.id,
    );
    final outFile = File(
      '${targetDir.path}${Platform.pathSeparator}$safeName$fileExtension',
    );
    final bytes = codec.encodeSetlistBytes(
      setlist,
      compressed: compressed,
      pretty: !compressed,
    );
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }

  @override
  Future<Setlist> importFromFile(File file) async {
    if (!await file.exists()) {
      throw ConcertFormatException('File not found: ${file.path}');
    }

    final fileName = _basename(file.path);
    final lower = fileName.toLowerCase();

    Setlist imported;
    if (lower.endsWith('.concert') || lower.endsWith('.json')) {
      final bytes = await file.readAsBytes();
      imported = codec.decodeSetlistBytes(bytes);
    } else if (lower.endsWith('.txt') || lower.endsWith('.lrc')) {
      final raw = await file.readAsString();
      final stem = _stripExtension(fileName);
      final song = lyricsParser.parseRawText(raw, fallbackTitle: stem);
      imported = Setlist(
        id: 'imported-${_sanitizeFileName(stem)}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
        title: song.title,
        artist: song.artist ?? '',
        songs: [song],
      );
    } else {
      throw ConcertFormatException(
        'Unsupported file extension for "$fileName". Expected .concert, .json, .lrc, or .txt.',
      );
    }

    await save(imported);
    return imported;
  }

  static String _sanitizeFileName(String raw) {
    final sanitized = raw
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'\.{2,}'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (sanitized.isEmpty) return 'setlist';
    return sanitized.length > 64 ? sanitized.substring(0, 64) : sanitized;
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx == -1 ? normalized : normalized.substring(idx + 1);
  }

  static String _stripExtension(String fileName) {
    final idx = fileName.lastIndexOf('.');
    return idx <= 0 ? fileName : fileName.substring(0, idx);
  }
}

import 'dart:js_interop';

import '../models/models.dart';
import '../parser/parser.dart';
import 'concert_repository.dart';

@JS('window.localStorage')
external _WebStorage get _localStorage;

extension type _WebStorage(JSObject _) implements JSObject {
  external int get length;
  external String? key(int index);
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// Offline browser `localStorage`-backed [ConcertRepository] for StageLine Web PWA.
class WebLocalStorageConcertRepository implements ConcertRepository {
  WebLocalStorageConcertRepository({ConcertCodec? codec})
    : _codec = codec ?? const ConcertCodec();

  static const String _keyPrefix = 'stageline:v1:setlist:';

  final ConcertCodec _codec;

  String _storageKey(String id) {
    final sanitized = id.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (sanitized.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Setlist ID cannot be empty.');
    }
    return '$_keyPrefix$sanitized';
  }

  @override
  Future<List<Setlist>> loadAll() async {
    final results = <Setlist>[];
    final count = _localStorage.length;
    for (var i = 0; i < count; i++) {
      final k = _localStorage.key(i);
      if (k == null || !k.startsWith(_keyPrefix)) continue;
      final raw = _localStorage.getItem(k);
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        results.add(_codec.decodeSetlistString(raw));
      } on Object {
        // Skip corrupted entries so one broken item never blocks concert reading.
      }
    }
    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  @override
  Future<Setlist?> loadById(String id) async {
    final raw = _localStorage.getItem(_storageKey(id));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return _codec.decodeSetlistString(raw);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(Setlist setlist) async {
    final json = _codec.encodeSetlist(setlist);
    _localStorage.setItem(_storageKey(setlist.id), json);
  }

  @override
  Future<void> delete(String id) async {
    _localStorage.removeItem(_storageKey(id));
  }
}

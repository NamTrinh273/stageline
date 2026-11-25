import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'parser_exceptions.dart';

/// Encodes and decodes canonical `.concert` v1 JSON payloads (plain or gzip-compressed).
class ConcertCodec {
  const ConcertCodec();

  /// Maximum decompressed `.concert` setlist size (5 MB) to guard against zip bombs.
  static const int maxDecompressedSetlistBytes = 5 * 1024 * 1024;

  static const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

  /// Serializes [setlist] into UTF-8 JSON conforming to `.concert` schema v1.
  String encodeSetlist(Setlist setlist, {bool pretty = false}) {
    final map = setlist.toJson();
    return pretty ? _prettyEncoder.convert(map) : jsonEncode(map);
  }

  /// Serializes [setlist] into raw UTF-8 JSON bytes or gzip-compressed `.concert` bytes.
  List<int> encodeSetlistBytes(
    Setlist setlist, {
    bool compressed = false,
    bool pretty = false,
  }) {
    final utf8Bytes = utf8.encode(encodeSetlist(setlist, pretty: pretty));
    return compressed ? gzip.encode(utf8Bytes) : utf8Bytes;
  }

  /// Decodes a UTF-8 JSON `.concert` string into a validated [Setlist].
  Setlist decodeSetlistString(String raw) {
    final cleaned = _stripBom(raw).trim();
    if (cleaned.isEmpty) {
      throw const ConcertFormatException('Empty .concert payload.');
    }
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) {
        throw const ConcertFormatException(
          'Expected top-level JSON object for .concert setlist.',
        );
      }
      return Setlist.fromJson(decoded);
    } on ConcertFormatException {
      rethrow;
    } on FormatException catch (e) {
      throw ConcertFormatException(
        'Invalid .concert JSON structure.',
        cause: e,
      );
    }
  }

  /// Decodes raw bytes from either plain UTF-8 JSON or gzip-compressed `.concert` files.
  Setlist decodeSetlistBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const ConcertFormatException('Empty .concert file.');
    }

    final isGzip = bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B;
    final List<int> payloadBytes;

    if (isGzip) {
      payloadBytes = boundedGzipDecode(
        bytes,
        maxBytes: maxDecompressedSetlistBytes,
      );
    } else {
      if (bytes.length > maxDecompressedSetlistBytes) {
        throw const ConcertFormatException(
          'Setlist file exceeds maximum allowed size of 5 MB.',
        );
      }
      payloadBytes = bytes;
    }

    try {
      final text = utf8.decode(payloadBytes);
      return decodeSetlistString(text);
    } on FormatException catch (e) {
      throw ConcertFormatException(
        'Invalid UTF-8 content in .concert file.',
        cause: e,
      );
    }
  }

  /// Safely decompresses gzip bytes while enforcing a hard [maxBytes] limit.
  static List<int> boundedGzipDecode(
    List<int> compressedBytes, {
    required int maxBytes,
  }) {
    final out = <int>[];
    final sink = _BoundedByteSink(out, maxBytes: maxBytes);
    try {
      final byteSink = gzip.decoder.startChunkedConversion(sink);
      byteSink.add(compressedBytes);
      byteSink.close();
      return out;
    } on ConcertFormatException {
      rethrow;
    } on Object catch (e) {
      throw ConcertFormatException(
        'Failed to decompress gzip payload.',
        cause: e,
      );
    }
  }

  static String _stripBom(String input) =>
      input.startsWith('\uFEFF') ? input.substring(1) : input;
}

class _BoundedByteSink implements Sink<List<int>> {
  _BoundedByteSink(this._buffer, {required this.maxBytes});

  final List<int> _buffer;
  final int maxBytes;

  @override
  void add(List<int> data) {
    if (_buffer.length + data.length > maxBytes) {
      throw ConcertFormatException(
        'Decompressed payload exceeds safety limit of $maxBytes bytes.',
      );
    }
    _buffer.addAll(data);
  }

  @override
  void close() {}
}

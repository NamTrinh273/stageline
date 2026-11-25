import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'concert_codec.dart';
import 'parser_exceptions.dart';

/// Encodes and decodes a single [Song] into a compact `SL1:` Gzip+Base64Url QR payload.
class QrSongCodec {
  const QrSongCodec();

  /// Protocol prefix identifying StageLine v1 single-song QR codes.
  static const String prefix = 'SL1:';

  /// Hard safety cap for reliable low-light scanning inside dark concert venues.
  static const int maxEncodedChars = 2200;

  /// Hard zip-bomb guard for decompressed single-song JSON (64 KB).
  static const int maxDecompressedBytes = 64 * 1024;

  /// Computes the compressed QR string length without throwing.
  int estimateEncodedLength(Song song) => _encodeRaw(song).length;

  /// Encodes [song] into a `SL1:<base64Url(gzip(utf8(json)))>` QR payload.
  ///
  /// Throws [QrPayloadTooLargeException] if the payload exceeds [maxEncodedChars].
  String encode(Song song) {
    final payload = _encodeRaw(song);
    if (payload.length > maxEncodedChars) {
      throw QrPayloadTooLargeException(
        encodedLength: payload.length,
        maxLength: maxEncodedChars,
      );
    }
    return payload;
  }

  /// Decodes a scanned QR string into a validated [Song].
  ///
  /// Throws [ConcertFormatException] if the prefix is missing, base64/gzip is
  /// malformed, decompressed payload exceeds 64 KB, or JSON is invalid.
  Song decode(String payload) {
    final trimmed = payload.trim();
    if (!trimmed.startsWith(prefix)) {
      throw const ConcertFormatException(
        'Unrecognized QR code (expected StageLine prefix "$prefix").',
      );
    }

    final encodedBody = trimmed.substring(prefix.length);
    if (encodedBody.isEmpty) {
      throw const ConcertFormatException('Empty StageLine QR payload.');
    }

    final List<int> compressedBytes;
    try {
      compressedBytes = base64Url.decode(base64Url.normalize(encodedBody));
    } on FormatException catch (e) {
      throw ConcertFormatException(
        'Malformed Base64Url in QR payload.',
        cause: e,
      );
    }

    final decompressedBytes = ConcertCodec.boundedGzipDecode(
      compressedBytes,
      maxBytes: maxDecompressedBytes,
    );

    try {
      final jsonText = utf8.decode(decompressedBytes);
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) {
        throw const ConcertFormatException(
          'QR payload does not contain a Song JSON object.',
        );
      }
      return Song.fromJson(decoded);
    } on ConcertFormatException {
      rethrow;
    } on FormatException catch (e) {
      throw ConcertFormatException(
        'Invalid Song JSON inside QR payload.',
        cause: e,
      );
    }
  }

  String _encodeRaw(Song song) {
    final jsonBytes = utf8.encode(jsonEncode(song.toJson()));
    final gzipBytes = gzip.encode(jsonBytes);
    final b64 = base64Url.encode(gzipBytes).replaceAll('=', '');
    return '$prefix$b64';
  }
}

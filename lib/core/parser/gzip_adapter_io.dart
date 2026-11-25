import 'dart:io';

import 'parser_exceptions.dart';

/// Encodes [bytes] using native `dart:io` Gzip compression.
List<int> gzipEncodeBytes(List<int> bytes) => gzip.encode(bytes);

/// Safely decompresses gzip [compressedBytes] enforcing a hard [maxBytes] cap.
List<int> gzipDecodeBounded(
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

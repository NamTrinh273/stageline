import 'dart:typed_data';

import 'parser_exceptions.dart';

/// Pure-Dart RFC 1952 stored-block Gzip encoder for Web (zero external packages).
///
/// Produces a 100% standard Gzip stream decodable by native Android/iOS `dart:io`.
List<int> gzipEncodeBytes(List<int> bytes) {
  final out = BytesBuilder(copy: false);
  // 10-byte RFC 1952 Gzip header: ID1, ID2, CM=8 (DEFLATE), FLG=0, MTIME=0, XFL=0, OS=255.
  out.add(const <int>[
    0x1F,
    0x8B,
    0x08,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0xFF,
  ]);

  // Write uncompressed DEFLATE stored blocks (max 65,535 bytes per block).
  var offset = 0;
  do {
    final remaining = bytes.length - offset;
    final chunkLen = remaining > 65535 ? 65535 : remaining;
    final isFinal = (offset + chunkLen) >= bytes.length;
    final nlen = (~chunkLen) & 0xFFFF;
    out.add(<int>[
      isFinal ? 0x01 : 0x00,
      chunkLen & 0xFF,
      (chunkLen >> 8) & 0xFF,
      nlen & 0xFF,
      (nlen >> 8) & 0xFF,
    ]);
    if (chunkLen > 0) {
      out.add(bytes.sublist(offset, offset + chunkLen));
    }
    offset += chunkLen;
  } while (offset < bytes.length);

  final crc = _crc32(bytes);
  final isize = bytes.length & 0xFFFFFFFF;
  out.add(<int>[
    crc & 0xFF,
    (crc >> 8) & 0xFF,
    (crc >> 16) & 0xFF,
    (crc >> 24) & 0xFF,
    isize & 0xFF,
    (isize >> 8) & 0xFF,
    (isize >> 16) & 0xFF,
    (isize >> 24) & 0xFF,
  ]);
  return out.takeBytes();
}

/// Decodes RFC 1952 stored-block Gzip streams on Web with a hard [maxBytes] cap.
List<int> gzipDecodeBounded(
  List<int> compressedBytes, {
  required int maxBytes,
}) {
  if (compressedBytes.length < 18 ||
      compressedBytes[0] != 0x1F ||
      compressedBytes[1] != 0x8B ||
      compressedBytes[2] != 0x08) {
    throw const ConcertFormatException('Invalid gzip header.');
  }

  final flg = compressedBytes[3];
  var pos = 10;

  if ((flg & 0x04) != 0) {
    if (pos + 2 > compressedBytes.length) {
      throw const ConcertFormatException('Truncated gzip extra field.');
    }
    final xlen = compressedBytes[pos] | (compressedBytes[pos + 1] << 8);
    pos += 2 + xlen;
  }
  if ((flg & 0x08) != 0) {
    while (pos < compressedBytes.length && compressedBytes[pos] != 0) {
      pos++;
    }
    pos++;
  }
  if ((flg & 0x10) != 0) {
    while (pos < compressedBytes.length && compressedBytes[pos] != 0) {
      pos++;
    }
    pos++;
  }
  if ((flg & 0x02) != 0) {
    pos += 2;
  }

  final out = <int>[];
  var isFinal = false;
  while (!isFinal) {
    if (pos >= compressedBytes.length - 8) {
      throw const ConcertFormatException('Truncated gzip payload.');
    }
    final header = compressedBytes[pos++];
    isFinal = (header & 0x01) != 0;
    final btype = (header >> 1) & 0x03;
    if (btype != 0) {
      throw const ConcertFormatException(
        'Bản Web chưa hỗ trợ giải nén Gzip nén sâu — hãy xuất tệp .concert dạng JSON thường để chia sẻ chéo nền tảng.',
      );
    }
    if (pos + 4 > compressedBytes.length - 8) {
      throw const ConcertFormatException('Truncated stored DEFLATE block.');
    }
    final len = compressedBytes[pos] | (compressedBytes[pos + 1] << 8);
    pos += 4;
    if (out.length + len > maxBytes) {
      throw ConcertFormatException(
        'Decompressed payload exceeds safety limit of $maxBytes bytes.',
      );
    }
    if (pos + len > compressedBytes.length - 8) {
      throw const ConcertFormatException('Truncated stored DEFLATE data.');
    }
    out.addAll(compressedBytes.sublist(pos, pos + len));
    pos += len;
  }

  return out;
}

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b & 0xFF;
    for (var i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = (crc >>> 1) ^ 0xEDB88320;
      } else {
        crc = crc >>> 1;
      }
    }
  }
  return (~crc) & 0xFFFFFFFF;
}

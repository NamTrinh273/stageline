import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stageline/core/models/models.dart';
import 'package:stageline/core/parser/parser.dart';

void main() {
  const concertCodec = ConcertCodec();
  const qrCodec = QrSongCodec();

  final sampleSong = Song(
    id: 'song-1',
    title: 'Đêm Nay Mình Hát',
    artist: 'Demo Artist',
    sections: [
      LyricSection(
        tag: 'Verse 1',
        lines: const [
          LyricLine(
            text: 'City lights are shining bright tonight',
            translation: 'Ánh đèn thành phố sáng rực đêm nay',
          ),
          LyricLine(text: 'Bước chân hòa nhịp cùng hàng ngàn người'),
        ],
      ),
      LyricSection(
        tag: 'Chorus',
        singAlong: true,
        lines: const [
          LyricLine(text: 'Oh oh oh, hát vang lên nào!'),
          LyricLine(text: 'Never let this moment fade away'),
        ],
      ),
    ],
  );

  final sampleSetlist = Setlist(
    id: 'tour-2026',
    title: 'StageLine Live 2026',
    artist: 'Demo Artist',
    updatedAt: DateTime.utc(2026, 11, 25, 19, 0),
    songs: [sampleSong],
  );

  group('ConcertCodec', () {
    test(
      'encodes and decodes plain UTF-8 JSON and gzip-compressed .concert bytes',
      () {
        final plainBytes = concertCodec.encodeSetlistBytes(
          sampleSetlist,
          compressed: false,
        );
        final gzipBytes = concertCodec.encodeSetlistBytes(
          sampleSetlist,
          compressed: true,
        );

        expect(gzipBytes.length, lessThan(plainBytes.length));
        expect(concertCodec.decodeSetlistBytes(plainBytes), sampleSetlist);
        expect(concertCodec.decodeSetlistBytes(gzipBytes), sampleSetlist);
      },
    );

    test(
      'handles UTF-8 BOM and rejects malformed JSON or wrong schema version',
      () {
        final withBom = '\uFEFF${concertCodec.encodeSetlist(sampleSetlist)}';
        expect(concertCodec.decodeSetlistString(withBom), sampleSetlist);

        expect(
          () => concertCodec.decodeSetlistString('not valid json'),
          throwsA(isA<ConcertFormatException>()),
        );
        expect(
          () => concertCodec.decodeSetlistString(
            '{"v": 99, "setlist": "X", "songs": []}',
          ),
          throwsA(isA<ConcertFormatException>()),
        );
      },
    );
  });

  group('QrSongCodec', () {
    test(
      'encodes a typical bilingual song well under 2200 chars and round-trips',
      () {
        final payload = qrCodec.encode(sampleSong);

        expect(payload.startsWith(QrSongCodec.prefix), isTrue);
        expect(payload.length, lessThan(QrSongCodec.maxEncodedChars));
        expect(qrCodec.estimateEncodedLength(sampleSong), payload.length);

        final decoded = qrCodec.decode(payload);
        expect(decoded, sampleSong);
      },
    );

    test('throws QrPayloadTooLargeException when compressed song exceeds 2200 chars', () {
      // High-entropy unique lines that will exceed 2200 chars even after gzip.
      final bigLines = List<LyricLine>.generate(
        180,
        (i) => LyricLine(
          text:
              'Line #$i unique-verse-${i * 7919}-${(i * 104729).toRadixString(36)} '
              'extra-random-lyrics-fragment-${(i * 65537).toRadixString(16)}',
          translation:
              'Dịch câu $i khác biệt hoàn toàn ${(i * 31337).toRadixString(36)}',
        ),
      );
      final hugeSong = Song(
        id: 'huge',
        title: 'Medley 30 Minutes',
        sections: [LyricSection(tag: 'Verse 1', lines: bigLines)],
      );

      expect(
        () => qrCodec.encode(hugeSong),
        throwsA(
          isA<QrPayloadTooLargeException>().having(
            (e) => e.maxLength,
            'maxLength',
            QrSongCodec.maxEncodedChars,
          ),
        ),
      );
    });

    test('rejects unrelated QR strings, bad base64, and corrupted gzip', () {
      expect(
        () => qrCodec.decode('https://example.com/ticket'),
        throwsA(isA<ConcertFormatException>()),
      );
      expect(
        () => qrCodec.decode('SL1:%%%NOT-BASE64%%%'),
        throwsA(isA<ConcertFormatException>()),
      );
      expect(
        () => qrCodec.decode('SL1:${base64Url.encode([1, 2, 3, 4])}'),
        throwsA(isA<ConcertFormatException>()),
      );
    });

    test('blocks gzip zip-bomb exceeding 64 KB decompressed safety cap', () {
      final bombRaw = List<int>.filled(70 * 1024, 0x41); // 70 KB of 'A'
      final compressedBomb = gzip.encode(bombRaw);
      final maliciousQr = 'SL1:${base64Url.encode(compressedBomb)}';

      // Compressed payload itself is tiny (<200 chars), so guard MUST catch on decode.
      expect(maliciousQr.length, lessThan(300));
      expect(
        () => qrCodec.decode(maliciousQr),
        throwsA(isA<ConcertFormatException>()),
      );
    });
  });
}

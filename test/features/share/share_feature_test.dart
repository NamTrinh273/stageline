import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:stageline/core/models/models.dart';
import 'package:stageline/core/parser/parser.dart';
import 'package:stageline/core/theme/stageline_theme.dart';
import 'package:stageline/features/share/share.dart';

Song _buildCompactSong() {
  return Song(
    id: 'song-qr-demo',
    title: 'Đêm Nay Bay Lên',
    artist: 'StageLine Demo',
    sections: [
      LyricSection(
        tag: 'Chorus',
        singAlong: true,
        lines: const [
          LyricLine(text: 'Giơ cao ánh đèn giữa bầu trời đêm'),
          LyricLine(
            text: 'Raise your lights into the midnight sky',
            translation: 'Giơ cao ánh sáng lên bầu trời đêm',
          ),
        ],
      ),
    ],
  );
}

Song _buildOversizedSong() {
  // High-entropy pseudo-random text so gzip cannot compress it under 2,200 chars.
  final rng = Random(42);
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
  final lines = List<LyricLine>.generate(95, (index) {
    final chars = List<String>.generate(
      42,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
    return LyricLine(text: 'L$index $chars');
  });

  return Song(
    id: 'song-too-big',
    title: 'Epic 15-Minute Medley',
    sections: [LyricSection(tag: 'Verse 1', lines: lines)],
  );
}

void main() {
  group('SongQrSheet', () {
    testWidgets('renders QR code and byte budget for compact song', (
      tester,
    ) async {
      final song = _buildCompactSong();
      await tester.pumpWidget(
        MaterialApp(
          theme: StageLineTheme.buildDarkTheme(),
          home: Scaffold(body: SongQrSheet(song: song)),
        ),
      );

      expect(find.byKey(const ValueKey('song_qr_image')), findsOneWidget);
      expect(find.byKey(const ValueKey('song_qr_too_large')), findsNothing);
      expect(find.textContaining('/ 2200 ký tự'), findsOneWidget);
      expect(find.text('Đêm Nay Bay Lên'), findsOneWidget);
    });

    testWidgets(
      'shows warning and invokes fallback callback when song exceeds QR cap',
      (tester) async {
        var fallbackTapped = false;
        final hugeSong = _buildOversizedSong();

        await tester.pumpWidget(
          MaterialApp(
            theme: StageLineTheme.buildDarkTheme(),
            home: Scaffold(
              body: SongQrSheet(
                song: hugeSong,
                onExportSetlistFallback: () {
                  fallbackTapped = true;
                },
              ),
            ),
          ),
        );

        expect(find.byKey(const ValueKey('song_qr_image')), findsNothing);
        expect(find.byKey(const ValueKey('song_qr_too_large')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('song_qr_fallback_btn')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('song_qr_fallback_btn')));
        await tester.pump();
        expect(fallbackTapped, isTrue);
      },
    );
  });

  group('StageLineShareService.parseImportedBytes', () {
    const service = StageLineShareService();
    const concertCodec = ConcertCodec();

    test('parses plain and gzipped .concert files into ImportedSetlist', () {
      final original = Setlist(
        id: 'concert-2026',
        title: 'Tour 2026',
        artist: 'My Artist',
        songs: [_buildCompactSong()],
      );

      final plainBytes = concertCodec.encodeSetlistBytes(
        original,
        compressed: false,
      );
      final plainResult = service.parseImportedBytes(
        fileName: 'tour-2026.concert',
        bytes: plainBytes,
      );
      expect(plainResult, isA<ImportedSetlist>());
      expect((plainResult as ImportedSetlist).setlist.title, 'Tour 2026');

      final gzipBytes = concertCodec.encodeSetlistBytes(
        original,
        compressed: true,
      );
      final gzipResult = service.parseImportedBytes(
        fileName: '/storage/emulated/0/Download/tour-2026.concert',
        bytes: gzipBytes,
      );
      expect(gzipResult, isA<ImportedSetlist>());
      expect((gzipResult as ImportedSetlist).setlist.songs.length, 1);
    });

    test(
      'parses .lrc and .txt files into ImportedSong with fallback title',
      () {
        const lrc = '''
[ti:Chạy Ngay Đi]
[ar:Sơn Tùng M-TP]
[00:12.00][Chorus]
[00:13.00]Chạy ngay đi trước khi mọi điều dần tồi tệ hơn
''';
        final lrcResult = service.parseImportedBytes(
          fileName: 'chay-ngay-di.lrc',
          bytes: utf8.encode(lrc),
        );
        expect(lrcResult, isA<ImportedSong>());
        final lrcSong = (lrcResult as ImportedSong).song;
        expect(lrcSong.title, 'Chạy Ngay Đi');
        expect(lrcSong.sections.first.singAlong, isTrue);

        const txt = '''
[Sing-along]
We will rock you
| Chúng ta sẽ khuấy đảo sân khấu
''';
        final txtResult = service.parseImportedBytes(
          fileName: 'Encore Anthem.txt',
          bytes: utf8.encode(txt),
        );
        expect(txtResult, isA<ImportedSong>());
        final txtSong = (txtResult as ImportedSong).song;
        expect(txtSong.title, 'Encore Anthem');
        expect(txtSong.sections.first.lines.first.translation, isNotNull);
      },
    );

    test('throws FormatException on unsupported extension or empty bytes', () {
      expect(
        () => service.parseImportedBytes(fileName: 'notes.pdf', bytes: [1, 2]),
        throwsFormatException,
      );
      expect(
        () => service.parseImportedBytes(fileName: 'empty.concert', bytes: []),
        throwsFormatException,
      );
      expect(
        () => service.parseImportedBytes(
          fileName: 'broken.concert',
          bytes: utf8.encode('{not valid json'),
        ),
        throwsFormatException,
      );
    });
  });

  group('showAssignSongToSetlistDialog', () {
    testWidgets(
      'assigns scanned song to existing setlist and deduplicates ID',
      (tester) async {
        final song = _buildCompactSong();
        final existing = Setlist(
          id: 'existing-1',
          title: 'Đêm Diễn Hà Nội',
          songs: [song],
        );
        Setlist? chosen;

        await tester.pumpWidget(
          MaterialApp(
            theme: StageLineTheme.buildDarkTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    chosen = await showAssignSongToSetlistDialog(
                      context,
                      existingSetlists: [existing],
                      song: song,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Tạo setlist mới'), findsOneWidget);
        expect(find.text('Đêm Diễn Hà Nội'), findsOneWidget);

        await tester.tap(find.text('Đêm Diễn Hà Nội'));
        await tester.pumpAndSettle();

        expect(chosen, isNotNull);
        expect(chosen!.id, 'existing-1');
        expect(chosen!.songs.length, 2);
        expect(chosen!.songs[0].id, isNot(chosen!.songs[1].id));
      },
    );
  });
}

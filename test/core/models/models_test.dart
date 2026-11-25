import 'package:flutter_test/flutter_test.dart';
import 'package:stageline/core/models/models.dart';

void main() {
  group('LyricLine', () {
    test('omits "tr" key when translation is null or whitespace', () {
      const noTr = LyricLine(text: 'Hello concert');
      const blankTr = LyricLine(text: 'Hello concert', translation: '   ');
      const withTr = LyricLine(text: 'Hello concert', translation: 'Xin chào');

      expect(noTr.toJson(), {'t': 'Hello concert'});
      expect(noTr.toJson().containsKey('tr'), isFalse);
      expect(blankTr.toJson().containsKey('tr'), isFalse);
      expect(withTr.toJson(), {'t': 'Hello concert', 'tr': 'Xin chào'});
    });
  });

  group('LyricSection', () {
    test('shortLabel produces compact labels for Quick Section Jump', () {
      expect(LyricSection(tag: 'Verse 1', lines: const []).shortLabel, 'V1');
      expect(LyricSection(tag: 'Verse 2', lines: const []).shortLabel, 'V2');
      expect(
        LyricSection(tag: 'Pre-Chorus', lines: const []).shortLabel,
        'Pre',
      );
      expect(LyricSection(tag: 'Chorus', lines: const []).shortLabel, 'CHORUS');
      expect(
        LyricSection(tag: 'Điệp khúc', lines: const []).shortLabel,
        'CHORUS',
      );
      expect(
        LyricSection(tag: 'Sing-along', lines: const []).shortLabel,
        'SING',
      );
      expect(LyricSection(tag: 'Bridge', lines: const []).shortLabel, 'Bridge');
      expect(LyricSection(tag: 'Outro', lines: const []).shortLabel, 'Outro');
    });
  });

  group('Song', () {
    test('flattenLines and firstLineIndexForSection stay aligned', () {
      final song = Song(
        id: 's1',
        title: 'Stage Night',
        sections: [
          LyricSection(
            tag: 'Verse 1',
            lines: const [
              LyricLine(text: 'Line 0'),
              LyricLine(text: 'Line 1'),
            ],
          ),
          LyricSection(
            tag: 'Chorus',
            singAlong: true,
            lines: const [
              LyricLine(text: 'Line 2', translation: 'Dòng 2'),
              LyricLine(text: 'Line 3'),
            ],
          ),
        ],
      );

      final flat = song.flattenLines();
      expect(song.totalLines, 4);
      expect(song.hasTranslations, isTrue);
      expect(flat.length, 4);
      expect(song.firstLineIndexForSection(0), 0);
      expect(song.firstLineIndexForSection(1), 2);
      expect(flat[2].isSectionStart, isTrue);
      expect(flat[2].section.singAlong, isTrue);
      expect(flat[3].isSectionStart, isFalse);
    });
  });

  group('Setlist', () {
    test(
      'round-trips canonical v1 JSON and rejects unsupported schema version',
      () {
        final original = Setlist(
          id: 'saigon-2026',
          title: 'Saigon Live 2026',
          artist: 'Various Artists',
          updatedAt: DateTime.utc(2026, 11, 25, 18, 0),
          songs: [
            Song(
              id: 's1',
              title: 'Opening Track',
              sections: [
                LyricSection(
                  tag: 'Chorus',
                  singAlong: true,
                  lines: const [LyricLine(text: 'Sing loud tonight')],
                ),
              ],
            ),
          ],
        );

        final restored = Setlist.fromJson(original.toJson());
        expect(restored, original);

        final badVersion = original.toJson()..['v'] = 2;
        expect(() => Setlist.fromJson(badVersion), throwsFormatException);
      },
    );
  });
}

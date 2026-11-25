import 'package:flutter_test/flutter_test.dart';
import 'package:stageline/core/parser/parser.dart';

void main() {
  const parser = LyricsParser();

  group('LyricsParser.parseRawText', () {
    test('parses .lrc metadata, stacked timestamps, sections, and Vietnamese Unicode', () {
      const rawLrc =
          '\uFEFF'
          '[ti:Đêm Sân Khấu]\r\n'
          '[ar:Ca Sĩ Việt]\r\n'
          '[al:Tour 2026]\r\n'
          '[00:05.00][Verse 1]\r\n'
          '[00:10.50]Ánh đèn sân khấu rực sáng đêm nay\r\n'
          '[00:15.20][01:12.00]Cùng nhau giơ tay lên trời cao\r\n'
          '[00:20.00]\r\n'
          '[00:25.00][Pre-Chorus]\r\n'
          '[00:26.00]Nhịp tim hòa chung theo tiếng trống\r\n'
          '[00:35.00][Chorus]\r\n'
          '[00:36.00]Hát vang lên nào bạn ơi!\r\n'
          '[00:40.00][Sing-along]\r\n'
          '[00:41.00]Oh oh oh, đêm nay không ngủ\r\n';

      final song = parser.parseRawText(rawLrc, fallbackTitle: 'Fallback');

      expect(song.title, 'Đêm Sân Khấu');
      expect(song.artist, 'Ca Sĩ Việt');
      expect(song.sections.length, 4);

      expect(song.sections[0].tag, 'Verse 1');
      expect(song.sections[0].singAlong, isFalse);
      expect(song.sections[0].lines.map((l) => l.text).toList(), [
        'Ánh đèn sân khấu rực sáng đêm nay',
        'Cùng nhau giơ tay lên trời cao',
      ]);

      // Pre-Chorus must NOT falsely match Chorus sing-along highlight.
      expect(song.sections[1].tag, 'Pre-Chorus');
      expect(song.sections[1].singAlong, isFalse);

      expect(song.sections[2].tag, 'Chorus');
      expect(song.sections[2].singAlong, isTrue);

      expect(song.sections[3].tag, 'Sing-along');
      expect(song.sections[3].singAlong, isTrue);
    });

    test('attaches > and | translation lines to the previous lyric line', () {
      const rawTxt = '''
> Orphan leading translation should be ignored safely
[Verse 1]
Lights go down across the crowd
> Ánh đèn tắt dần khắp khán đài
Hold your phone up to the sky
| Giơ cao chiếc điện thoại lên bầu trời

[Chorus]
We are singing out loud tonight
> Đêm nay chúng ta cùng hát vang
''';

      final song = parser.parseRawText(rawTxt, fallbackTitle: 'Concert Anthem');

      expect(song.title, 'Concert Anthem');
      expect(song.hasTranslations, isTrue);
      expect(song.sections.length, 2);
      expect(song.sections[0].lines[0].text, 'Lights go down across the crowd');
      expect(
        song.sections[0].lines[0].translation,
        'Ánh đèn tắt dần khắp khán đài',
      );
      expect(
        song.sections[0].lines[1].translation,
        'Giơ cao chiếc điện thoại lên bầu trời',
      );
      expect(song.sections[1].singAlong, isTrue);
      expect(
        song.sections[1].lines[0].translation,
        'Đêm nay chúng ta cùng hát vang',
      );
    });

    test(
      'splits untagged paragraphs into Verse 1, Verse 2 when no headers exist',
      () {
        const raw = '''
First stanza line one
First stanza line two

Second stanza line one
''';

        final song = parser.parseRawText(raw, fallbackTitle: 'Plain Lyrics');
        expect(song.sections.length, 2);
        expect(song.sections[0].tag, 'Verse 1');
        expect(song.sections[0].lines.length, 2);
        expect(song.sections[1].tag, 'Verse 2');
        expect(song.sections[1].lines.length, 1);
      },
    );

    test('round-trips cleanly through toEditableText', () {
      const input = '''
[Verse 1]
Line A
> Dịch A

[Chorus]
Crowd sing line
''';
      final first = parser.parseRawText(
        input,
        fallbackTitle: 'Roundtrip',
        id: 's1',
      );
      final editable = parser.toEditableText(first);
      final second = parser.parseRawText(
        editable,
        fallbackTitle: 'Roundtrip',
        id: 's1',
      );

      expect(second, first);
    });
  });
}

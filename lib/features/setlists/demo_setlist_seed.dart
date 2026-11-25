import '../../core/models/models.dart';

/// Builds a lightweight built-in V-Pop + US-UK demo setlist for instant offline testing.
Setlist buildDemoSetlist() {
  return Setlist(
    id: 'demo-stageline-2026',
    title: 'Đêm Nhạc StageLine (Demo)',
    artist: 'V-Pop & US-UK Mix',
    updatedAt: DateTime.now().toUtc(),
    songs: [
      Song(
        id: 'demo-vpop-1',
        title: 'Đêm Ánh Sáng (Demo V-Pop)',
        artist: 'Demo Artist',
        sections: [
          LyricSection(
            tag: 'Verse 1',
            lines: const [
              LyricLine(
                text: 'Đèn sân khấu vụt tắt chỉ còn biển sao lung linh',
              ),
              LyricLine(
                text: 'Hàng ngàn giọng ca chờ khoảnh khắc mình chung nhịp',
              ),
              LyricLine(text: 'Tiếng bass dội lên làm rung chuyển cả khán đài'),
            ],
          ),
          LyricSection(
            tag: 'Pre-Chorus',
            lines: const [
              LyricLine(text: 'Đếm ba hai một rồi cùng nhau hòa vang'),
              LyricLine(text: 'Đừng ngại ngần gì hãy bật sáng trái tim'),
            ],
          ),
          LyricSection(
            tag: 'Chorus',
            singAlong: true,
            lines: const [
              LyricLine(text: 'Hát vang lên nào cho đêm nay không phai!'),
              LyricLine(text: 'Giơ cao đôi tay ta cháy hết tuổi trẻ này'),
              LyricLine(text: 'Oh oh oh, cả sân vận động cùng hòa ca'),
            ],
          ),
          LyricSection(
            tag: 'Bridge',
            lines: const [
              LyricLine(text: 'Khi ánh đèn dịu xuống chỉ còn tiếng hát của ta'),
              LyricLine(text: 'Khoảnh khắc này sẽ mãi ở lại trong tim'),
            ],
          ),
          LyricSection(
            tag: 'Sing-along',
            singAlong: true,
            lines: const [
              LyricLine(text: 'La la la la, hát lớn hơn nữa nào!'),
              LyricLine(text: 'Cảm ơn vì đã ở đây đêm nay!'),
            ],
          ),
        ],
      ),
      Song(
        id: 'demo-usuk-2',
        title: 'City Under Stars (Demo US-UK)',
        artist: 'Demo Band',
        sections: [
          LyricSection(
            tag: 'Verse 1',
            lines: const [
              LyricLine(
                text: 'We drove all night just to stand right here',
                translation: 'Ta lái xe suốt đêm chỉ để đứng nơi đây',
              ),
              LyricLine(
                text: 'Loud guitars ringing crystal clear',
                translation: 'Tiếng guitar vang dội thật trong trẻo',
              ),
            ],
          ),
          LyricSection(
            tag: 'Chorus',
            singAlong: true,
            lines: const [
              LyricLine(
                text: 'Whoa-oh, sing it back to the stage tonight',
                translation: 'Whoa-oh, hãy hát vọng lại lên sân khấu đêm nay',
              ),
              LyricLine(
                text: 'Every voice shining in the stadium light',
                translation: 'Mọi giọng ca tỏa sáng dưới ánh đèn sân vận động',
              ),
            ],
          ),
          LyricSection(
            tag: 'Outro',
            lines: const [
              LyricLine(
                text: 'Hold on to this melody until sunrise',
                translation: 'Giữ lấy giai điệu này cho đến bình minh',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

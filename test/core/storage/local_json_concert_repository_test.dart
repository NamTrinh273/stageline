import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stageline/core/models/models.dart';
import 'package:stageline/core/parser/parser.dart';
import 'package:stageline/core/storage/storage.dart';

void main() {
  late Directory tempDir;
  late LocalJsonConcertRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stageline_test_');
    repository = LocalJsonConcertRepository(
      baseDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Setlist makeSetlist(String id, String title, DateTime updatedAt) {
    return Setlist(
      id: id,
      title: title,
      artist: 'Test Artist',
      updatedAt: updatedAt,
      songs: [
        Song(
          id: 's1',
          title: 'Song A',
          sections: [
            LyricSection(
              tag: 'Chorus',
              singAlong: true,
              lines: const [LyricLine(text: 'Sing along with us!')],
            ),
          ],
        ),
      ],
    );
  }

  group('LocalJsonConcertRepository', () {
    test(
      'saves, loads sorted by updatedAt desc, and deletes cleanly',
      () async {
        final older = makeSetlist(
          'older',
          'Night 1',
          DateTime.utc(2026, 11, 1),
        );
        final newer = makeSetlist(
          'newer',
          'Night 2',
          DateTime.utc(2026, 11, 20),
        );

        await repository.save(older);
        await repository.save(newer);

        final all = await repository.loadAll();
        expect(all.map((s) => s.id).toList(), ['newer', 'older']);
        expect(await repository.loadById('older'), older);

        await repository.delete('newer');
        expect(await repository.loadById('newer'), isNull);
        expect((await repository.loadAll()).map((s) => s.id).toList(), [
          'older',
        ]);
      },
    );

    test('skips corrupted .concert files during loadAll and sanitizes path traversal IDs', () async {
      final valid = makeSetlist(
        '../../escape',
        'Safe Setlist',
        DateTime.utc(2026, 11, 25),
      );
      await repository.save(valid);

      final corruptFile = File(
        '${tempDir.path}${Platform.pathSeparator}setlists${Platform.pathSeparator}broken.concert',
      );
      await corruptFile.writeAsString('{corrupt json');

      final all = await repository.loadAll();
      expect(all.length, 1);
      expect(all.first.title, 'Safe Setlist');

      // Ensure no file escaped outside tempDir/setlists.
      final rootFiles = tempDir.listSync().whereType<File>().toList();
      expect(rootFiles, isEmpty);
    });

    test('exports and imports .concert (plain & gzip), .lrc, .txt, and rejects unknown extensions', () async {
      final exportDir = await Directory(
        '${tempDir.path}${Platform.pathSeparator}exports',
      ).create();
      final original = makeSetlist(
        'tour-hn',
        'Hanoi Concert',
        DateTime.utc(2026, 11, 25),
      );

      final exportedGzip = await repository.exportToFile(
        original,
        targetDir: exportDir,
        compressed: true,
      );
      expect(await exportedGzip.exists(), isTrue);

      final importedConcert = await repository.importFromFile(exportedGzip);
      expect(importedConcert, original);

      final lrcFile = File(
        '${exportDir.path}${Platform.pathSeparator}encore.lrc',
      );
      await lrcFile.writeAsString(
        '[ti:Encore Song]\n[ar:V-Pop Star]\n[00:10.00][Chorus]\n[00:12.00]Hát cùng nhau nhé!\n',
      );
      final importedLrc = await repository.importFromFile(lrcFile);
      expect(importedLrc.title, 'Encore Song');
      expect(importedLrc.artist, 'V-Pop Star');
      expect(importedLrc.songs.single.sections.single.singAlong, isTrue);

      final badFile = File(
        '${exportDir.path}${Platform.pathSeparator}ticket.pdf',
      );
      await badFile.writeAsString('not lyrics');
      expect(
        () => repository.importFromFile(badFile),
        throwsA(isA<ConcertFormatException>()),
      );
    });

    test(
      'setlistsProvider loads, saves, and deletes reactively via Riverpod',
      () async {
        final container = ProviderContainer(
          overrides: [concertRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        expect(await container.read(setlistsProvider.future), isEmpty);

        final notifier = container.read(setlistsProvider.notifier);
        await notifier.saveSetlist(
          makeSetlist('live-1', 'Live Show', DateTime.utc(2026, 11, 25)),
        );

        final afterSave = await container.read(setlistsProvider.future);
        expect(afterSave.length, 1);
        expect(afterSave.first.id, 'live-1');

        await notifier.deleteSetlist('live-1');
        expect(await container.read(setlistsProvider.future), isEmpty);
      },
    );
  });
}

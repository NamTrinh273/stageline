import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stageline/app.dart';
import 'package:stageline/core/models/models.dart';
import 'package:stageline/core/storage/storage.dart';

class InMemoryConcertRepository implements ConcertRepository {
  final Map<String, Setlist> _store = <String, Setlist>{};

  @override
  Future<List<Setlist>> loadAll() async {
    final list = _store.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<Setlist?> loadById(String id) async => _store[id];

  @override
  Future<void> save(Setlist setlist) async {
    _store[setlist.id] = setlist;
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
  }

  @override
  Future<File> exportToFile(
    Setlist setlist, {
    required Directory targetDir,
    bool compressed = false,
  }) => throw UnimplementedError();

  @override
  Future<Setlist> importFromFile(File file) => throw UnimplementedError();
}

void main() {
  testWidgets(
    'Home loads demo setlist, opens detail, and adds a song via Quick Editor',
    (tester) async {
      final repo = InMemoryConcertRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [concertRepositoryProvider.overrideWithValue(repo)],
          child: const StageLineApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state shown initially.
      expect(find.byKey(const ValueKey('empty_load_demo_btn')), findsOneWidget);

      // Load demo setlist.
      await tester.tap(find.byKey(const ValueKey('empty_load_demo_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Đêm Nhạc StageLine (Demo)'), findsOneWidget);

      // Open setlist detail.
      await tester.tap(find.text('Đêm Nhạc StageLine (Demo)'));
      await tester.pumpAndSettle();

      expect(find.text('Đêm Ánh Sáng (Demo V-Pop)'), findsOneWidget);
      expect(find.text('City Under Stars (Demo US-UK)'), findsOneWidget);

      // Add a new song using QuickLyricsEditorScreen.
      await tester.tap(find.byKey(const ValueKey('detail_add_song_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('editor_title_field')),
        'Encore Finale',
      );
      await tester.enterText(
        find.byKey(const ValueKey('editor_lyrics_field')),
        '[Chorus]\nHát vang đêm nay\n> Sing out loud tonight',
      );
      await tester.pump();

      expect(find.textContaining('1 đoạn • 1 dòng'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('editor_save_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Encore Finale'), findsOneWidget);
    },
  );
}

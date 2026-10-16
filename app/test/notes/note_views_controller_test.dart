import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_view.dart';
import 'package:truce_editor/notes/note_view_store.dart';
import 'package:truce_editor/notes/note_views_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  test('views remembered at the same time are all kept', () async {
    final storage = AppStorage(tempFolder().path);
    final container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final views = container.read(noteViewsProvider.notifier);
    final a = (folderId: 'f1', path: path('a.md'));
    final b = (folderId: 'f1', path: path('b.md'));

    await Future.wait([
      views.remember(a, NoteView.text),
      views.remember(b, NoteView.rendered),
    ]);

    final expected = {
      NoteViewStore.storeKey(a): NoteView.text,
      NoteViewStore.storeKey(b): NoteView.rendered,
    };
    expect(container.read(noteViewsProvider).value, expected);
    expect(await container.read(noteViewStoreProvider).load(), expected);
  });
}

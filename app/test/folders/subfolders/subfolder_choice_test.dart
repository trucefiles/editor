import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/subfolders/subfolder_choice.dart';

import '../../support.dart';

void main() {
  SubfolderChoice choice({
    List<Selection> taken = const [],
    Selection? initial,
  }) => SubfolderChoice(
    names: const _Names({
      null: ['.git', 'home', 'notes'],
      'notes': ['private', 'tool', 'work'],
    }),
    isToolFolder: (segments) => segments.last == 'tool',
    taken: taken,
    initial: initial,
  );

  test('offers the folders the user can pick, without hidden ones '
      "or the sync tool's own", () async {
    final names = choice();

    expect((await names.foldersIn(null)).value, [path('home'), path('notes')]);
    expect((await names.foldersIn(path('notes'))).value, [
      path('notes/private'),
      path('notes/work'),
    ]);
  });

  test('passes on a folder that cannot be read', () async {
    expect((await choice().foldersIn(path('gone'))).error, StoreError.notFound);
  });

  test('is nothing until a subfolder is picked or the whole chosen', () {
    final parts = choice();
    expect(parts.selection, isNull);

    parts.toggle(path('notes/work'));
    expect(parts.selection, Selection.of([path('notes/work')]));

    parts.toggle(path('notes/work'));
    expect(parts.selection, isNull);

    parts.chooseWhole(whole: true);
    expect(parts.selection, const WholeFolder());
  });

  test('keeps the picked subfolders while the whole is chosen', () {
    final parts = choice()
      ..toggle(path('home'))
      ..chooseWhole(whole: true)
      ..chooseWhole(whole: false);

    expect(parts.selection, Selection.of([path('home')]));
  });

  test('starts at the folder\'s choice', () {
    final parts = choice(initial: Selection.of([path('home')]));

    expect(parts.whole, isFalse);
    expect(parts.picked, {path('home')});
  });

  test('a subfolder below a picked one is shown with it', () {
    final parts = choice()..toggle(path('notes'));

    expect(parts.isInPicked(path('notes/work')), isTrue);
    expect(parts.isInPicked(path('home')), isFalse);
  });

  test('what another folder shows cannot be picked, nor what holds it', () {
    final parts = choice(
      taken: [
        Selection.of([path('notes/work')]),
      ],
    );

    expect(parts.wholeTaken, isTrue);
    expect(parts.isTaken(path('notes/work')), isTrue);
    expect(parts.isTaken(path('notes')), isTrue);
    expect(parts.isTaken(path('notes/private')), isFalse);
  });
}

/// Folder names by the path of their parent (`null` for the top).
final class _Names implements SubfolderNames {
  const _Names(this.byParent);

  final Map<String?, List<String>> byParent;

  @override
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder) async =>
      switch (byParent[folder?.value]) {
        final names? => Ok(names),
        null => const Err(StoreError.notFound),
      };
}

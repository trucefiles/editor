import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing_ui/src/syncthing_tree_choice.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// Folder names from a fixed tree, by parent path ('' for the top).
final class _Names implements SubfolderNames {
  const _Names(this._tree);

  final Map<String, List<String>> _tree;

  @override
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder) async =>
      Ok(_tree[folder?.value ?? ''] ?? const []);
}

void main() {
  const names = _Names({
    '': ['notes', 'work'],
    'work': ['a', 'b'],
  });

  SyncthingTreeChoice choice({
    Set<RelPath?> taken = const {},
    RelPath? initial,
  }) => SyncthingTreeChoice(names: names, taken: taken, initial: initial);

  test('ticks the folder picked to start with', () {
    expect(choice(initial: path('work')).picked, [path('work')]);
    expect(choice().picked, [null]);
  });

  test('a start pick inside a folder added before stays unpicked', () {
    final pick = choice(taken: {path('work')}, initial: path('work/a'));

    expect(pick.picked, isEmpty);
    expect(pick.isTicked(path('work')), isTrue);
    expect(pick.isLocked(path('work/a')), isTrue);
  });

  test('locks folders at, inside or around one added before', () {
    final pick = choice(taken: {path('work')}, initial: path('notes'));

    expect(pick.isLocked(path('work')), isTrue);
    expect(pick.isLocked(path('work/a')), isTrue);
    expect(pick.isLocked(null), isTrue);
    expect(pick.isLocked(path('notes')), isFalse);
  });

  test('picks and unpicks, sorted, the Syncthing folder first', () {
    final pick = choice(initial: path('work'))..toggle(path('notes'));

    expect(pick.picked, [path('notes'), path('work')]);
    pick.toggle(path('work'));
    expect(pick.picked, [path('notes')]);
  });

  test('a folder inside a picked one swaps in for it', () {
    final pick = choice()..toggle(path('work/a'));

    expect(pick.picked, [path('work/a')]);
    expect(pick.isLocked(path('work/b')), isFalse);
  });

  test('a folder around picked ones swaps in for all of them', () {
    final pick = choice(initial: path('work/a'))
      ..toggle(path('work/b'))
      ..toggle(path('notes'))
      ..toggle(path('work'));

    expect(pick.picked, [path('notes'), path('work')]);
  });

  test('a Syncthing folder added as a whole locks every folder in it', () {
    final pick = choice(taken: {null}, initial: path('notes'));

    expect(pick.picked, isEmpty);
    expect(pick.isLocked(path('notes')), isTrue);
  });

  test('opens the folders that hold a ticked one', () {
    final pick = choice(taken: {path('work/a')}, initial: path('notes'));

    expect(pick.holdsTicked(path('work')), isTrue);
    expect(pick.holdsTicked(path('notes')), isFalse);
  });

  test('lists the folders of a level as paths', () async {
    expect((await choice().foldersIn(path('work'))).value, [
      path('work/a'),
      path('work/b'),
    ]);
  });
}

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

Folder _folder(String id) =>
    Folder(id: folderId(id), name: id, color: 'teal', location: id);

void main() {
  final work = _folder('work');
  final home = _folder('home');
  final saved = ListedFile(
    folder: work,
    path: path('inbox/Plan.md'),
    type: const FakeFileType(),
    version: const FileVersion(1),
    modified: DateTime(2026, 11, 2),
  );

  PlaceChange change({
    required FilePlace place,
    String name = '',
    bool isNew = false,
    ListedFile? read,
  }) => PlaceChange.of(
    (place: place, name: name, newSubfolder: false),
    isNew: isNew,
    saved: read,
    unnamed: 'Plan',
  );

  test('a new file only changes where it will go', () {
    final placed = change(place: topOf(home), name: ' Milk ', isNew: true);

    expect(placed, isA<NewPlace>());
    expect((placed as NewPlace).place, topOf(home));
    expect(placed.name, 'Milk');
  });

  test('a new file with an empty name keeps being named as before', () {
    final placed = change(place: topOf(home), isNew: true);

    expect((placed as NewPlace).name, isNull);
  });

  test('a file not saved yet can not move', () {
    expect(
      change(place: topOf(home)),
      isA<CantMove>().having((c) => c.failure, 'failure', isA<MoveNotSaved>()),
    );
  });

  test('the same place and name is nothing to do', () {
    final same = (folder: work, subfolder: path('inbox'));

    expect(change(place: same, read: saved), isA<SamePlace>());
    expect(change(place: same, name: 'Plan', read: saved), isA<SamePlace>());
  });

  test('a typed name that gives the name the file has is nothing to do', () {
    final same = (folder: work, subfolder: path('inbox'));

    // A file name can't hold the `?`: renaming would only add a number.
    expect(change(place: same, name: 'Plan?', read: saved), isA<SamePlace>());
  });

  test('a typed name without the number of the name now renames', () {
    final numbered = ListedFile(
      folder: work,
      path: path('Trip 2024.jpg'),
      type: const FakeFileType(),
      version: const FileVersion(1),
      modified: DateTime(2026, 11, 2),
    );

    final renamed = change(place: topOf(work), name: 'Trip', read: numbered);

    expect((renamed as MoveTo).to.title, 'Trip');
  });

  test('another place or name moves, an empty name as unnamed', () {
    final moved = change(place: topOf(home), read: saved);
    final renamed = change(
      place: (folder: work, subfolder: path('inbox')),
      name: 'Steps',
      read: saved,
    );

    expect((moved as MoveTo).to.title, 'Plan');
    expect(moved.to.place, topOf(home));
    expect((renamed as MoveTo).to.title, 'Steps');
  });
}

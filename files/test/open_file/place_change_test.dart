import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

final class _Type implements ShownFileType {
  const _Type();

  @override
  FakeFileType get support => const FakeFileType();

  @override
  String get name => 'Fake';

  @override
  TextFile get newFile => const TextFile.empty();

  @override
  List<NewFileKind> get newKinds => const [];

  @override
  String searchText(FileText read) => read.text;

  @override
  FileCardSummary cardSummary(FileText read) =>
      FileCardSummary(title: read.summary.firstLine, preview: (_) => '');

  @override
  TextMerge? get merge => null;
}

Folder _folder(String id) =>
    Folder(id: folderId(id), name: id, color: 'teal', location: id);

void main() {
  final work = _folder('work');
  final home = _folder('home');
  final saved = FileText(
    ListedFile(
      folder: work,
      path: path('inbox/Plan.md'),
      type: const FakeFileType(),
      version: const FileVersion(1),
      modified: DateTime(2026, 11, 2),
    ),
    const TextFile.empty(),
  );
  final existing = ExistingFile(saved);

  PlaceChange change(
    PageFile file, {
    required FilePlace place,
    String name = '',
    FileText? read,
  }) => PlaceChange.of(
    file,
    saved: read,
    firstLine: 'Plan',
    picked: (place: place, name: name, newSubfolder: false),
  );

  test('a new file only changes where its file will go', () {
    final placed = change(
      NewFile(topOf(work), type: const _Type()),
      place: topOf(home),
      name: ' Milk ',
    );

    expect(placed, isA<NewPlace>());
    final to = (placed as NewPlace).to;
    expect(to.place, topOf(home));
    expect(to.name, 'Milk');
  });

  test('a new file with an empty name is named after its first line', () {
    final placed = change(
      NewFile(topOf(work), type: const _Type()),
      place: topOf(home),
    );

    expect((placed as NewPlace).to.name, isNull);
  });

  test('a file not saved yet can not move', () {
    expect(
      change(existing, place: topOf(home)),
      isA<CantMove>().having((c) => c.failure, 'failure', isA<MoveNotSaved>()),
    );
  });

  test('the same place and name is nothing to do', () {
    final same = (folder: work, subfolder: path('inbox'));

    expect(change(existing, place: same, read: saved), isA<SamePlace>());
    expect(
      change(existing, place: same, name: 'Plan', read: saved),
      isA<SamePlace>(),
    );
  });

  test('another place or name moves, an empty name by the first line', () {
    final moved = change(existing, place: topOf(home), read: saved);
    final renamed = change(
      existing,
      place: (folder: work, subfolder: path('inbox')),
      name: 'Steps',
      read: saved,
    );

    expect((moved as MoveTo).to.title, 'Plan');
    expect(moved.to.place, topOf(home));
    expect((renamed as MoveTo).to.title, 'Steps');
  });

  test('the name field: a new file named after its text starts empty, '
      'the name its text gives as the hint', () {
    final named = NewFile(topOf(work), type: const _Type(), name: 'Plan');

    expect(
      nameFieldOf(
        NewFile(topOf(work), type: const _Type()),
        path('x.md'),
        'Milk',
      ),
      (name: '', hint: 'Milk'),
    );
    expect(nameFieldOf(named, path('Plan.md'), 'Milk'), (
      name: 'Plan',
      hint: 'Milk',
    ));
    expect(nameFieldOf(existing, saved.path, 'Other'), (
      name: 'Plan',
      hint: 'Other',
    ));
    expect(nameFieldOf(existing, saved.path, ''), (
      name: 'Plan',
      hint: 'Untitled',
    ));
  });
}

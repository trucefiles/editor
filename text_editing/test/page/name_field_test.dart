import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

final class _Type extends TextFileType {
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
  TextSummary<Object?> summary(String text, {required int maxLines}) =>
      throw UnimplementedError();

  @override
  String textSearchWords(FileText read) => read.text;

  @override
  FileCardSummary textCard(FileText read) => throw UnimplementedError();

  @override
  TextMerge? get textMerge => null;
}

Folder _folder(String id) =>
    Folder(id: folderId(id), name: id, color: 'teal', location: id);

void main() {
  final work = _folder('work');
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

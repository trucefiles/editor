import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_markdown/truce_markdown.dart';
import 'package:truce_test_support/truce_test_support.dart';

// How titles and first lines are read is tested with `DocumentSummary`;
// here what the type adds for cards and search.
void main() {
  const type = MarkdownFileType();
  final shown = const MarkdownView(checkedItems: CheckedItems.inPlace).settings;
  const hidden = ViewSettings.none;

  FileText read(String text, {String name = 'a.md'}) => FileText(
    ListedFile(
      folder: Folder(
        id: folderId('home'),
        name: 'Home',
        color: 'teal',
        location: 'home',
      ),
      path: path(name),
      type: type.support,
      version: const FileVersion(0),
      modified: DateTime(2000),
    ),
    const TextFile.empty().withText(text),
  );

  FileCardSummary summaryOf(String text, {String name = 'a.md'}) =>
      type.cardSummary(read(text, name: name));

  test('a read document holds one summary for its title and preview', () {
    final file = read('# A\nb');

    expect(identical(file.summary, file.summary), isTrue);
    expect(file.summary.title, 'A');
  });

  test('the title takes the first level-1 heading', () {
    expect(summaryOf('intro\n## Sub\n# Shopping \n# Later').title, 'Shopping');
  });

  test('the title falls back to the file name without extension', () {
    expect(
      summaryOf('## Sub\ntext', name: 'lists/Groceries.md').title,
      'Groceries',
    );
    expect(summaryOf('text', name: 'lists/Plan.md').title, 'Plan');
  });

  test('the first line names a document, as plain words', () {
    String firstLine(String text) =>
        type.support.summary(text, maxLines: 0).firstLine;

    expect(firstLine('\n  Milk and eggs \nmore'), 'Milk and eggs');
    expect(firstLine(' \n'), '');
    expect(firstLine('# Shopping\nmilk'), 'Shopping');
  });

  test('the preview leaves checked items out unless shown in place', () {
    final summary = summaryOf('# Shopping\n- [x] milk\n- [ ] eggs');

    expect(summary.title, 'Shopping');
    expect(summary.preview(shown), '☑ milk\n☐ eggs');
    expect(summary.preview(hidden), '☐ eggs\n+ 1 done');
  });

  test('works out its previews once, holding no text', () {
    final summary = summaryOf('# A\n- [x] milk');

    expect(identical(summary.preview(hidden), summary.preview(hidden)), isTrue);
  });

  test('search reads the whole text; texts are not merged', () {
    expect(type.searchText(read('# A\nb')), '# A\nb');
    expect(type.merge, isNull);
  });

  test(r'a new file is a .md file with \n line breaks', () {
    expect(type.newFileExtension, '.md');
    expect(type.newFile.encode('a\nb'), 'a\nb'.codeUnits);
  });
}

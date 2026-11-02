import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_plain_text/truce_plain_text.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const type = PlainTextFileType();

  FileText read(String text, {String name = 'a.txt'}) => FileText(
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

  FileCardSummary summaryOf(String text, {String name = 'a.txt'}) =>
      type.cardSummary(read(text, name: name));

  test('the title is the first line as written', () {
    expect(summaryOf('# Shopping\nmilk').title, '# Shopping');
    expect(
      type.support.summary('# Shopping\nmilk', maxLines: 0).firstLine,
      '# Shopping',
    );
  });

  test('the first line is the title, the later lines the preview', () {
    final summary = summaryOf('Shopping\n\n- [x] milk\n  eggs  \n');

    expect(summary.title, 'Shopping');
    expect(summary.preview(ViewSettings.none), '- [x] milk\n  eggs');
    // How a file shows changes nothing of a plain text's preview.
    expect(
      summary.preview(ViewSettings({'checked': 'inPlace'})),
      summary.preview(ViewSettings.none),
    );
  });

  test('takes the title from the file name without words', () {
    expect(summaryOf(' \n', name: 'lists/Plan.txt').title, 'Plan');
  });

  test('previews hold up to ten lines', () {
    final lines = [for (var line = 0; line < 12; line++) 'line $line'];

    expect(
      summaryOf(lines.join('\n')).preview(ViewSettings.none),
      lines.skip(1).take(10).join('\n'),
    );
  });

  test('search reads the whole text; texts are not merged', () {
    expect(type.searchText(read('a\nb')), 'a\nb');
    expect(type.merge, isNull);
    expect(type.newFileExtension, '.txt');
  });
}

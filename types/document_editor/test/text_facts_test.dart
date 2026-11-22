import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

EditorStart _start(String text) => (
  text: text,
  version: const Version(1),
  view: ViewSettings.none,
  readOnly: false,
  isNew: false,
);

List<(String, String)> _shown(List<FileFact> facts) => [
  for (final fact in facts.cast<TextFact>()) (fact.label, fact.text),
];

void main() {
  test('a plain text document tells the lines and words of the text it '
      'is handed', () {
    final part = PlainEditorPart(_start('one\ntwo'));
    addTearDown(part.dispose);

    expect(_shown(part.facts('one two\nthree\n')), [
      ('Lines', '2'),
      ('Words', '3'),
    ]);
  });

  test('a Markdown document tells the same in every mode, markup counted '
      'as written', () {
    final part = MarkdownEditorPart(
      _start('# Shopping\n'),
      EditorPage(keepView: (_) {}, withFile: (_) async {}),
    );
    addTearDown(part.dispose);

    expect(_shown(part.facts('# Shopping\n- [ ] milk\n')), [
      ('Lines', '2'),
      ('Words', '6'),
    ]);
  });
}

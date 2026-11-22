import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart';
import 'package:truce_plain_text/truce_plain_text.dart';
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

/// The edit that makes [after] of [before], as an editor sends it.
TextEdit _editTo(String before, String after) =>
    TextEdit(before, textChange(before, after));

/// What [part]'s editor sends from now on.
List<EditorNotice> _sentBy(EditorPart part) {
  final sent = <EditorNotice>[];
  part.editor.events.listen(sent.add);
  return sent;
}

void main() {
  test('a plain text document counts what shows, typing not sent yet '
      'included, and sends nothing', () async {
    final part = PlainEditorPart(_start('one\ntwo'));
    addTearDown(part.dispose);
    final sent = _sentBy(part);
    final state = part.owner.state;
    part.owner.send(
      TextEdited(
        _editTo(state.text, 'one two\nthree\n'),
        revision: state.revision,
      ),
    );
    final before = part.editor.state;

    expect(_shown(part.facts()), [('Lines', '2'), ('Words', '3')]);

    expect(before.unsent, isTrue);
    expect(part.editor.state, before);
    expect(sent, isEmpty);
  });

  test('a Markdown document counts what shows in Visual edit, markup as '
      'written, and sends nothing', () async {
    final part = MarkdownEditorPart(
      _start('# Shopping\n- [ ] milk\n'),
      EditorPage(keepView: (_) {}, withFile: (_) async {}),
    );
    addTearDown(part.dispose);
    final sent = _sentBy(part);
    part.gate.send(
      (now) => Typed(
        'fresh ',
        over: TextSelection.caret(
          Place((now.content as FormattedContent).view.rows.last.leaf.id, 0),
        ),
        revision: now.revision,
      ),
    );
    final before = part.editor.state;

    expect(_shown(await part.facts()), [('Lines', '2'), ('Words', '7')]);

    expect(before.unsent, isTrue);
    expect(part.editor.state, before);
    expect(sent, isEmpty);
  });

  test('a Markdown document counts the same in Markdown edit', () async {
    final part = MarkdownEditorPart(
      _start('# Shopping\n- [ ] milk\n'),
      EditorPage(keepView: (_) {}, withFile: (_) async {}),
    )..pick(EditMode.markdown);
    addTearDown(part.dispose);

    expect(_shown(await part.facts()), [('Lines', '2'), ('Words', '6')]);
  });
}

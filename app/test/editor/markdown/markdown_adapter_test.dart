import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart' show Replaced, Version;
import 'package:truce_editor/editor/editor_gate.dart';
import 'package:truce_editor/editor/markdown/library/markdown_adapter.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

/// A Markdown edit adapter on an editor owner of [text].
final class _Markdown {
  _Markdown(String text)
    : gate = EditorGate(
        md.editorOwner(
          text,
          version: const Version(1),
          mode: md.EditMode.markdown,
        ),
      ) {
    adapter = MarkdownAdapter(gate);
    addTearDown(adapter.dispose);
  }

  final EditorGate gate;
  late final MarkdownAdapter adapter;

  Editor get editor => adapter.editor;
  Document get document => adapter.document;

  /// The text of each node.
  List<String> get lines => [
    for (final node in document) (node as TextNode).text.toPlainText(),
  ];

  List<String> get ids => [for (final node in document) node.id];

  /// The owner's text.
  String get text => (gate.state.content as md.MarkdownContent).text;

  DocumentPosition? get caret => adapter.composer.selection?.extent;

  DocumentPosition at(int node, int offset) => DocumentPosition(
    nodeId: document.getNodeAt(node)!.id,
    nodePosition: TextNodePosition(offset: offset),
  );

  void placeCaret(int node, int offset) => editor.execute([
    ChangeSelectionRequest(
      DocumentSelection.collapsed(position: at(node, offset)),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
    ),
  ]);

  void type(int node, int offset, String text) {
    placeCaret(node, offset);
    editor.execute([
      InsertTextRequest(
        documentPosition: at(node, offset),
        textToInsert: text,
        attributions: const {},
      ),
    ]);
  }

  /// Text from elsewhere, e.g. the file changed on another device.
  void fromElsewhere(String text) => gate.external(
    md.FromFile(Replaced(text, version: const Version(2), ackRev: 0)),
  );
}

void main() {
  test('shows one node per line', () {
    final markdown = _Markdown('# Title\r\n\r\n- [ ] a');

    expect(markdown.lines, ['# Title', '', '- [ ] a']);
  });

  test('typing in a line sends the text, its line endings kept', () {
    final markdown = _Markdown('a\r\nb\r\nc');

    markdown.type(1, 1, 'x');

    expect(markdown.text, 'a\r\nbx\r\nc');
    expect(markdown.lines, ['a', 'bx', 'c']);
  });

  test('Enter makes a line, which ends as the others do', () {
    final markdown = _Markdown('a\r\nbc');
    markdown.placeCaret(1, 1);

    markdown.editor.execute([InsertNewlineAtCaretRequest()]);

    expect(markdown.text, 'a\r\nb\r\nc');
    expect(markdown.document.getNodeIndexById(markdown.caret!.nodeId), 2);
  });

  test('joining a line to the one above removes its line break', () {
    final markdown = _Markdown('a\nb\nc');

    markdown.editor.execute([
      CombineParagraphsRequest(
        firstNodeId: markdown.ids[0],
        secondNodeId: markdown.ids[1],
      ),
    ]);

    expect(markdown.text, 'ab\nc');
  });

  test('pasted Windows line breaks make lines', () {
    final markdown = _Markdown('ab');
    markdown.placeCaret(0, 1);

    markdown.editor.execute([
      PasteEditorRequest(content: 'x\r\ny', pastePosition: markdown.at(0, 1)),
    ]);

    expect(markdown.lines, ['ax', 'yb']);
    expect(markdown.text, 'ax\nyb');
    expect(markdown.caret, markdown.at(1, 1));
  });

  test('text with line breaks typed into a line makes lines, the caret '
      'after it', () {
    final markdown = _Markdown('ab\nc');

    markdown.type(0, 1, 'x\ny');

    expect(markdown.lines, ['ax', 'yb', 'c']);
    expect(markdown.text, 'ax\nyb\nc');
    expect(markdown.caret, markdown.at(1, 1));
  });

  test('a text from elsewhere shows; unchanged lines keep their nodes and '
      'the caret stays on its line', () {
    final markdown = _Markdown('a\nb\nc');
    final ids = markdown.ids;
    markdown.placeCaret(2, 1);

    markdown.fromElsewhere('a\nnew\nb\nc');

    expect(markdown.lines, ['a', 'new', 'b', 'c']);
    expect([markdown.ids.first, ...markdown.ids.skip(2)], ids);
    expect(markdown.caret, markdown.at(2, 1));
  });

  test('highlights a line as the package reads it', () {
    final markdown = _Markdown('# Title');

    expect(
      markdown.adapter
          .highlightsOf(markdown.ids.single)
          .map((span) => span.highlight),
      contains(const md.HeadingHighlight(1)),
    );
  });

  test('finds the link at a position', () {
    final markdown = _Markdown('see [docs](https://x.org)');

    expect(markdown.adapter.linkAt(markdown.at(0, 6)), 'https://x.org');
    expect(markdown.adapter.linkAt(markdown.at(0, 1)), isNull);
  });
}

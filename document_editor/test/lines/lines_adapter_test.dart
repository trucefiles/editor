import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart' show FromFile, Replaced, Version;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;
import 'package:truce_test_support/truce_test_support.dart' show ManualTimers;

/// A line adapter on the Markdown edit of an editor owner of [text].
final class _Markdown {
  _Markdown(String text)
    : gate = EditorGate(
        md.editorOwner(
          text,
          version: const Version(1),
          mode: md.EditMode.markdown,
          startTimer: ManualTimers().start,
        ),
      ) {
    adapter = LinesAdapter(MarkdownText(gate));
    addTearDown(adapter.dispose);
  }

  final EditorGate gate;
  late final LinesAdapter adapter;

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
    md.Request(FromFile(Replaced(text, version: const Version(2), ackRev: 0))),
  );
}

void main() {
  test('shows one node per line', () {
    final markdown = _Markdown('# Title\n\n- [ ] a');

    expect(markdown.lines, ['# Title', '', '- [ ] a']);
  });

  test('typing in a line sends the text', () {
    final markdown = _Markdown('a\nb\nc');

    markdown.type(1, 1, 'x');

    expect(markdown.text, 'a\nbx\nc');
    expect(markdown.adapter.text, 'a\nbx\nc');
    expect(markdown.lines, ['a', 'bx', 'c']);
  });

  test('Enter makes a line', () {
    final markdown = _Markdown('a\nbc');
    markdown.placeCaret(1, 1);

    markdown.editor.execute([InsertNewlineAtCaretRequest()]);

    expect(markdown.text, 'a\nb\nc');
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

    markdown.adapter.paste('x\r\ny');

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

  test('a text from elsewhere without lines in the middle keeps the nodes '
      'at both ends', () {
    final markdown = _Markdown('a\nb\nc\nd');
    final ids = markdown.ids;

    markdown.fromElsewhere('a\nd');

    expect(markdown.lines, ['a', 'd']);
    expect(markdown.ids, [ids.first, ids.last]);
  });

  test('tells of each change of its lines', () {
    final markdown = _Markdown('a');
    var changes = 0;
    markdown.adapter.linesChanged.addListener(() => changes++);

    markdown.fromElsewhere('x');
    expect(markdown.adapter.lastChange, LinesChange.replaced);
    markdown.type(0, 1, 'b');
    expect(markdown.adapter.lastChange, LinesChange.edited);

    expect(changes, 2);
  });
}

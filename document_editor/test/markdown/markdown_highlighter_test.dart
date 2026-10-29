import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

/// A text a line editor edits, kept here.
final class _Text extends ChangeNotifier implements EditedText {
  _Text(this._text);

  String _text;

  @override
  ShownText get shown => (text: _text, caret: null);

  @override
  void edit(String text, {required bool pasted}) => _text = text;

  @override
  void caretMoved() {}

  /// [text] from elsewhere, e.g. an undo.
  void replace(String text) {
    _text = text;
    notifyListeners();
  }
}

/// Markdown edit's highlighter over the lines of [text]. Each test
/// disposes it, so no read is left waiting.
final class _Highlighted {
  _Highlighted(String text) : this._(_Text(text));

  _Highlighted._(this.text) : adapter = LinesAdapter(text) {
    highlighter = MarkdownHighlighter(adapter);
  }

  final _Text text;
  final LinesAdapter adapter;
  late final MarkdownHighlighter highlighter;

  String idOf(int line) => adapter.document.getNodeAt(line)!.id;

  /// The highlights line [line] shows.
  List<md.Highlight> on(int line) => [
    for (final span in highlighter.phase.highlightsOf(idOf(line)))
      span.highlight,
  ];

  DocumentPosition at(int line, int offset) => DocumentPosition(
    nodeId: idOf(line),
    nodePosition: TextNodePosition(offset: offset),
  );

  void type(int line, int offset, String text) => adapter.editor.execute([
    InsertTextRequest(
      documentPosition: at(line, offset),
      textToInsert: text,
      attributions: const {},
    ),
  ]);

  void dispose() {
    highlighter.dispose();
    adapter.dispose();
  }
}

const _heading = md.HeadingHighlight(1);

void main() {
  testWidgets('highlights the lines as they read, at once', (tester) async {
    final text = _Highlighted('# Title\nplain');

    expect(text.on(0), contains(_heading));
    expect(text.on(1), isEmpty);
    text.dispose();
  });

  testWidgets('reads the lines again once typing pauses for a second', (
    tester,
  ) async {
    final text = _Highlighted('Title');

    text.type(0, 0, '# ');
    await tester.pump(const Duration(milliseconds: 999));
    expect(text.on(0), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(text.on(0), contains(_heading));
    text.dispose();
  });

  testWidgets('each change starts the pause again', (tester) async {
    final text = _Highlighted('Title');

    text.type(0, 0, '#');
    await tester.pump(const Duration(milliseconds: 600));
    text.type(0, 1, ' ');
    await tester.pump(const Duration(milliseconds: 600));
    expect(text.on(0), isEmpty);
    await tester.pump(const Duration(milliseconds: 400));
    expect(text.on(0), contains(_heading));
    text.dispose();
  });

  testWidgets('a changed line keeps its highlights meanwhile; a new line '
      'has none', (tester) async {
    final text = _Highlighted('# Title');

    text.type(0, 7, 's');
    text.adapter.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: text.at(0, 8)),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
      InsertNewlineAtCaretRequest(),
    ]);
    text.type(1, 0, '# More');

    expect(text.on(0), contains(_heading));
    expect(text.on(1), isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(text.on(1), contains(_heading));
    text.dispose();
  });

  testWidgets('reads a text from elsewhere at once', (tester) async {
    final text = _Highlighted('Title\nplain');

    text.text.replace('# Title\nplain');

    expect(text.on(0), contains(_heading));
    text.dispose();
  });

  testWidgets('pasted lines leave the lines below their highlights, and '
      'each line gets its own after the pause', (tester) async {
    final text = _Highlighted('x\n# Below');

    text.adapter.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: text.at(0, 1)),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
    text.adapter.paste('\n# One\nplain');

    expect(text.adapter.text, 'x\n# One\nplain\n# Below');
    expect(text.on(3), contains(_heading));
    expect(text.on(1), isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(
      [
        for (final line in [0, 1, 2, 3]) text.on(line).contains(_heading),
      ],
      [false, true, false, true],
    );
    text.dispose();
  });

  testWidgets('finds a link only on a line as read', (tester) async {
    final text = _Highlighted('see [docs](https://x.org)');

    expect(text.highlighter.linkAt(text.at(0, 6)), 'https://x.org');
    expect(text.highlighter.linkAt(text.at(0, 1)), isNull);
    text.type(0, 0, 'x');
    expect(text.highlighter.linkAt(text.at(0, 7)), isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(text.highlighter.linkAt(text.at(0, 7)), 'https://x.org');
    text.dispose();
  });

  testWidgets('reads no more once disposed', (tester) async {
    final text = _Highlighted('Title');

    text.type(0, 0, '# ');
    text.dispose();

    // A read left waiting would fail the test as a pending timer.
    await tester.pump(const Duration(seconds: 1));
  });
}

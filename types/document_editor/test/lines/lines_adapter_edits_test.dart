import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart'
    show TextEdit, Version, applyChange, textChange;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;
import 'package:truce_test_support/truce_test_support.dart' show ManualTimers;

/// A text a line editor edits, kept here, each edit kept too; it shows
/// the very text the edit made, as the owners do.
final class _Recorded extends ChangeNotifier implements EditedText {
  _Recorded(this._text);

  String _text;
  int? _caret;
  final edits = <TextEdit>[];

  @override
  ShownText get shown => (text: _text, caret: _caret);

  /// [text] from elsewhere (an undo, another device), with the caret at
  /// [caret] or, if `null`, where it was.
  void fromElsewhere(String text, {int? caret}) {
    _text = text;
    _caret = caret;
    notifyListeners();
  }

  @override
  void edit(TextEdit edit, {required bool pasted}) {
    edits.add(edit);
    _text = edit.text;
    _caret = null;
    notifyListeners();
  }

  @override
  void caretMoved() {}
}

final class _Lines {
  _Lines(String text) : recorded = _Recorded(text) {
    adapter = LinesAdapter(recorded);
    addTearDown(adapter.dispose);
  }

  final _Recorded recorded;
  late final LinesAdapter adapter;

  Editor get editor => adapter.editor;
  Document get document => adapter.document;

  List<String> get lines => [
    for (final node in document) (node as TextNode).text.toPlainText(),
  ];

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
}

void main() {
  test('random edits, between texts from elsewhere, each send the minimal '
      'change that makes the lines shown', () {
    final random = Random(7);
    final lines = _Lines('one\ntwo words\n\nthree\nfour');
    int node() => random.nextInt(lines.document.nodeCount);
    int offsetIn(int node) => random.nextInt(lines.lines[node].length + 1);
    String word() => ['a', 'bc', 'x y', '', 'two'][random.nextInt(5)];

    for (var round = 0; round < 500; round++) {
      final before = lines.adapter.text;
      final edits = lines.recorded.edits.length;
      final at = node();
      switch (random.nextInt(8)) {
        case 0:
          lines.type(at, offsetIn(at), word());
        case 1:
          // An input method putting in text with a line break.
          lines.type(at, offsetIn(at), '${word()}\n${word()}');
        case 2:
          lines
            ..placeCaret(at, offsetIn(at))
            ..editor.execute([InsertNewlineAtCaretRequest()]);
        case 3 when at + 1 < lines.document.nodeCount:
          lines.editor.execute([
            CombineParagraphsRequest(
              firstNodeId: lines.document.getNodeAt(at)!.id,
              secondNodeId: lines.document.getNodeAt(at + 1)!.id,
            ),
          ]);
        case 4 when at + 1 < lines.document.nodeCount:
          final end =
              at + 1 + random.nextInt(lines.document.nodeCount - at - 1);
          final range = DocumentRange(
            start: lines.at(at, offsetIn(at)),
            end: lines.at(end, offsetIn(end)),
          );
          lines
            ..placeCaret(at, 0)
            ..editor.execute([DeleteContentRequest(documentRange: range)]);
        case 5:
          lines
            ..placeCaret(at, offsetIn(at))
            ..adapter.paste('${word()}\n${word()}\n');
        case 6 when lines.lines[at].isNotEmpty:
          // An input method replacing the word it composes.
          final from = random.nextInt(lines.lines[at].length);
          lines
            ..placeCaret(at, from + 1)
            ..editor.execute([
              DeleteContentRequest(
                documentRange: DocumentRange(
                  start: lines.at(at, from),
                  end: lines.at(at, from + 1),
                ),
              ),
              InsertTextRequest(
                documentPosition: lines.at(at, from),
                textToInsert: word(),
                attributions: const {},
              ),
            ]);
        case 7:
          // A text from elsewhere near this one: a word in or out.
          final from = random.nextInt(before.length + 1);
          final to = min(before.length, from + random.nextInt(4));
          final text = before.replaceRange(from, to, word());
          final caret = random.nextBool()
              ? random.nextInt(text.length + 1)
              : null;
          lines.recorded.fromElsewhere(text, caret: caret);
          expect(lines.lines.join('\n'), text, reason: 'round $round');
          expect(lines.adapter.text, text, reason: 'round $round');
          expect(
            lines.recorded.edits,
            hasLength(edits),
            reason: 'round $round',
          );
          continue;
        case _:
          continue;
      }
      final after = lines.lines.join('\n');
      expect(lines.adapter.text, after, reason: 'round $round');
      if (after == before) continue;
      expect(lines.recorded.edits.length, edits + 1, reason: 'round $round');
      final edit = lines.recorded.edits.last;
      // As small as the change found over the whole text; where it sits
      // in repeated text is a guess either way.
      final whole = textChange(before, after);
      expect(
        (edit.change.removed.length, edit.change.added.length),
        (whole.removed.length, whole.added.length),
        reason: 'round $round',
      );
      expect(applyChange(before, edit.change), after);
      expect(identical(lines.adapter.text, edit.text), isTrue);
    }
  });

  test('typing in a line leaves the nodes of the other lines as they '
      'are', () {
    final lines = _Lines('a\nb\nc\nd');
    final nodes = lines.document.toList();

    lines.type(2, 1, 'x');

    final now = lines.document.toList();
    expect(lines.lines, ['a', 'b', 'cx', 'd']);
    for (final index in [0, 1, 3]) {
      expect(identical(now[index], nodes[index]), isTrue);
    }
  });

  test('text with line breaks typed into a line replaces only its node', () {
    final lines = _Lines('a\nb\nc');
    final nodes = lines.document.toList();

    lines.type(1, 1, 'x\ny');

    final now = lines.document.toList();
    expect(lines.lines, ['a', 'bx', 'y', 'c']);
    expect(identical(now.first, nodes.first), isTrue);
    expect(identical(now.last, nodes.last), isTrue);
  });

  test('the owner keeps the very text the edit made, so its echo is no '
      'compare', () {
    final gate = EditorGate(
      md.editorOwner(
        md.MarkdownStart.read('a\nb'),
        version: const Version(1),
        mode: md.EditMode.markdown,
        startTimer: ManualTimers().start,
      ),
    );
    final adapter = LinesAdapter(MarkdownText(gate));
    addTearDown(adapter.dispose);

    adapter.editor.execute([
      InsertTextRequest(
        documentPosition: DocumentPosition(
          nodeId: adapter.document.getNodeAt(1)!.id,
          nodePosition: const TextNodePosition(offset: 1),
        ),
        textToInsert: 'x',
        attributions: const {},
      ),
    ]);

    final owned = (gate.state.content as md.MarkdownContent).text;
    expect(owned, 'a\nbx');
    expect(identical(owned, adapter.text), isTrue);
  });
}

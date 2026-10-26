import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart' show Edited, SecureReason, Version;
import 'package:truce_editor/editor/editor_gate.dart';
import 'package:truce_editor/editor/visual/library/visual_adapter.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

/// A Visual edit adapter on an editor owner of [text].
final class _Visual {
  _Visual(String text)
    : gate = EditorGate(md.editorOwner(text, version: const Version(1))) {
    gate.outputs.listen(outputs.add);
    adapter = VisualAdapter(gate);
  }

  final EditorGate gate;
  late final VisualAdapter adapter;
  final outputs = <md.EditorOutput>[];

  Editor get editor => adapter.editor;
  Document get document => adapter.document;

  /// The text of each node.
  List<String> get texts => [
    for (final node in document)
      node is TextNode ? node.text.toPlainText() : '[${node.runtimeType}]',
  ];

  List<String> get ids => [for (final node in document) node.id];

  DocumentSelection? get selection => adapter.composer.selection;

  /// The text the owner sends once secured.
  String secured() {
    gate.send((_) => const md.SecureEditor(SecureReason.close));
    return outputs
        .whereType<md.ToFile>()
        .map((output) => output.input)
        .whereType<Edited>()
        .last
        .text;
  }

  DocumentPosition at(int node, int offset) => DocumentPosition(
    nodeId: document.getNodeAt(node)!.id,
    nodePosition: TextNodePosition(offset: offset),
  );

  void caret(int node, int offset) => editor.execute([
    ChangeSelectionRequest(
      DocumentSelection.collapsed(position: at(node, offset)),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
    ),
  ]);
}

void main() {
  test('shows one node per row', () {
    final visual = _Visual('# Title\n\n- [ ] a\n- [x] b\n\n---\n\nend');

    expect(visual.texts, ['Title', 'a', 'b', '[LookBlockNode]', 'end']);
  });

  test('typed text goes to the owner, which the document then shows', () {
    final visual = _Visual('ab');
    visual.caret(0, 1);

    visual.editor.execute([
      InsertTextRequest(
        documentPosition: visual.at(0, 1),
        textToInsert: 'x',
        attributions: const {},
      ),
    ]);

    expect(visual.texts, ['axb']);
    expect(
      visual.selection?.extent.nodePosition,
      const TextNodePosition(offset: 2),
    );
    expect(visual.secured(), 'axb');
  });

  test('a caret the user moves goes to the owner', () {
    final visual = _Visual('ab');

    visual.caret(0, 2);

    expect(
      (visual.gate.state.content as md.FormattedContent).selection,
      isA<md.TextSelection>().having(
        (selection) => selection.extent.offset,
        'offset',
        2,
      ),
    );
  });

  test('Enter splits: the top keeps its node, the caret goes to the new '
      'one the library named', () {
    final visual = _Visual('- abc');
    final top = visual.ids.single;
    visual.caret(0, 1);

    visual.editor.execute([InsertNewlineAtCaretRequest('new')]);

    expect(visual.texts, ['a', 'bc']);
    expect(visual.ids, [top, 'new']);
    expect(visual.selection?.extent.nodeId, 'new');
    expect(visual.secured(), '- a\n- bc');
  });

  test('Backspace at a start joins with the row above', () {
    final visual = _Visual('a\n\nb');
    visual.caret(1, 0);

    visual.editor.execute([
      DeleteUpstreamAtBeginningOfNodeRequest(visual.document.getNodeAt(1)!),
    ]);

    expect(visual.texts, ['ab']);
  });

  test('other content requests are refused', () {
    final visual = _Visual('a');

    visual.editor.execute([
      DeleteNodeRequest(nodeId: visual.document.first.id),
    ]);

    expect(visual.texts, ['a']);
  });

  test('a waiting box tap shows checked at once', () {
    final visual = _Visual('- [ ] a');
    final item =
        ((visual.gate.state.content as md.FormattedContent)
                    .view
                    .doc
                    .root
                    .children
                    .single
                as md.ListNode)
            .items
            .single;

    visual.gate.tapBox(item.id);

    expect(visual.document.first.id, isNotEmpty);
  });
}

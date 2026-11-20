import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  test('an image kept once the caret went goes at the end, so it shows', () {
    final gate = EditorGate(
      md.editorOwner(
        md.MarkdownStart.read('milk\n\neggs'),
        version: const Version(1),
        mode: md.EditMode.visual,
        startTimer: ManualTimers().start,
      ),
    );
    addTearDown(gate.dispose);
    final actions = VisualActions(gate, onFold: (_) {}, onCaretPlaced: () {});
    List<md.NodeId> rows() => [
      for (final row in (gate.state.content as md.FormattedContent).view.rows)
        row.leaf.id,
    ];
    final before = rows();

    actions.image('kept/1.png');

    expect(gate.state.content.imageLinks, {'kept/1.png'});
    expect(rows(), [...before, isNot(isIn(before))]);
  });
}

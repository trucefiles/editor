import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart' show Version;
import 'package:truce_editor/editor/editor_gate.dart';
import 'package:truce_editor/editor/visual/library/visual_adapter.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

/// The budget for a typed character in a 2000-item list, from the
/// library's request to its document showing it, on the JIT that tests
/// run on: four times the compiled app's budget (8 ms, half a frame, so
/// layout and paint fit too), so a slow machine passes and work that
/// grows with the whole list fails.
const _keystrokeBudget = Duration(milliseconds: 32);

void main() {
  for (final nested in [false, true]) {
    test('a typed character in a 2000-item ${nested ? 'nested ' : ''}list '
        'shows within budget', () {
      final text = [
        for (var item = 0; item < 2000; item++)
          '${nested && item.isOdd ? '  ' : ''}'
              '- [${item % 3 == 0 ? 'x' : ' '}] item number $item with words',
      ].join('\n');
      final gate = EditorGate(md.editorOwner(text, version: const Version(1)));
      final adapter = VisualAdapter(gate);
      final node = adapter.document.getNodeAt(1000)!.id;
      final times = [
        for (var round = 0; round < 21; round++)
          _timed(
            () => adapter.editor.execute([
              InsertTextRequest(
                documentPosition: DocumentPosition(
                  nodeId: node,
                  nodePosition: const TextNodePosition(offset: 3),
                ),
                textToInsert: 'x',
                attributions: const {},
              ),
            ]),
          ),
      ];

      expect(
        (adapter.document.getNodeById(node)! as TextNode).text.toPlainText(),
        startsWith('ite${'x' * 21}m'),
      );
      expect(_median(times), lessThan(_keystrokeBudget));
    });
  }
}

Duration _timed(void Function() run) {
  final watch = Stopwatch()..start();
  run();
  return watch.elapsed;
}

Duration _median(List<Duration> times) =>
    (List.of(times)..sort())[times.length ~/ 2];

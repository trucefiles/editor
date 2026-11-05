import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart' show Version;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;
import 'package:truce_test_support/truce_test_support.dart' show ManualTimers;

/// The budget for a typed character in a 20000-line text, from the
/// library's request to the owner holding the edit, on the JIT that tests
/// run on: four times the compiled app's budget (8 ms, half a frame), so
/// a slow machine passes and work that reads the whole text grows past it.
const _keystrokeBudget = Duration(milliseconds: 32);

void main() {
  test('a typed character in a 20000-line Markdown edit is in the owner '
      'within budget', () {
    final text = [
      for (var line = 0; line < 20000; line++)
        '- [${line % 3 == 0 ? 'x' : ' '}] item number $line with words',
    ].join('\n');
    final gate = EditorGate(
      md.editorOwner(
        md.MarkdownStart.read(text),
        version: const Version(1),
        mode: md.EditMode.markdown,
        startTimer: ManualTimers().start,
      ),
    );
    final adapter = LinesAdapter(MarkdownText(gate));
    addTearDown(adapter.dispose);
    final node = adapter.document.getNodeAt(10000)!.id;
    final times = [
      for (var round = 0; round < 21; round++)
        _timed(
          () => adapter.editor.execute([
            InsertTextRequest(
              documentPosition: DocumentPosition(
                nodeId: node,
                nodePosition: TextNodePosition(offset: 3 + round),
              ),
              textToInsert: 'x',
              attributions: const {},
            ),
          ]),
        ),
    ];

    final shown = (gate.state.content as md.MarkdownContent).text;
    expect(shown.split('\n')[10000], startsWith('- [${'x' * 21}'));
    expect(_median(times), lessThan(_keystrokeBudget));
  });
}

Duration _timed(void Function() run) {
  final watch = Stopwatch()..start();
  run();
  return watch.elapsed;
}

Duration _median(List<Duration> times) =>
    (List.of(times)..sort())[times.length ~/ 2];

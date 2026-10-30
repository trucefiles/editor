import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart'
    show
        Edited,
        FromFile,
        Replaced,
        SaveTimer,
        SecureEditor,
        Ticket,
        ToFile,
        Version;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_markdown/truce_markdown.dart';
import 'package:truce_test_support/truce_test_support.dart';

const _delay = Duration(milliseconds: 700);

/// A gate on an editor owner of [text], with what the owner led to.
final class _Gate {
  _Gate(String text, {CheckedItems checkedItems = CheckedItems.inPlace})
    : this._(text, checkedItems, ManualTimers());

  _Gate._(String text, CheckedItems checkedItems, this.clock)
    : gate = EditorGate(
        editorOwner(
          MarkdownStart.read(text),
          version: const Version(1),
          checkedItems: checkedItems,
          startTimer: clock.start,
        ),
        checkDelay: _delay,
      ) {
    gate
      ..events.listen(outputs.add)
      ..addListener(() => heard++);
  }

  /// The save timers; they fire only when a test says.
  final ManualTimers clock;

  final EditorGate gate;
  final outputs = <EditorEvent>[];
  int heard = 0;

  FormattedContent get shown => gate.state.content as FormattedContent;

  List<ItemNode> get items =>
      (shown.view.doc.root.children.first as ListNode).items;

  /// Whether each item's box shows checked.
  List<bool> get boxes => [for (final item in items) gate.showsChecked(item)];

  /// Whether each item is checked in the document.
  List<bool?> get checked => [for (final item in items) item.checked];

  void tap(int index) => gate.tapBox(items[index].id);

  void type(String text) => gate.send(
    (now) => Typed(
      text,
      over: (now.content as FormattedContent).selection as TextSelection,
      revision: now.revision,
    ),
  );

  /// The texts the editor sent so far.
  List<Edited> get edits => [
    for (final output in outputs)
      if (output case Notice(notice: ToFile(input: final Edited edited))) edited,
  ];

  /// The text the editor sends when it is secured.
  String secured() {
    gate.send((_) => Request(SecureEditor(Ticket(), .close)));
    return edits.last.text;
  }
}

void main() {
  testWidgets('a tap waits, then toggles the item once', (tester) async {
    final run = _Gate('- [ ] a\n- [ ] b');

    run.tap(0);
    expect(run.boxes, [true, false]);
    expect(run.checked, [false, false]);

    await tester.pump(_delay);
    expect(run.checked, [true, false]);
    expect(run.boxes, [true, false]);
  });

  testWidgets('a second tap takes the first back', (tester) async {
    final run = _Gate('- [ ] a');

    run
      ..tap(0)
      ..tap(0);
    expect(run.boxes, [false]);

    await tester.pump(_delay);
    expect(run.checked, [false]);
  });

  testWidgets('quick taps wait for the last and move together', (tester) async {
    final run = _Gate(
      '- [ ] a\n- [ ] b\n- [ ] c',
      checkedItems: CheckedItems.moveToEnd,
    );

    run.tap(0);
    await tester.pump(_delay ~/ 2);
    run.tap(1);
    await tester.pump(_delay ~/ 2);
    expect(run.checked, [false, false, false]);

    await tester.pump(_delay ~/ 2);
    expect(run.secured(), '- [ ] c\n- [x] a\n- [x] b');
  });

  testWidgets('typing sends the waiting taps first', (tester) async {
    final run = _Gate('- [ ] a');

    run
      ..tap(0)
      ..type('x');

    expect(run.checked, [true]);
    expect(run.secured(), '- [x] xa');
    await tester.pump(_delay);
  });

  testWidgets('securing keeps waiting taps in the text', (tester) async {
    final run = _Gate('- [ ] a');

    run.tap(0);

    expect(run.secured(), '- [x] a');
  });

  testWidgets('a reload while taps wait drops them', (tester) async {
    final run = _Gate('- [ ] a');

    run
      ..tap(0)
      ..gate.external(
        const Request(
          FromFile(Replaced('- [ ] a\n', version: Version(2), ackRev: 0)),
        ),
      );
    await tester.pump(_delay);

    expect(run.checked, [false]);
  });

  testWidgets('a save timer does not cut the wait short', (tester) async {
    final run = _Gate('- [ ] a')
      ..type('x')
      ..tap(0);
    final heard = run.heard;

    run.clock.fire(SaveTimer.pause.delay);
    await tester.pump();
    expect(run.edits, hasLength(1), reason: 'the pause timer fired');
    expect(run.heard, greaterThan(heard), reason: 'listeners heard of it');
    expect(run.checked, [false]);

    await tester.pump(_delay);
    expect(run.checked, [true]);
  });

  test('listeners hear once per call', () {
    final run = _Gate('- [ ] a');

    run
      ..tap(0)
      ..type('x');

    expect(run.heard, 2);
  });
}

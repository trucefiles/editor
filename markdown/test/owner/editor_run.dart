/// A test run of one editor owner, shared by the owner's test suites.
library;

import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';
import 'package:truce_test_support/truce_test_support.dart';

const v1 = Version(1);
const v2 = Version(2);

/// An editor machine with what it led to so far. [onOutputs] hears what
/// each message sent through [send] led to.
final class EditorRun {
  EditorRun(
    String text, {
    CheckedItems checkedItems = CheckedItems.moveToEnd,
    EditMode mode = EditMode.visual,
    this.onOutputs,
  }) : owner = MachineRun.of(
         editorMachine(
           text,
           version: v1,
           checkedItems: checkedItems,
           mode: mode,
         ),
       );

  final MachineRun<EditorMessage, EditorState, EditorEvent, EditorEffect> owner;
  final void Function(List<Object?> outputs)? onOutputs;

  /// What the machine led to, the page's notices unwrapped.
  List<Object?> get outputs => _unwrapped(owner.outputs);

  void send(EditorMessage message) {
    final outputs = _unwrapped(owner.send(message));
    onOutputs?.call(outputs);
  }

  static List<Object?> _unwrapped(List<Object?> outputs) => [
    for (final output in outputs) output is Notice ? output.notice : output,
  ];

  /// The document page's [request].
  void request(EditorRequest request) => send(Request(request));

  EditorState get state => owner.state;
  int get revision => state.revision;

  FormattedContent get shown => state.content as FormattedContent;

  /// What the rows show.
  List<String> get rows => [
    for (final row in shown.view.rows)
      switch (row) {
        TextRow(:final leaf) => textOf(leaf).text,
        BlockRow(:final leaf) => '[${leaf.runtimeType}]',
      },
  ];

  List<Edited> get edits => [
    for (final output in outputs)
      if (output case ToFile(input: final Edited edited)) edited,
  ];

  /// The text last sent to the file owner.
  String get sent => edits.last.text;

  /// The leaf of row [index].
  NodeId leaf(int index) => shown.view.rows[index].leaf.id;

  void caret(int row, int offset) => send(
    CaretMoved(
      TextSelection.caret(Place(leaf(row), offset)),
      revision: revision,
    ),
  );

  void type(String text) => send(
    Typed(text, over: shown.selection as TextSelection, revision: revision),
  );

  void press(EditKey key) => send(Pressed(key, revision: revision));

  void runCommand(Command command) => send(Run(command, revision: revision));

  NodeId item(int index) =>
      (shown.view.doc.root.children.first as ListNode).items[index].id;

  void toggle(int index) =>
      send(ToggleItems([item(index)], revision: revision));

  /// The save timer [timer] last started fires.
  void fire(SaveTimer timer) => send(
    SaveTimerFired(
      outputs
          .whereType<StartSaveTimer>()
          .lastWhere((start) => start.delay == timer.delay)
          .id,
    ),
  );

  /// The edits are sent: a pause's draft.
  void pause() => fire(SaveTimer.pause);
}

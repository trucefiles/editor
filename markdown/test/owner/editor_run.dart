/// A test run of one editor owner, shared by the owner's test suites.
library;

import 'package:truce_core/truce_core.dart' show Edited, Version;
import 'package:truce_markdown/truce_markdown.dart';

const v1 = Version(1);
const v2 = Version(2);

/// An editor owner with what it led to so far.
final class EditorRun {
  EditorRun(
    String text, {
    CheckedItems checkedItems = CheckedItems.moveToEnd,
    EditMode mode = EditMode.visual,
  }) : owner = editorOwner(
         text,
         version: v1,
         checkedItems: checkedItems,
         mode: mode,
       ) {
    owner.outputs.listen(outputs.add);
  }

  final EditorOwner owner;
  final outputs = <EditorOutput>[];

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

  void caret(int row, int offset) => owner.send(
    CaretMoved(
      TextSelection.caret(Place(leaf(row), offset)),
      revision: revision,
    ),
  );

  void type(String text) => owner.send(
    Typed(text, over: shown.selection as TextSelection, revision: revision),
  );

  void press(EditKey key) => owner.send(Pressed(key, revision: revision));

  void runCommand(Command command) =>
      owner.send(Run(command, revision: revision));

  NodeId item(int index) =>
      (shown.view.doc.root.children.first as ListNode).items[index].id;

  void toggle(int index) =>
      owner.send(ToggleItems([item(index)], revision: revision));

  /// The save timer [timer] last started fires.
  void fire(SaveTimer timer) => owner.send(
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

import 'package:flutter/foundation.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../editor_gate.dart';
import '../run_command.dart';

/// What the user does in Visual edit beside typing: the rows' boxes,
/// delete buttons, drags and swipes, the Done headings, Add item buttons
/// and raw blocks, and the toolbar. Each is one input to the editor owner
/// through the [_gate].
final class VisualActions {
  VisualActions(
    this._gate, {
    required this.onFold,
    required this.onCaretPlaced,
  });

  final EditorGate _gate;

  /// The item being dragged, whose subitems fold meanwhile; `null` once
  /// the drag ends.
  final ValueChanged<NodeId?> onFold;

  /// The caret went into a row the user added: the editor takes the
  /// keyboard.
  final VoidCallback onCaretPlaced;

  FormattedContent? get _shown => switch (_gate.state.content) {
    final FormattedContent shown => shown,
    MarkdownContent() => null,
  };

  /// The text place the caret is in, if any.
  NodeId? get _caretLeaf => switch (_shown?.selection) {
    TextSelection(:final extent) => extent.leaf,
    _ => null,
  };

  /// A tap on [item]'s box: it waits a moment for more taps.
  void toggle(NodeId item) => _gate.tapBox(item);

  void deleteItem(NodeId item) => _gate.run((_) => DeleteItem(item));

  /// The item whose text [leaf] is, one level deeper or shallower, where
  /// it can go; the user's selection stays where it is.
  void indent(NodeId leaf) => _gate.run(
    (selection) => switch (_shown?.view) {
      final view? when canIndent(view, leaf) => Indent(
        TextSelection.caret(Place(leaf, 0)),
        after: selection,
      ),
      _ => null,
    },
  );

  void outdent(NodeId leaf) => _gate.run(
    (selection) => switch (_shown?.view) {
      final view? when canOutdent(view, leaf) => Outdent(
        TextSelection.caret(Place(leaf, 0)),
        after: selection,
      ),
      _ => null,
    },
  );

  /// [item] lifted to be dragged: taps waiting go first; its subitems
  /// fold.
  void dragStarted(NodeId item) {
    _gate.send((_) => null);
    onFold(item);
  }

  void dragEnded() => onFold(null);

  /// [item], whose text is [leaf], dropped right next to [target]'s row,
  /// [below] it or above; dropped on itself, it goes [levels] deeper
  /// (shallower if negative).
  void drop(
    NodeId item, {
    required NodeId leaf,
    required NodeId target,
    required bool below,
    required int levels,
  }) {
    if (item != target) {
      return _gate.run(
        (selection) => switch (_firstSubitem(target)) {
          // Right below the row, above the subitems shown under it.
          final first? when below && first == item => null,
          final first? when below => MoveItem(
            item,
            first,
            below: false,
            selection: selection,
          ),
          _ => MoveItem(item, target, below: below, selection: selection),
        },
      );
    }
    final step = levels > 0 ? indent : outdent;
    for (final _ in Iterable<void>.generate(levels.abs())) {
      step(leaf);
    }
  }

  /// The first subitem of [item], if it shows right under its text.
  NodeId? _firstSubitem(NodeId item) => switch (_shown?.view.doc.nodeOf(item)) {
    ItemNode(children: [_, ListNode(:final items), ...]) => items.first.id,
    _ => null,
  };

  /// [list]'s Done section folded or unfolded.
  void setCollapsed(NodeId list, {required bool collapsed}) =>
      _gate.send((_) => SetCollapsed(list, collapsed: collapsed));

  /// A new item in [list], as its [first] or last, with the caret in it.
  void addItem(NodeId list, {required bool first}) {
    _gate.run((_) => AddItem(list, first: first));
    onCaretPlaced();
  }

  /// [block], a raw block, shown as its raw text to edit.
  void openRaw(NodeId block) {
    _gate.send(
      (now) => OpenRawBlock(block, atEnd: false, revision: now.revision),
    );
    onCaretPlaced();
  }

  // The toolbar.

  /// The link dialog's answer for [range], asked at [revision]: its text
  /// links to [url]. Dropped if the text changed meanwhile.
  void setLink(TextSelection range, String url, {required int revision}) =>
      _gate.send(
        (now) => switch (now.content) {
          FormattedContent(:final view) => Run(
            SetLink(range, plainTextOf(copiedLines(view, range)), url),
            revision: revision,
          ),
          MarkdownContent() => null,
        },
      );

  /// [key] pressed on the toolbar.
  void press(EditKey key) =>
      _gate.send((now) => Pressed(key, revision: now.revision));

  /// The caret's text made the next heading level, or text again.
  void heading() => _gate.run(
    (selection) => switch ((selection, _shown?.view)) {
      (TextSelection(:final extent), final view?) => SetHeading(
        extent,
        nextHeadingLevel(switch (view.doc.nodeOf(extent.leaf)) {
          HeadingNode(:final level) => level,
          _ => null,
        }),
      ),
      _ => null,
    },
  );

  /// The selected blocks put in a quote, or taken out of it.
  void quote() => _gate.run(
    (selection) => switch (selection) {
      final TextSelection range => SetFrame(range, FrameKind.quote),
      BlockSelection() => null,
    },
  );

  /// Whether the caret's item can go one level deeper.
  bool get canIndentHere => switch ((_shown?.view, _caretLeaf)) {
    (final view?, final leaf?) => canIndent(view, leaf),
    _ => false,
  };

  /// Whether the caret's item can go one level shallower.
  bool get canOutdentHere => switch ((_shown?.view, _caretLeaf)) {
    (final view?, final leaf?) => canOutdent(view, leaf),
    _ => false,
  };
}

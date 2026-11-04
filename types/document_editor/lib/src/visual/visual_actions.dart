import 'package:flutter/foundation.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../editor_gate.dart';
import '../run_command.dart';

/// What showed as a gesture (a drag, a swipe) started: what it does on
/// release is dropped if the text changed meanwhile, as the items it
/// holds may then be other ones.
extension type const ShownAt(int revision) {}

/// What the user does in Visual edit beside typing: the rows' boxes,
/// delete buttons, drags and swipes, the Done headings, Add item buttons
/// and raw blocks, and the toolbar. Each is one input to the editor owner
/// through the [_gate]. The rows' controls (box, delete button, drag,
/// swipe, Done heading) leave no caret once they acted, so nothing
/// scrolls to an old one; the next tap into text places it.
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

  /// Whether a caret (or selection) shows, in the text or in a raw block
  /// open as text.
  bool get hasCaret => switch (_shown) {
    FormattedContent(:final selection, :final raw) =>
      selection != null || raw != null,
    null => false,
  };

  /// What is on at the caret or the selection, for the toolbar to show;
  /// nothing while a raw block is open as text.
  FormatState get formatState => switch (_shown) {
    FormattedContent(
      :final view,
      :final selection,
      :final typingStyle,
      raw: null,
    ) =>
      formatStateAt(view, selection, typingStyle: typingStyle),
    _ => FormatState.none,
  };

  /// The text place the caret is in, if any.
  NodeId? get _caretLeaf => switch (_shown?.selection) {
    TextSelection(:final extent) => extent.leaf,
    _ => null,
  };

  /// A tap on [item]'s box: it waits a moment for more taps.
  void toggle(NodeId item) => _gate.tapBox(item);

  void deleteItem(NodeId item) =>
      _gate.run((_) => DeleteItem(item), byControl: true);

  /// A drag or swipe starts: taps waiting go first; what shows then. A
  /// raw block open as text stays open until the gesture acts, so its row
  /// stays where the gesture holds it.
  ShownAt gestureStarted() {
    _gate.send((_) => null);
    return ShownAt(_gate.state.revision);
  }

  /// Whether the text is still as it showed [from].
  bool _still(ShownAt from) => _gate.state.revision == from.revision;

  /// [item] one level deeper, by a swipe or drag started [from], where it
  /// can go; whether it went.
  bool indent(NodeId item, ShownAt from) =>
      _shift(item, from, canIndent, Indent.new);

  /// [item] one level shallower (see [indent]).
  bool outdent(NodeId item, ShownAt from) =>
      _shift(item, from, canOutdent, Outdent.new);

  bool _shift(
    NodeId item,
    ShownAt from,
    bool Function(ViewRows view, NodeId leaf) can,
    Command Function(TextSelection at) shift,
  ) =>
      _still(from) &&
      _gate.run(
        (_) => switch ((_shown?.view, _leafOf(item))) {
          (final view?, final leaf?) when can(view, leaf) => shift(
            TextSelection.caret(Place(leaf, 0)),
          ),
          _ => null,
        },
        byControl: true,
      );

  /// The block that starts [item], as the blocks are now.
  NodeId? _leafOf(NodeId item) => switch (_shown?.view.doc.nodeOf(item)) {
    final ItemNode item => leavesIn(item).first.id,
    _ => null,
  };

  /// [item] lifted to be dragged (see [gestureStarted]); its subitems
  /// fold. What shows then.
  ShownAt dragStarted(NodeId item) {
    final from = gestureStarted();
    onFold(item);
    return from;
  }

  void dragEnded() => onFold(null);

  /// Where [item] dropped right next to [target]'s row, [below] it or
  /// above, goes; `null` where it stays where it shows.
  ({NodeId item, bool below})? _placeOf(
    NodeId item,
    NodeId target, {
    required bool below,
  }) => switch (_shown) {
    final shown? => dropPlace(shown.view, item, target, below: below),
    null => null,
  };

  /// The item [item] goes next to, as one of its list, dropped right next
  /// to [target]'s row, [below] it or above; `null` where it stays where
  /// it shows.
  NodeId? goesNextTo(NodeId item, NodeId target, {required bool below}) =>
      _placeOf(item, target, below: below)?.item;

  /// [item], dragged [from] what showed then, dropped right next to
  /// [target]'s row, [below] it or above; dropped on itself, it goes
  /// [levels] deeper (shallower if negative), each level on what the one
  /// before left.
  void drop(
    NodeId item, {
    required NodeId target,
    required bool below,
    required int levels,
    required ShownAt from,
  }) {
    if (item == target) {
      final step = levels > 0 ? indent : outdent;
      var at = from;
      for (final _ in Iterable<void>.generate(levels.abs())) {
        if (!step(item, at)) return;
        at = ShownAt(_gate.state.revision);
      }
      return;
    }
    if (!_still(from)) return;
    _gate.run(
      (_) => switch (_placeOf(item, target, below: below)) {
        (item: final next, :final below) => MoveItem(item, next, below: below),
        null => null,
      },
      byControl: true,
    );
  }

  /// [list]'s Done section folded or unfolded.
  void setCollapsed(NodeId list, {required bool collapsed}) =>
      _gate.send((_) => SetCollapsed(list, collapsed: collapsed));

  /// A new item in [list], as its [first] or last, with the caret in it.
  void addItem(NodeId list, {required bool first}) {
    _gate.run((_) => AddItem(list, at: first ? AddAt.first : AddAt.last));
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

  /// The link dialog's answer for [range], asked at [revision]: it shows
  /// [text] as a link to [url]. Dropped if the text changed meanwhile.
  void setLink(
    TextSelection range,
    String text,
    String url, {
    required int revision,
  }) => _gate.send((_) => Run(SetLink(range, text, url), revision: revision));

  /// The link the caret is in, if any: the link popup shows it.
  LinkHere? get caretLink => switch (_shown) {
    FormattedContent(
      :final view,
      selection: final TextSelection caret,
      raw: null,
    )
        when caret.isCaret =>
      linkHere(view, caret),
    _ => null,
  };

  /// The link at [range], as shown at [revision], taken away, its text
  /// kept. Dropped if the text changed meanwhile.
  void removeLink(TextSelection range, {required int revision}) =>
      _gate.send((_) => Run(RemoveLink(range.base), revision: revision));

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

  /// A separator after the caret's block or the selected one, or as an
  /// item after its item.
  void separator() => _gate.run(
    (selection) => switch (selection) {
      TextSelection(:final extent) => AddDivider(extent.leaf),
      BlockSelection(:final block) ||
      BlockCaret(:final block) => AddDivider(block),
      null => null,
    },
  );

  /// The selected blocks put in a quote, or taken out of it.
  void quote() => _gate.run(
    (selection) => switch (selection) {
      final TextSelection range => SetFrame(range, FrameKind.quote),
      BlockSelection() || BlockCaret() || null => null,
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

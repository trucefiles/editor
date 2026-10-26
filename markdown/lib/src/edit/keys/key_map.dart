import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../../visible/formatting.dart';
import '../commands/command.dart';
import '../commands/indent.dart';
import '../commands/text_commands.dart';
import '../selection.dart';

/// The keys Visual edit acts on; the platform maps physical keys and the
/// input method's requests to these.
enum EditKey {
  enter,
  shiftEnter,
  backspace,
  delete,
  tab,
  shiftTab,
  bold,
  italic,
  link,
  numbered,
  bullet,
  checklist,
}

/// What a key does.
sealed class KeyAction {
  const KeyAction();
}

/// The key runs [command].
final class RunCommand extends KeyAction {
  const RunCommand(this.command);

  final Command command;
}

/// The key selects [block], a divider, whole.
final class SelectBlock extends KeyAction {
  const SelectBlock(this.block);

  final NodeId block;
}

/// The key opens [block], a raw block, as its raw text, the caret at its
/// end if [atEnd], else at its start.
final class OpenRaw extends KeyAction {
  const OpenRaw(this.block, {required this.atEnd});

  final NodeId block;
  final bool atEnd;
}

/// A caret alone: [format] toggled in the typing style.
final class ToggleTypingStyle extends KeyAction {
  const ToggleTypingStyle(this.format);

  final TextFormat format;
}

/// The link dialog opens.
final class OpenLinkDialog extends KeyAction {
  const OpenLinkDialog();
}

/// The key does nothing, and nothing else gets it.
final class Consumed extends KeyAction {
  const Consumed();
}

/// What [key] does with [selection] in what [view] shows: the key map,
/// its rules in priority order.
KeyAction keyAction(ViewRows view, Selection selection, EditKey key) =>
    switch ((selection, key)) {
      (_, EditKey.link) => const OpenLinkDialog(),
      (final TextSelection range, EditKey.numbered) => _frame(range, .numbered),
      (final TextSelection range, EditKey.bullet) => _frame(range, .bullet),
      (final TextSelection range, EditKey.checklist) => _frame(
        range,
        .checkbox,
      ),
      (final TextSelection range, EditKey.bold) => _style(range, .strong),
      (final TextSelection range, EditKey.italic) => _style(range, .emphasis),
      (BlockSelection(:final block), EditKey.backspace || EditKey.delete) =>
        RunCommand(RemoveBlock(block)),
      (BlockSelection(), _) => const Consumed(),
      (final TextSelection range, _) => _Keys(view, range).action(key),
    };

KeyAction _frame(TextSelection range, FrameKind kind) =>
    RunCommand(SetFrame(range, kind));

KeyAction _style(TextSelection range, TextFormat format) => range.isCaret
    ? ToggleTypingStyle(format)
    : RunCommand(ToggleStyle(range, format));

/// The editing keys at a text selection.
final class _Keys {
  _Keys(this.view, this.range)
    : at = range.extent,
      index = view.rowOf(range.extent.leaf)!;

  final ViewRows view;
  final TextSelection range;
  final Place at;

  /// The index of the row the caret is in.
  final int index;

  Row get _row => view.rows[index];
  Row? get _rowAbove => index > 0 ? view.rows[index - 1] : null;
  Row? get _rowBelow => view.rows.elementAtOrNull(index + 1);

  late final String _text = textOf(_row.leaf).text;
  late final bool _inCode = _row.leaf is CodeNode;

  /// The container the caret's text is in.
  late final DocContainer _frame = view.doc.parentOf(at.leaf)!;

  KeyAction action(EditKey key) => switch (key) {
    EditKey.enter => RunCommand(_enter()),
    EditKey.shiftEnter => RunCommand(
      _inCode ? SplitBlock(range) : LineBreak(range),
    ),
    EditKey.backspace ||
    EditKey.delete when !range.isCaret => RunCommand(DeleteRange(range)),
    EditKey.backspace => _backspace(),
    EditKey.delete => _delete(),
    EditKey.tab when _inCode && range.base.leaf == at.leaf => RunCommand(
      ReplaceText(range, '\t'),
    ),
    EditKey.tab when canIndent(view, at.leaf) => RunCommand(Indent(range)),
    EditKey.shiftTab when canOutdent(view, at.leaf) => RunCommand(
      Outdent(range),
    ),
    EditKey.tab || EditKey.shiftTab => const Consumed(),
    EditKey.bold ||
    EditKey.italic ||
    EditKey.link ||
    EditKey.numbered ||
    EditKey.bullet ||
    EditKey.checklist => throw ArgumentError.value(key, 'key', 'no edit key'),
  };

  Command _enter() => switch (_frame) {
    _ when !range.isCaret || _row.done || _text.isNotEmpty => SplitBlock(range),
    final ItemNode item when _isOwnPlace(item) => Outdent(range),
    QuoteNode() => RemoveFrame(at.leaf),
    _ => SplitBlock(range),
  };

  /// Whether the caret's text is [item]'s own place: the empty paragraph
  /// an empty item, or one that starts with a list, shows.
  bool _isOwnPlace(ItemNode item) => switch (item.children) {
    [final first, ...final rest] =>
      first.id == at.leaf && (rest.isEmpty || rest.first is ListNode),
    _ => false,
  };

  KeyAction _backspace() => switch (_rowAbove) {
    _ when at.offset > 0 => _deleteTo(graphemeBefore(_text, at.offset)),
    _ when _row.done => _joinInSection(_rowAbove, JoinWithPrevious(at)),
    _ when _firstOfFrame => RunCommand(RemoveFrame(at.leaf)),
    final BlockRow above => _into(above, atEnd: true),
    _ when _inCode && _text.isNotEmpty => const Consumed(),
    null => const Consumed(),
    TextRow() => RunCommand(JoinWithPrevious(at)),
  };

  KeyAction _delete() => switch (_rowBelow) {
    _ when at.offset < _text.length => _deleteTo(
      graphemeAfter(_text, at.offset),
    ),
    final BlockRow below => _into(below, atEnd: false),
    null => const Consumed(),
    final TextRow below => _joinInSection(below, JoinWithNext(at)),
  };

  /// Whether the caret's text is the first that its innermost item or
  /// quote shows.
  bool get _firstOfFrame => switch (_frame) {
    DocRoot() => false,
    final frame =>
      view.rows.indexWhere(
            (row) => view.doc
                .pathOf(row.leaf.id)
                .any((container) => container.id == frame.id),
          ) ==
          index,
  };

  /// [join] with [neighbor] if it shows in the same Done section or
  /// outside of both.
  KeyAction _joinInSection(Row? neighbor, Command join) =>
      neighbor is TextRow && neighbor.done == _row.done
      ? RunCommand(join)
      : const Consumed();

  KeyAction _into(BlockRow row, {required bool atEnd}) => switch (row.leaf) {
    DividerNode(:final id) => SelectBlock(id),
    final leaf => OpenRaw(leaf.id, atEnd: atEnd),
  };

  KeyAction _deleteTo(int offset) =>
      RunCommand(DeleteRange(TextSelection(at, Place(at.leaf, offset))));
}

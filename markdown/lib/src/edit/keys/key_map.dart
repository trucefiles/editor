import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../../visible/formatting.dart';
import '../commands/command.dart';
import '../commands/items.dart';
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

/// The link dialog opens, for a selection in one text place.
final class OpenLinkDialog extends KeyAction {
  const OpenLinkDialog();
}

/// The key does nothing, and nothing else gets it.
final class Consumed extends KeyAction {
  const Consumed();
}

/// What [key] does with [selection] in what [view] shows: the key map,
/// its rules in priority order.
KeyAction keyAction(
  ViewRows view,
  Selection selection,
  EditKey key,
) => switch ((selection, key)) {
  (final TextSelection range, EditKey.link)
      when range.base.leaf == range.extent.leaf =>
    const OpenLinkDialog(),
  (_, EditKey.link) => const Consumed(),
  (final TextSelection range, EditKey.numbered) => _frame(range, .numbered),
  (final TextSelection range, EditKey.bullet) => _frame(range, .bullet),
  (final TextSelection range, EditKey.checklist) => _frame(range, .checkbox),
  (final TextSelection range, EditKey.bold) => _style(range, .strong),
  (final TextSelection range, EditKey.italic) => _style(range, .emphasis),
  (BlockSelection(:final block), EditKey.backspace) => RunCommand(
    RemoveBlock(block, backward: true),
  ),
  (BlockSelection(:final block), EditKey.delete) => RunCommand(
    RemoveBlock(block, backward: false),
  ),
  (BlockSelection(:final block), EditKey.enter) => RunCommand(LineAfter(block)),
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
    final ItemNode item when isOwnLine(item, at.leaf) => Outdent(range),
    QuoteNode() => RemoveFrame(at.leaf),
    _ => SplitBlock(range),
  };

  KeyAction _backspace() => switch (_rowAbove) {
    _ when at.offset > 0 => _deleteTo(graphemeBefore(_text, at.offset)),
    _ when _row.done => _inSection(
      _rowAbove,
      JoinWithPrevious(at),
      backward: true,
    ),
    _ when _firstOfFrame => RunCommand(RemoveFrame(at.leaf)),
    final BlockRow above => _inSection(
      above,
      JoinWithPrevious(at),
      backward: true,
    ),
    _ when _inCode && _text.isNotEmpty => const Consumed(),
    null => const Consumed(),
    TextRow() => RunCommand(JoinWithPrevious(at)),
  };

  KeyAction _delete() => switch (_rowBelow) {
    _ when at.offset < _text.length => _deleteTo(
      graphemeAfter(_text, at.offset),
    ),
    null => const Consumed(),
    final below => _inSection(below, JoinWithNext(at), backward: false),
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

  /// Backspace ([backward]) or Delete into [neighbor], if it shows in
  /// the same Done section or outside of both: a text is joined by
  /// [join], a block entered (see [_into]); else nothing happens.
  KeyAction _inSection(Row? neighbor, Command join, {required bool backward}) =>
      switch (neighbor) {
        final row? when row.done != _row.done => const Consumed(),
        final BlockRow block => _into(block, backward: backward),
        TextRow() => RunCommand(join),
        null => const Consumed(),
      };

  /// Backspace ([backward]) or Delete into [row], a block next to the
  /// caret: a divider goes, as one character; any other opens as its raw
  /// text, the caret at the side it came from.
  KeyAction _into(BlockRow row, {required bool backward}) => switch (row.leaf) {
    DividerNode(:final id) => RunCommand(
      RemoveBlock(id, backward: backward, caret: at),
    ),
    final leaf => OpenRaw(leaf.id, atEnd: backward),
  };

  KeyAction _deleteTo(int offset) =>
      RunCommand(DeleteRange(TextSelection(at, Place(at.leaf, offset))));
}

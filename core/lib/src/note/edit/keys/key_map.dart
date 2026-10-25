import 'package:characters/characters.dart';
import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../visible/formatting.dart';
import '../commands/command.dart';
import '../commands/indent.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';

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

/// The key selects [block], a rule, whole.
final class SelectBlock extends KeyAction {
  const SelectBlock(this.block);

  final BlockId block;
}

/// The key opens [block], one without text, as its raw text, the caret
/// at its end if [atEnd], else at its start.
final class OpenRaw extends KeyAction {
  const OpenRaw(this.block, {required this.atEnd});

  final BlockId block;
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

/// What [key] does with [selection] in [note]: the key map, its rules in
/// priority order.
KeyAction keyAction(ShownNote note, Selection selection, EditKey key) =>
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
      (final TextSelection range, _) => _Keys(note, range).action(key),
    };

KeyAction _frame(TextSelection range, FrameKind kind) =>
    RunCommand(SetFrame(range, kind));

KeyAction _style(TextSelection range, TextFormat format) => range.isCaret
    ? ToggleTypingStyle(format)
    : RunCommand(ToggleStyle(range, format));

/// The editing keys at a text selection.
final class _Keys {
  _Keys(this.note, this.range)
    : at = range.extent,
      row = note.rowOf(range.extent.slot)!;

  final ShownNote note;
  final TextSelection range;
  final Place at;

  /// The index of the row the caret is in.
  final int row;

  late final String _text = note.textOf(at.slot).text;
  late final bool _inCode = switch (at.slot) {
    LeafSlot(:final leaf) => note.tree.blockOf(leaf) is CodeBlock,
    _ => false,
  };

  KeyAction action(EditKey key) => switch (key) {
    EditKey.enter => RunCommand(_enter()),
    EditKey.shiftEnter => RunCommand(
      _inCode ? SplitBlock(range) : LineBreak(range),
    ),
    EditKey.backspace ||
    EditKey.delete when !range.isCaret => RunCommand(DeleteRange(range)),
    EditKey.backspace => _backspace(),
    EditKey.delete => _delete(),
    EditKey.tab when _inCode && range.base.slot == at.slot => RunCommand(
      ReplaceText(range, '\t'),
    ),
    EditKey.tab when canIndent(note, at.slot) => RunCommand(Indent(range)),
    EditKey.shiftTab when canOutdent(note, at.slot) => RunCommand(
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

  Command _enter() => switch (at.slot) {
    _ when !range.isCaret || _row.done => SplitBlock(range),
    ItemSlot() when _text.isEmpty => Outdent(range),
    GapSlot() when _row.path.lastOrNull is QuoteBlock => RemoveFrame(at.slot),
    _ => SplitBlock(range),
  };

  KeyAction _backspace() => switch (_rowAbove) {
    _ when at.offset > 0 => _deleteTo(_graphemeBefore),
    _ when _row.done => _joinInSection(_rowAbove, JoinWithPrevious(at.slot)),
    _ when _firstOfFrame => RunCommand(RemoveFrame(at.slot)),
    final BlockRow above => _into(above, atEnd: true),
    _ when _inCode && _text.isNotEmpty => const Consumed(),
    null => const Consumed(),
    TextRow() => RunCommand(JoinWithPrevious(at.slot)),
  };

  KeyAction _delete() => switch (_rowBelow) {
    _ when at.offset < _text.length => _deleteTo(_graphemeAfter),
    final BlockRow below => _into(below, atEnd: false),
    null => const Consumed(),
    final TextRow below => _joinInSection(below, JoinWithNext(at.slot)),
  };

  Row get _row => note.rows[row];
  Row? get _rowAbove => row > 0 ? note.rows[row - 1] : null;
  Row? get _rowBelow => note.rows.elementAtOrNull(row + 1);

  /// Whether the caret's text is the first of its innermost item or
  /// quote.
  bool get _firstOfFrame => switch (_row.path.lastOrNull) {
    final ContainerBlock frame =>
      note.rows.indexWhere((other) => other.path.contains(frame)) == row,
    null => false,
  };

  /// [join] with [neighbor] if it shows in the same Done section or
  /// outside of both.
  KeyAction _joinInSection(Row? neighbor, Command join) =>
      neighbor is TextRow && neighbor.done == _row.done
      ? RunCommand(join)
      : const Consumed();

  KeyAction _into(BlockRow row, {required bool atEnd}) => switch (row.leaf) {
    RuleBlock(:final id) => SelectBlock(id),
    final leaf => OpenRaw(leaf.id, atEnd: atEnd),
  };

  KeyAction _deleteTo(int offset) =>
      RunCommand(DeleteRange(TextSelection(at, Place(at.slot, offset))));

  int get _graphemeBefore =>
      at.offset - _text.substring(0, at.offset).characters.last.length;

  int get _graphemeAfter =>
      at.offset + _text.substring(at.offset).characters.first.length;
}

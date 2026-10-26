import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart'
    show Edited, Picked, Replaced, Secure, Step, Version;

import '../edit/clipboard/clipboard_lines.dart';
import '../edit/commands/command.dart';
import '../edit/keys/key_map.dart';
import '../edit/shown/rows.dart';
import '../edit/shown/selection.dart';
import '../edit/shown/shown_document.dart';
import '../edit/shown/slot.dart';
import '../edit/shown/typing_style.dart';
import '../lines/line_change.dart';
import '../tree/blocks.dart';
import 'editor_contract.dart';
import 'editor_state.dart';
import 'editor_work.dart';

/// How long a toggled item waits before it moves.
const settleDelay = Duration(milliseconds: 700);

/// The editor owner's decision on [input] in [state], with its [work].
Step<EditorState, EditorWork, EditorOutput> editorStep(
  EditorState state,
  EditorWork work,
  EditorInput input,
) {
  final step = _Step(state, work)..handle(input);
  return (state: step.state, work: step.work, outputs: step.outputs);
}

/// One input's handling: the state as it changes and what it leads to.
final class _Step {
  _Step(this.state, this.work);

  EditorState state;
  EditorWork work;
  final outputs = <EditorOutput>[];

  ShownDocument get document => state.document;

  void handle(EditorInput input) {
    if (input case ShownInput(:final revision)
        when revision != state.revision) {
      assert(false, 'an input on what no longer shows');
      return;
    }
    switch (input) {
      case Pressed(:final key) when _editsVisually:
        _pressed(key);
      case Typed(:final text) when _editsVisually:
        _typed(text);
      case Run(command: Toggle()):
        assert(false, 'a box tap is a ToggleItem');
      case Run(command: final MoveToEnd command) when _editsVisually:
        // "Now" moves the toggles still waiting too.
        _settle();
        _run(command);
      case Run(:final command) when _editsVisually:
        _run(command);
      case CaretMoved(:final selection) when state.mode == EditMode.visual:
        _caretMoved(selection);
      case ToggleItem(:final item) when _editsVisually:
        _toggle(item);
      case EditLines(:final change) when state.mode == EditMode.markdown:
        _changeLines(change);
      case EditRaw(:final text, :final base, :final extent):
        _editRaw(text, base, extent);
      case RawCaretMoved(:final base, :final extent):
        if (state.raw case final raw?) {
          _set(
            state.copyWith(
              raw: RawRegion(raw.first, raw.last, base: base, extent: extent),
            ),
          );
        }
      case DragStarted(:final item):
        _setHolds(
          Holds(
            items: {...work.holds.items}..remove(item),
            timer: work.holds.timer,
          ),
        );
      case SetMode(:final mode):
        _settle();
        _set(state.copyWith(mode: mode, raw: null));
      case SetCheckedItems(:final checkedItems):
        // Choosing never moves an item.
        state = state.copyWith(checkedItems: checkedItems);
        _setHolds(const Holds());
      case SetCollapsed(:final list, :final collapsed):
        _setCollapsed(list, collapsed: collapsed);
      case UndoRemoval(:final id):
        _undo(id);
      case SettleTimerFired(:final id) when id == work.holds.timer:
        work = work.copyWith(holds: Holds(items: work.holds.items));
        if (!_caretInHeldItem) _settle();
      case FromFile(
            message: Replaced(:final text, :final version, :final ackRev),
          )
          when ackRev == work.rev:
        _takeText(text, version);
      case FromFile(message: Picked(:final text, :final version, :final rev)):
        work = work.copyWith(rev: rev, picks: work.picks + 1);
        _takeText(text, version);
      case SecureEditor(:final reason):
        _settle();
        outputs.add(ToFile(Secure(reason)));
      case _:
        break;
    }
  }

  /// Whether Visual edit takes edits: shown, with no raw region open.
  bool get _editsVisually => state.mode == EditMode.visual && state.raw == null;

  // Visual edit.

  void _pressed(EditKey key) {
    switch (keyAction(document, state.selection, key)) {
      case RunCommand(:final command):
        _run(command);
      case SelectBlock(:final block):
        _set(state.copyWith(selection: BlockSelection(block)));
      case OpenRaw(:final block, :final atEnd):
        _openRaw(block, atEnd: atEnd);
      case ToggleTypingStyle(:final format):
        final caret = (state.selection as TextSelection).extent;
        final style = state.typingStyle ?? typingStyleAt(document, caret);
        _set(
          state.copyWith(
            typingStyle: style.withFormat(format, on: !style.has(format)),
          ),
        );
      case OpenLinkDialog():
        if (state.selection case final TextSelection range) {
          outputs.add(AskLink(range));
        }
      case Consumed():
        break;
    }
  }

  void _typed(String text) {
    // Typing elsewhere settles the toggles.
    if (!_caretInHeldItem) _settle();
    if (state.selection case final TextSelection range) {
      final at = range.extent;
      final style = state.typingStyle ?? typingStyleAt(document, at);
      _run(switch (range) {
        _ when range.isCaret => InsertText(at, text, style),
        _ when range.base.slot == range.extent.slot => ReplaceText(range, text),
        _ => Paste(range, plainLines(text, style)),
      });
    }
  }

  void _caretMoved(Selection selection) {
    _set(state.copyWith(selection: selection, typingStyle: null, raw: null));
    if (work.holds.timer == null && !_caretInHeldItem) _settle();
  }

  /// [command] run on the document; a text change reaches the file owner.
  void _run(Command command) {
    final before = state;
    final edited = run(document, command);
    _set(
      state.copyWith(
        document: _withView(edited.document),
        selection: edited.selection,
      ),
    );
    final text = document.tree.text;
    if (text == before.document.tree.text) return;
    _textChanged(text);
    if (_removes(command, before.document, document)) {
      final id = work.nextId;
      work = work.copyWith(
        nextId: id + 1,
        undo: (
          id: id,
          before: before.document,
          selection: before.selection,
          rev: work.rev,
        ),
      );
      outputs.add(ItemsRemoved(id));
    }
  }

  void _textChanged(String text) {
    work = work.copyWith(rev: work.rev + 1);
    outputs.add(
      ToFile(
        Edited(text, rev: work.rev, lineage: work.lineage, picks: work.picks),
      ),
    );
  }

  /// Whether [command] removed what an undo is offered for: items by the
  /// delete button or the menu, a block without text, code, or more than
  /// one leaf. An emptied code block goes like an emptied paragraph.
  bool _removes(Command command, ShownDocument before, ShownDocument after) {
    if (command is DeleteItem || command is ClearChecked) return true;
    final kept = {for (final leaf in after.tree.root.leaves) leaf.id};
    final removed = before.tree.root.leaves.where(
      (leaf) => !kept.contains(leaf.id),
    );
    return removed.length > 1 ||
        removed.any(
          (leaf) => switch (leaf) {
            TextLeaf() => false,
            CodeBlock(:final code) => code.isNotEmpty,
            _ => true,
          },
        );
  }

  void _undo(int id) {
    final undo = work.undo;
    if (undo == null || undo.id != id || undo.rev != work.rev) {
      outputs.add(UndoRefused(id));
      return;
    }
    _set(
      state.copyWith(
        document: _withView(document.reverted(undo.before)),
        selection: undo.selection,
      ),
    );
    work = work.copyWith(undo: null);
    _textChanged(document.tree.text);
  }

  // Checked items.

  void _toggle(BlockId item) {
    final checked = (document.tree.blockOf(item) as ItemBlock?)?.checked;
    _run(Toggle(item, state.selection));
    if (state.checkedItems == CheckedItems.inPlace || checked == null) return;
    final items = {...work.holds.items};
    // Toggled back: nothing waits.
    if (items.remove(item) == null) items[item] = checked;
    final timer = work.nextId;
    work = work.copyWith(nextId: timer + 1);
    _setHolds(Holds(items: items, timer: timer));
    outputs.add(StartSettleTimer(timer, settleDelay));
  }

  /// The held toggles take effect: with "Move to end", the items still
  /// checked move.
  void _settle() {
    if (work.holds.isEmpty) return;
    final moved = [
      for (final MapEntry(key: id, value: was) in work.holds.items.entries)
        if (_checked(id) case final now? when now != was && now) id,
    ];
    _setHolds(const Holds());
    if (state.checkedItems == CheckedItems.moveToEnd && moved.isNotEmpty) {
      _run(MoveToEnd(state.selection, items: moved));
    }
  }

  bool? _checked(BlockId item) =>
      (document.tree.blockOf(item) as ItemBlock?)?.checked;

  bool get _caretInHeldItem => switch (state.selection) {
    TextSelection(:final extent) => _inHeldItem(extent.slot),
    BlockSelection() => false,
  };

  bool _inHeldItem(Slot slot) => switch (document.rowOf(slot)) {
    final row? => document.rows[row].path.any(
      (block) => work.holds.items.containsKey(block.id),
    ),
    null => false,
  };

  void _setHolds(Holds holds) {
    work = work.copyWith(holds: holds);
    _set(state.copyWith(document: _withView(document)));
  }

  void _setCollapsed(BlockId list, {required bool collapsed}) {
    final done = document.done;
    if (done == null) return;
    _set(
      state.copyWith(
        document: document.withDone(
          DoneSections(
            held: done.held,
            collapsed: collapsed
                ? {...done.collapsed, list}
                : done.collapsed.difference({list}),
          ),
        ),
      ),
    );
  }

  /// [document] showing checked items as the view state says.
  ShownDocument _withView(ShownDocument document) =>
      switch (state.checkedItems) {
        CheckedItems.doneSection => document.withDone(
          DoneSections(
            held: work.holds.items.keys.toSet(),
            collapsed: document.done?.collapsed ?? const {},
          ),
        ),
        CheckedItems.inPlace ||
        CheckedItems.moveToEnd => document.withDone(null),
      };

  // Raw regions and Markdown edit.

  void _openRaw(BlockId block, {required bool atEnd}) {
    final leaf = document.tree.blockOf(block)! as LeafBlock;
    final text = leaf.lines.map((line) => line.text).join('\n');
    final caret = atEnd ? text.length : 0;
    _set(
      state.copyWith(
        raw: RawRegion(
          leaf.lines.first.id,
          leaf.lines.last.id,
          base: caret,
          extent: caret,
        ),
      ),
    );
  }

  void _editRaw(String text, int base, int extent) {
    final raw = state.raw;
    if (raw == null) return;
    final start = document.tree.indexOf(raw.first);
    final lines = text.split('\n');
    // The region's first and last lines keep their ids; a last line only
    // where the region had one of its own.
    final last = lines.length > 1 && raw.last != raw.first ? raw.last : null;
    _changeTree(
      LineChange(start, document.tree.indexOf(raw.last) + 1, [
        for (final (index, line) in lines.indexed)
          (
            id: switch (index) {
              0 => raw.first,
              _ when index == lines.length - 1 => last,
              _ => null,
            },
            text: line,
          ),
      ]),
    );
    _set(
      state.copyWith(
        raw: RawRegion(
          raw.first,
          document.tree.lines[start + lines.length - 1].id,
          base: base,
          extent: extent,
        ),
      ),
    );
  }

  void _changeLines(LineChange change) => _changeTree(change);

  void _changeTree(LineChange change) {
    final changed = ShownDocument(document.tree.changed(change));
    _set(
      state.copyWith(
        document: _withView(changed),
        selection: _kept(state.selection, document, changed),
      ),
    );
    _textChanged(document.tree.text);
  }

  // Changes from the file owner.

  /// [text], descending from [version], shown instead.
  void _takeText(String text, Version? version) {
    final taken = ShownDocument(document.tree.withText(text));
    final holds = {
      for (final MapEntry(key: id, value: was) in work.holds.items.entries)
        // Gone or changed there: nothing waits.
        if (_checkedIn(taken, id) case final now? when now != was) id: was,
    };
    work = work.copyWith(
      holds: Holds(items: holds, timer: work.holds.timer),
      lineage: version,
      undo: null,
    );
    state = state.copyWith(
      typingStyle: null,
      raw: switch (state.raw) {
        final raw?
            when taken.tree.lineOf(raw.first) != null &&
                taken.tree.lineOf(raw.last) != null =>
          raw,
        _ => null,
      },
    );
    _set(
      state.copyWith(
        document: _withView(taken),
        selection: _kept(state.selection, document, taken),
      ),
    );
  }

  bool? _checkedIn(ShownDocument document, BlockId item) =>
      (document.tree.blockOf(item) as ItemBlock?)?.checked;

  // State.

  void _set(EditorState next) =>
      state = next.copyWith(revision: state.revision + 1);
}

/// [selection] as it shows in [to], once [from] became it: a place
/// whose text place still shows stays, clamped to its text; one in a
/// leaf read anew goes to the nearest leaf at or before it that kept a
/// line, same offset clamped; else the caret goes to the first text.
Selection _kept(Selection selection, ShownDocument from, ShownDocument to) =>
    switch (selection) {
      TextSelection(:final base, :final extent) => switch ((
        _keptPlace(base, from, to),
        _keptPlace(extent, from, to),
      )) {
        (final base?, final extent?) => TextSelection(base, extent),
        _ => to.firstCaret,
      },
      BlockSelection(:final block) when to.blockRowOf(block) != null =>
        selection,
      BlockSelection() => to.firstCaret,
    };

Place? _keptPlace(Place place, ShownDocument from, ShownDocument to) {
  Place clamped(Slot slot) =>
      Place(slot, place.offset.clamp(0, to.textOf(slot).length));
  if (to.rowOf(place.slot) != null) return clamped(place.slot);
  final leaf = switch (place.slot) {
    LeafSlot(:final leaf) => from.tree.blockOf(leaf),
    _ => null,
  };
  if (leaf is! LeafBlock) return null;
  final last = from.tree.indexOf(leaf.lines.last.id);
  return from.tree.lines
      .take(last + 1)
      .toList()
      .reversed
      .map((line) => to.tree.leafOf(line.id))
      .nonNulls
      .map((leaf) => LeafSlot(leaf.id))
      .where((slot) => to.rowOf(slot) != null)
      .map(clamped)
      .firstOrNull;
}

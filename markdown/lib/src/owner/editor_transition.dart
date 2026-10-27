import 'package:truce_core/truce_core.dart'
    show Edited, Picked, Replaced, SaveNow, Secure, SecureReason, Step;

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/origin.dart';
import '../edit/change.dart' show startOf;
import '../edit/clipboard_lines.dart';
import '../edit/commands/command.dart';
import '../edit/commands/text_commands.dart' show ordered;
import '../edit/keys/key_map.dart';
import '../edit/selection.dart';
import '../edit/text_places.dart' show textAt;
import '../edit/typing_style.dart';
import '../print/printer.dart';
import '../view/rows.dart';
import '../visible/formatting.dart';
import 'editor_contract.dart';
import 'editor_work.dart';
import 'history/snapshot.dart';
import 'history/text_change.dart';
import 'history/typing.dart';
import 'raw_closed.dart';
import 'reload.dart';
import 'save_clock.dart';

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

  /// What the input's step did, if it is offered for undo right away.
  OfferedUndo? offered;

  void handle(EditorInput input) {
    // An input on what no longer shows (e.g. a box tap whose wait ended
    // after a change elsewhere) is dropped.
    if (input case ShownInput(:final revision)
        when revision != state.revision) {
      return;
    }
    final (before, origin, rev) = (state, work.origin, work.rev);
    _handle(input);
    switch (input) {
      case Undo() || Redo():
        break;
      case ShownInput() when work.rev != rev:
        _record(input, before, origin);
        if (offered case final what?) {
          outputs.add(UndoOffered(work.history.latestId!, what));
        }
      case CaretMoved() || RawCaretMoved():
        // Typing after a caret move starts a new step.
        work = work.copyWith(history: work.history.runEnded());
      case _:
        break;
    }
    _settleFlags();
  }

  void _handle(EditorInput input) {
    switch ((input, state.content)) {
      case (Undo(), _):
        _undo();
      case (Redo(), _):
        _redo();
      case (ReplaceAll(:final text), _):
        _replaceAll(text);
      case (final ShownInput input, final FormattedContent shown)
          when state.mode == EditMode.visual:
        _visual(input, shown);
      // Read takes its menu's commands on all checked items; the text is
      // sent at once, as Read shows the text kept.
      case (
            Run(command: final command && (MoveToEnd() || ClearChecked())),
            FormattedContent(),
          )
          when state.mode == EditMode.read:
        _run(command);
        _send();
      case (EditText(:final text), MarkdownContent(text: final old))
          when text != old:
        _show(MarkdownContent(text));
        _textChanged();
      case (SetMode(:final mode), _):
        _setMode(mode);
      case (SetCheckedItems(:final checkedItems), _):
        _setCheckedItems(checkedItems);
      case (
        SetCollapsed(:final list, :final collapsed),
        FormattedContent(view: ViewRows(:final doc, done: final done?)),
      ):
        _show(
          _formatted(
            view: ViewRows(
              doc,
              done: done.withCollapsed(list, collapsed: collapsed),
            ),
          ),
        );
      case (UndoStep(:final id), _):
        _undoStep(id);
      case (SaveTimerFired(:final id), _):
        _tick(work.clock.fired(id));
      case (
            FromFile(
              message: Replaced(:final text, :final version, :final ackRev),
            ),
            _,
          )
          when ackRev == work.rev:
        work = work.copyWith(
          lineage: version,
          // Before the first edit, it still starts where the document
          // opened (e.g. a newer copy of an own save shows).
          history: work.history.nextId == 0
              ? work.history
              : work.history.cleared(HistoryStart.changedElsewhere),
        );
        _reload(text);
      case (
        FromFile(message: Picked(:final text, :final version, :final rev)),
        _,
      ):
        work = work.copyWith(
          lineage: version,
          rev: rev,
          sentRev: rev,
          picks: work.picks + 1,
          history: work.history.cleared(HistoryStart.replacedHere),
        );
        _reload(text);
      case (SecureEditor(:final reason), _):
        _secure(reason);
      case _:
        break;
    }
  }

  // Visual edit.

  void _visual(ShownInput input, FormattedContent shown) {
    switch ((input, shown.raw)) {
      case (EditRaw(:final text, :final base, :final extent), final raw?):
        _show(
          _formatted(
            raw: RawRegion(raw.block, text, base: base, extent: extent),
          ),
        );
        if (text != raw.text) _textChanged();
      case (RawCaretMoved(:final base, :final extent), final raw?):
        _show(
          _formatted(
            raw: RawRegion(raw.block, raw.text, base: base, extent: extent),
          ),
        );
      case (CaretMoved(:final selection), _):
        _show(_closedRaw(selection));
      case (_, _?):
        // Any other input closes the raw block first.
        final closed = _closedRaw(shown.selection);
        _show(closed);
        _visual(input, closed);
      case (Pressed(:final key), null):
        _pressed(shown, key);
      case (Typed(:final text, :final over), null):
        _typed(shown, text, over);
      case (Run(command: Toggle()), null):
        assert(false, 'a box tap is a ToggleItem');
      case (Run(command: DeleteRange(:final range)), null):
        _deleted(shown, range);
      case (Run(command: AddItem(:final list, at: AddAt.last)), null)
          when state.checkedItems == CheckedItems.moveToEnd:
        // Checked items stay at the end.
        _run(AddItem(list, at: AddAt.afterOpen));
      case (Run(:final command), null):
        _run(command);
      case (ToggleItems(:final items), null):
        _toggle(items);
      case (OpenRawBlock(:final block, :final atEnd), null):
        _openRaw(shown, block, atEnd: atEnd);
      case _:
        break;
    }
  }

  void _pressed(FormattedContent shown, EditKey key) {
    switch (keyAction(shown.view, shown.selection, key)) {
      case RunCommand(:final command):
        _run(command);
      case SelectBlock(:final block):
        _show(
          FormattedContent(view: shown.view, selection: BlockSelection(block)),
        );
      case OpenRaw(:final block, :final atEnd):
        _openRaw(shown, block, atEnd: atEnd);
      case ToggleTypingStyle(:final format):
        final caret = (shown.selection as TextSelection).extent;
        final style = shown.typingStyle ?? typingStyleAt(shown.view.doc, caret);
        _show(
          _formatted(
            typingStyle: style.withFormat(format, on: !style.has(format)),
          ),
        );
      case OpenLinkDialog():
        if (shown.selection case final TextSelection range) {
          outputs.add(AskLink(range));
        }
      case Consumed():
        break;
    }
  }

  /// [text] typed over [range]: the typing style holds only at the
  /// shown caret.
  void _typed(FormattedContent shown, String text, TextSelection range) {
    final at = range.extent;
    final style =
        (range == shown.selection ? shown.typingStyle : null) ??
        typingStyleAt(shown.view.doc, at);
    final lines = plainLines(text, style);
    _run(switch (range) {
      _ when lines.length > 1 => Paste(range, lines),
      _ when range.isCaret => InsertText(at, text, style),
      _ when range.base.leaf == range.extent.leaf => ReplaceText(range, text),
      _ => Paste(range, lines),
    });
  }

  /// [range] deleted; typing right there goes on in the formatting of
  /// the first character deleted, as typing over a selection does.
  void _deleted(FormattedContent shown, TextSelection range) {
    final (start, end) = ordered(shown.view, range);
    _run(DeleteRange(range));
    if (start.leaf != end.leaf || start.offset == end.offset) return;
    final deleted = textAt(
      shown.view.doc,
      start.leaf,
    ).formattingAt(start.offset);
    _show(_formatted(typingStyle: deleted));
  }

  /// [command] run on what shows; a changed document is a text change.
  void _run(Command command) {
    final shown = state.content as FormattedContent;
    final before = shown.view.doc;
    final edited = run(shown.view, command);
    _show(
      FormattedContent(
        view: ViewRows(edited.doc, done: shown.view.done),
        selection: edited.selection,
      ),
    );
    if (identical(edited.doc, before)) return;
    _textChanged();
    if (_removes(command, before, edited.doc)) offered = OfferedUndo.removal;
  }

  /// Whether [command] removed what an undo is offered for: items by the
  /// delete button or the menu, a block without text, code, or more than
  /// one leaf. An emptied code block goes like an emptied paragraph.
  bool _removes(Command command, DocTree before, DocTree after) {
    if (command is DeleteItem || command is ClearChecked) return true;
    final removed = leavesIn(before.root)
        .where((leaf) => after.nodeOf(leaf.id) == null)
        .toList();
    return removed.length > 1 ||
        removed.any(
          (leaf) => switch (leaf) {
            TextNode() => false,
            CodeNode(:final code) => code.isNotEmpty,
            _ => true,
          },
        );
  }

  // Undo and redo.

  /// The text change [input] made from [before], read from [origin], as
  /// an undo step, or as part of the latest one where it goes on typing.
  void _record(ShownInput input, EditorState before, Origin origin) {
    final typing = typingOf(input, before, state);
    final history = work.history;
    work = work.copyWith(
      history:
          history.continued(typing) ??
          history.recorded(snapshotOf(before.content, origin), typing),
    );
  }

  void _undo() {
    final history = work.history;
    switch (history.undone(_snapshot())) {
      case (history: final next, :final back):
        work = work.copyWith(history: next);
        _restore(back);
        if (!next.canUndo) outputs.add(HistoryEnd(next.start));
      case null:
        outputs.add(HistoryEnd(history.start));
    }
  }

  void _redo() {
    if (work.history.redone(_snapshot()) case (
      history: final next,
      :final back,
    )) {
      work = work.copyWith(history: next);
      _restore(back);
    }
  }

  /// Undoes step [id] if it is the latest.
  void _undoStep(int id) {
    if (work.history.latestId == id) {
      _undo();
    } else {
      outputs.add(UndoRefused(id));
    }
  }

  /// What shows now, to come back to.
  Snapshot _snapshot() => snapshotOf(state.content, work.origin);

  /// [back] shows again, as a text change.
  void _restore(Snapshot back) {
    switch ((back, state.content)) {
      case (_, MarkdownContent(text: final now)):
        if (back case TreeSnapshot(
          :final doc,
          :final selection,
          :final printed,
        )) {
          work = work.copyWith(
            left: (view: ViewRows(doc), selection: selection, printed: printed),
          );
        }
        final change = textChange(now, back.text);
        _show(
          MarkdownContent(back.text, caret: change.start + change.added.length),
        );
      case (
        TreeSnapshot(:final doc, :final origin, :final selection),
        FormattedContent(:final view),
      ):
        work = work.copyWith(origin: origin);
        _show(
          FormattedContent(
            view: _rows(doc, view.done, state.checkedItems),
            selection: selection,
          ),
        );
      case (TextSnapshot(:final text), FormattedContent()):
        _reload(text);
    }
    _changedByHistory();
  }

  /// The document reads [text] instead, from its start.
  void _replaceAll(String text) {
    if (state.mode == EditMode.markdown) {
      _show(MarkdownContent(text, caret: 0));
    } else {
      final next = loaded(text);
      work = work.copyWith(origin: next.origin);
      _show(_fresh(next.doc));
    }
    offered = OfferedUndo.restore;
    _changedByHistory();
  }

  /// A text change not typed: saved as typing is; Read shows the text
  /// kept, so it is sent at once.
  void _changedByHistory() {
    _textChanged();
    if (state.mode == EditMode.read) _send();
  }

  /// [items]' boxes toggled in order; with "Move to end", the checked
  /// ones move together.
  void _toggle(List<NodeId> items) {
    for (final item in items) {
      _run(Toggle(item, (state.content as FormattedContent).selection));
    }
    if (state.checkedItems != CheckedItems.moveToEnd) return;
    final after = state.content as FormattedContent;
    final checked = [
      for (final item in items)
        if (after.view.doc.nodeOf(item) case ItemNode(checked: true)) item,
    ];
    if (checked.isNotEmpty) {
      _run(MoveToEnd(after.selection, items: checked));
    }
  }

  // Raw blocks.

  void _openRaw(FormattedContent shown, NodeId block, {required bool atEnd}) {
    if (shown.view.doc.nodeOf(block) case RawLeaf(:final raw)) {
      final caret = atEnd ? raw.length : 0;
      _show(
        _formatted(
          raw: RawRegion(block, raw, base: caret, extent: caret),
        ),
      );
    }
  }

  /// What shows once the open raw block, if one is, takes what was typed
  /// in it (which the text sent holds already), [selection] where it
  /// stays.
  FormattedContent _closedRaw(Selection selection) {
    final shown = state.content as FormattedContent;
    final closed = rawClosed(shown, selection);
    return FormattedContent(
      view: ViewRows(closed.doc, done: shown.view.done),
      selection: closed.selection,
    );
  }

  // View state.

  void _setMode(EditMode mode) {
    switch ((state.content, mode)) {
      case (FormattedContent(:final view, :final selection), EditMode.markdown):
        final printed = _printed();
        work = work.copyWith(
          left: (view: view, selection: selection, printed: printed),
        );
        _show(MarkdownContent(printed.text), mode: mode);
      case (MarkdownContent(:final text), EditMode.visual || EditMode.read):
        _show(state.content, mode: mode);
        _reload(text);
        work = work.copyWith(left: null);
        if (mode == EditMode.read) _send();
      case (FormattedContent(:final selection), _):
        _show(_closedRaw(selection), mode: mode);
        // Read shows the text as sent.
        if (mode == EditMode.read) _send();
      case (MarkdownContent(), _):
        break;
    }
  }

  /// Checked items show as [checkedItems] says; nothing moves.
  void _setCheckedItems(CheckedItems checkedItems) {
    if (state.content case FormattedContent(:final selection, :final view)) {
      final closed = _closedRaw(selection);
      state = _state(
        content: FormattedContent(
          view: _rows(closed.view.doc, view.done, checkedItems),
          selection: closed.selection,
        ),
        checkedItems: checkedItems,
      );
    } else {
      state = _state(checkedItems: checkedItems);
    }
  }

  // Saving.

  /// A text change: its rev, and the save clock runs.
  void _textChanged() {
    work = work.copyWith(rev: work.rev + 1);
    _tick(work.clock.typed());
  }

  void _tick(Tick tick) {
    work = work.copyWith(clock: tick.clock);
    outputs.addAll([
      for (final (:timer, :id) in tick.started) StartSaveTimer(id, timer.delay),
    ]);
    switch (tick.save) {
      case Save.draft:
        _send();
      case Save.folder:
        _send();
        outputs.add(const ToFile(SaveNow()));
      case null:
        break;
    }
    _settleFlags();
  }

  /// The text, printed, to the file owner, unless it has it.
  void _send() {
    if (work.sentRev == work.rev) return;
    outputs.add(
      ToFile(
        Edited(
          _printed().text,
          rev: work.rev,
          lineage: work.lineage,
          picks: work.picks,
        ),
      ),
    );
    work = work.copyWith(sentRev: work.rev);
  }

  void _secure(SecureReason reason) {
    _send();
    work = work.copyWith(clock: work.clock.left);
    outputs.add(ToFile(Secure(reason)));
    _settleFlags();
  }

  /// What the file says once the text is sent: the document printed,
  /// with the open raw block as typed.
  PrintedMarkdown _printed() => switch (state.content) {
    FormattedContent(:final selection) => printMarkdown(
      _closedRaw(selection).view.doc,
      work.origin,
    ),
    MarkdownContent(:final text) => (text: text, lines: const {}),
  };

  // Changes from the file owner.

  /// [text] shows instead, read anew: the selection and collapsed Done
  /// sections follow their lines, and an open raw block whose text the
  /// change kept stays open.
  void _reload(String text) {
    if (state.mode == EditMode.markdown) return _show(MarkdownContent(text));
    final next = loaded(text);
    final content = switch (state.content) {
      FormattedContent(:final view, :final selection, :final raw) => _mapped(
        (view: view, selection: selection, printed: _printed()),
        raw,
        next,
      ),
      MarkdownContent() => switch (work.left) {
        final left? => _mapped(left, null, next),
        null => _fresh(next.doc),
      },
    };
    work = work.copyWith(origin: next.origin);
    _show(content);
  }

  /// What showed [before], with [raw] open, as it falls in [next].
  FormattedContent _mapped(Left before, RawRegion? raw, Loaded next) {
    final map = ReloadMap(before.printed, next);
    final done = switch (before.view.done) {
      final done? => DoneSections(
        collapsed: map.lists(done.collapsed, before.view.doc),
      ),
      null => null,
    };
    final view = _rows(next.doc, done, state.checkedItems);
    return FormattedContent(
      view: view,
      selection: map.selection(before.selection, view),
      raw: switch (raw) {
        final raw? => _reopened(raw, map.leafOf(raw.block, view), view),
        null => null,
      },
    );
  }

  /// [doc] shown from its start.
  FormattedContent _fresh(DocTree doc) {
    final view = _rows(doc, null, state.checkedItems);
    return FormattedContent(view: view, selection: startOf(view));
  }

  /// [raw] open again on [block] in [view], if that holds its text.
  RawRegion? _reopened(RawRegion raw, NodeId? block, ViewRows view) =>
      switch (block == null ? null : view.doc.nodeOf(block)) {
        RawLeaf(raw: final now, :final id) when now == raw.text => RawRegion(
          id,
          raw.text,
          base: raw.base,
          extent: raw.extent,
        ),
        _ => null,
      };

  // State.

  /// [doc] in rows with checked items as [checkedItems] says, Done
  /// sections collapsed as [done] has them.
  ViewRows _rows(DocTree doc, DoneSections? done, CheckedItems checkedItems) =>
      ViewRows(
        doc,
        done: checkedItems == CheckedItems.doneSection
            ? done ?? DoneSections()
            : null,
      );

  /// What shows now with [view], [typingStyle] or [raw] changed.
  FormattedContent _formatted({
    ViewRows? view,
    Formatting? typingStyle,
    RawRegion? raw,
  }) {
    final shown = state.content as FormattedContent;
    return FormattedContent(
      view: view ?? shown.view,
      selection: shown.selection,
      typingStyle: typingStyle ?? shown.typingStyle,
      raw: raw ?? shown.raw,
    );
  }

  /// [content] shows, in [mode] if given.
  void _show(EditorContent content, {EditMode? mode}) =>
      state = _state(content: content, mode: mode);

  /// The state with what is given changed: what shows changed, so its
  /// revision moves on.
  EditorState _state({
    EditorContent? content,
    EditMode? mode,
    CheckedItems? checkedItems,
  }) => EditorState(
    content: content ?? state.content,
    mode: mode ?? state.mode,
    checkedItems: checkedItems ?? state.checkedItems,
    revision: state.revision + 1,
    unsent: work.sentRev != work.rev,
    canUndo: work.history.canUndo,
    canRedo: work.history.canRedo,
  );

  /// The state telling whether edits are only in memory and what undo
  /// and redo can do; what shows is the same.
  void _settleFlags() {
    final (unsent, canUndo, canRedo) = (
      work.sentRev != work.rev,
      work.history.canUndo,
      work.history.canRedo,
    );
    if ((state.unsent, state.canUndo, state.canRedo) ==
        (unsent, canUndo, canRedo)) {
      return;
    }
    state = EditorState(
      content: state.content,
      mode: state.mode,
      checkedItems: state.checkedItems,
      revision: state.revision,
      unsent: unsent,
      canUndo: canUndo,
      canRedo: canRedo,
    );
  }
}

import 'package:truce_core/truce_core.dart'
    show Edited, Picked, Replaced, SaveNow, Secure, SecureReason, Step;

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../edit/change.dart' show startOf;
import '../edit/clipboard_lines.dart';
import '../edit/commands/command.dart';
import '../edit/keys/key_map.dart';
import '../edit/selection.dart';
import '../edit/typing_style.dart';
import '../print/printer.dart';
import '../view/rows.dart';
import '../visible/formatting.dart';
import 'editor_contract.dart';
import 'editor_work.dart';
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

  void handle(EditorInput input) {
    if (input case ShownInput(:final revision)
        when revision != state.revision) {
      assert(false, 'an input on what no longer shows');
      return;
    }
    switch ((input, state.content)) {
      case (final ShownInput input, final FormattedContent shown)
          when state.mode == EditMode.visual:
        _visual(input, shown);
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
      case (UndoRemoval(:final id), _):
        _undo(id);
      case (SaveTimerFired(:final id), _):
        _tick(work.clock.fired(id));
      case (
            FromFile(
              message: Replaced(:final text, :final version, :final ackRev),
            ),
            _,
          )
          when ackRev == work.rev:
        work = work.copyWith(lineage: version, undo: null);
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
          undo: null,
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
        _show(
          FormattedContent(view: _closedRaw(selection), selection: selection),
        );
      case (_, _?):
        // Other edits wait until the raw block closes.
        break;
      case (Pressed(:final key), null):
        _pressed(shown, key);
      case (Typed(:final text), null):
        _typed(shown, text);
      case (Run(command: Toggle()), null):
        assert(false, 'a box tap is a ToggleItem');
      case (Run(:final command), null):
        _run(command);
      case (ToggleItem(:final item), null):
        _toggle(item);
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

  void _typed(FormattedContent shown, String text) {
    if (shown.selection case final TextSelection range) {
      final at = range.extent;
      final style = shown.typingStyle ?? typingStyleAt(shown.view.doc, at);
      _run(switch (range) {
        _ when range.isCaret => InsertText(at, text, style),
        _ when range.base.leaf == range.extent.leaf => ReplaceText(range, text),
        _ => Paste(range, plainLines(text, style)),
      });
    }
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
    if (_removes(command, before, edited.doc)) {
      final id = work.nextUndo;
      work = work.copyWith(
        nextUndo: id + 1,
        undo: (
          id: id,
          before: before,
          selection: shown.selection,
          rev: work.rev,
        ),
      );
      outputs.add(ItemsRemoved(id));
    }
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

  void _undo(int id) {
    switch ((work.undo, state.content)) {
      case (final undo?, final FormattedContent shown)
          when undo.id == id && undo.rev == work.rev:
        work = work.copyWith(undo: null);
        _show(
          FormattedContent(
            view: ViewRows(undo.before, done: shown.view.done),
            selection: undo.selection,
          ),
        );
        _textChanged();
      case _:
        outputs.add(UndoRefused(id));
    }
  }

  /// [item]'s box toggled; with "Move to end", once checked, it moves.
  void _toggle(NodeId item) {
    final shown = state.content as FormattedContent;
    _run(Toggle(item, shown.selection));
    if (state.checkedItems != CheckedItems.moveToEnd) return;
    final after = state.content as FormattedContent;
    if (after.view.doc.nodeOf(item) case ItemNode(checked: true)) {
      _run(MoveToEnd(after.selection, items: [item]));
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
  ViewRows _closedRaw(Selection selection) {
    final shown = state.content as FormattedContent;
    return switch (shown.raw) {
      final raw? => ViewRows(
        _closed(shown.view, raw, selection),
        done: shown.view.done,
      ),
      null => shown.view,
    };
  }

  /// [view]'s document with [raw] closed, [selection] where it stays.
  DocTree _closed(ViewRows view, RawRegion raw, Selection selection) =>
      run(view, CloseRaw(raw.block, raw.text, selection)).doc;

  // View state.

  void _setMode(EditMode mode) {
    switch ((state.content, mode)) {
      case (FormattedContent(:final selection), EditMode.markdown):
        final printed = _printed();
        work = work.copyWith(left: (printed: printed, selection: selection));
        _show(MarkdownContent(printed.text), mode: mode);
      case (MarkdownContent(:final text), EditMode.visual || EditMode.read):
        _show(state.content, mode: mode);
        _reload(text);
        work = work.copyWith(left: null);
      case (FormattedContent(:final selection), _):
        _show(
          FormattedContent(view: _closedRaw(selection), selection: selection),
          mode: mode,
        );
      case (MarkdownContent(), _):
        break;
    }
  }

  /// Checked items show as [checkedItems] says; nothing moves.
  void _setCheckedItems(CheckedItems checkedItems) {
    final content = switch (state.content) {
      FormattedContent(:final selection, :final view) => FormattedContent(
        view: _rows(_closedRaw(selection).doc, view.done, checkedItems),
        selection: selection,
      ),
      final content => content,
    };
    state = _state(content: content, checkedItems: checkedItems);
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
    _markUnsent();
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
    _markUnsent();
  }

  /// What the file says once the text is sent: the document printed,
  /// with the open raw block as typed.
  PrintedMarkdown _printed() => switch (state.content) {
    FormattedContent(:final view, :final raw, :final selection) =>
      printMarkdown(switch (raw) {
        final raw? => _closed(view, raw, selection),
        null => view.doc,
      }, work.origin),
    MarkdownContent(:final text) => (text: text, lines: const {}),
  };

  // Changes from the file owner.

  /// [text] shows instead, read anew: the selection follows its lines,
  /// and an open raw block whose text the change kept stays open.
  void _reload(String text) {
    if (state.mode == EditMode.markdown) return _show(MarkdownContent(text));
    final (before, raw, done) = switch (state.content) {
      FormattedContent(:final selection, :final raw, :final view) => (
        (printed: _printed(), selection: selection),
        raw,
        view.done,
      ),
      MarkdownContent() => (work.left, null, null),
    };
    final next = loaded(text);
    final view = _rows(next.doc, done, state.checkedItems);
    Selection mapped(Selection selection) => switch (before) {
      final before? => mappedSelection(selection, before.printed, next, view),
      null => startOf(view),
    };
    final selection = switch (before) {
      final before? => mapped(before.selection),
      null => startOf(view),
    };
    final reopened = switch (raw) {
      final raw? => _reopened(raw, mapped(BlockSelection(raw.block)), view),
      null => null,
    };
    work = work.copyWith(origin: next.origin);
    _show(FormattedContent(view: view, selection: selection, raw: reopened));
  }

  /// [raw] open again on the block [at] in [view], if that holds its text.
  RawRegion? _reopened(RawRegion raw, Selection at, ViewRows view) =>
      switch (at) {
        BlockSelection(:final block) => switch (view.doc.nodeOf(block)) {
          RawLeaf(raw: final now) when now == raw.text => RawRegion(
            block,
            raw.text,
            base: raw.base,
            extent: raw.extent,
          ),
          _ => null,
        },
        TextSelection() => null,
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
  );

  /// The state telling whether edits are only in memory; what shows is
  /// the same.
  void _markUnsent() => state = EditorState(
    content: state.content,
    mode: state.mode,
    checkedItems: state.checkedItems,
    revision: state.revision,
    unsent: work.sentRev != work.rev,
  );
}

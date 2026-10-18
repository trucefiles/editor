import 'dart:async';
import 'dart:ui' show AppExitResponse, BoxWidthStyle;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../checklist/checklist_editor.dart';
import '../../checklist/ui/checklist_undo_hint.dart';
import '../../checklist/ui/checklist_view.dart';
import '../../common/error_text.dart';
import '../../common/moment.dart';
import '../../common/screen_shortcuts.dart';
import '../../common/snack.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../markdown/markdown_view.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../scan/folder_scans_controller.dart';
import '../checked_items.dart';
import '../new_note_session.dart';
import '../note.dart';
import '../note_actions.dart';
import '../note_colors.dart';
import '../note_drafts.dart';
import '../note_edit_session.dart';
import '../note_editor_controller.dart';
import '../note_files.dart';
import '../note_place.dart';
import '../note_settings.dart';
import '../note_settings_controller.dart';
import '../note_staging.dart';
import '../note_title.dart';
import '../note_view.dart';
import '../open_note.dart';
import 'checked_items_dialog.dart';
import 'edit_state_banner.dart';
import 'line_break_formatter.dart';
import 'note_heading.dart';
import 'note_place_chip.dart';
import 'note_view_button.dart';
import 'pin_or_color_sheet.dart';
import 'save_indicator.dart';

/// Editor for one note, as plain text or as a checklist. Saves as the user
/// types; a new note's file is created as the user leaves it or the app is
/// hidden.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen(Note this.note, {super.key}) : place = null;

  /// A new note, to go into [place].
  const NoteEditorScreen.fresh(NotePlace this.place, {super.key}) : note = null;

  /// The note to open; `null` for a new one.
  final Note? note;
  final NotePlace? place;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  // Read up front: dispose() needs them, and ref is unusable by then; a
  // new note gets its session as it is kept on leaving.
  late final FolderScansController _scans;
  late final ProviderContainer _container;
  late final OpenNote _open = switch ((widget.note, widget.place)) {
    (final note?, _) => OpenNote(_sessionOf(note), sessionOf: _sessionOfNew),
    (_, final place?) => OpenNote.fresh(
      NewNoteSession(
        place,
        stagingOf: (folder) => NoteStaging.unpublished(
          _container.read(noteDraftsProvider(folder.id)),
        ),
        create: ref.read(noteActionsProvider).create,
        remove: (note) =>
            _container.read(noteFilesProvider(note.folder)).delete(note),
      ),
      sessionOf: _sessionOfNew,
    ),
    _ => throw StateError('A note or a place is needed.'),
  };
  late final _controller = NoteEditorController(
    _open,
    reachSettled: () =>
        ref.read(folderReachProvider(_open.folder.location).notifier).settled(),
  );
  late final _text = TextEditingController(text: _open.text);
  late final AppLifecycleListener _lifecycle;
  late final _checklist = ChecklistEditor(_open);
  late final NoteSettingsController _settings;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// The note's last view on this device, else its first one.
  late NoteView _view =
      _settingsNow.view ??
      NoteView.first(
        hasItems: _checklist.list.hasItems,
        typing: widget.note == null,
      );

  /// A view picked before the note had a file, to remember once it has.
  bool _viewToSave = false;

  NoteEditSession _sessionOf(Note note, {Moment? writtenAt}) => NoteEditSession(
    note,
    _container.read(noteFilesProvider(note.folder)),
    _container.read(noteDraftsProvider(note.folder.id)),
    writtenAt: writtenAt,
  );

  /// For a note just written: created, moved or renamed.
  NoteEditSession _sessionOfNew(Note note) =>
      _sessionOf(note, writtenAt: Moment.now());

  /// The note's settings on this device; the defaults until it has a file.
  NoteSettings get _settingsNow => switch (_open.note) {
    final note? => _settings.settingsOf(note.key),
    null => NoteSettings.defaults,
  };

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _scans = ref.read(folderScansProvider.notifier);
    _settings = ref.read(noteSettingsProvider.notifier);
    _text.addListener(() => _open.edit(_text.text));
    _open.addListener(_onOpenChanged);
    _lifecycle = AppLifecycleListener(
      onHide: _open.secure,
      onExitRequested: _onExitRequested,
    );
    // The note may have changed since the last scan.
    unawaited(_scans.refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _checklist.dispose();
    _open.removeListener(_onOpenChanged);
    final open = _open;
    unawaited(
      open.secure().whenComplete(() {
        open.dispose();
        unawaited(_scans.refresh());
      }),
    );
    _text.dispose();
    super.dispose();
  }

  /// Shows text the note took from the file (rescan or "load theirs"),
  /// and remembers a view picked before the note had a file.
  void _onOpenChanged() {
    if (_text.text != _open.text) {
      final offset = _text.selection.baseOffset.clamp(0, _open.text.length);
      _text.value = TextEditingValue(
        text: _open.text,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
    if (_viewToSave && _open.note != null) {
      _viewToSave = false;
      _saveView(_view);
    }
    setState(() {});
  }

  /// Leaves once the edits are kept (see [NoteEditorController.keep]);
  /// asks if they can be kept nowhere. While the folder can't be reached,
  /// they stay on this device and go into the file at the next start.
  Future<void> _leave() async {
    if (await _controller.keep() || await _askToDiscard()) _close();
  }

  /// On desktop: quits once the edits are kept, or the user discards them.
  Future<AppExitResponse> _onExitRequested() async {
    if (await _controller.keep() || await _askToDiscard()) {
      return AppExitResponse.exit;
    }
    return AppExitResponse.cancel;
  }

  /// Whether the user drops edits that can be kept nowhere; if so, the
  /// session drops them.
  Future<bool> _askToDiscard() async {
    if (!mounted) return false;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Your edits can't be saved"),
        content: const Text(
          'Neither the note nor a conflict copy could be written. '
          'Stay to copy your text elsewhere, or discard it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
        ],
      ),
    );
    if (discard ?? false) {
      _open.discard();
      return true;
    }
    return false;
  }

  /// Closes the editor if it is still the top screen (the user may have
  /// left it meanwhile).
  void _close() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.pop(context);
    }
  }

  /// [context] is this screen's, below its own messenger. A new note is
  /// just dropped.
  Future<void> _delete(BuildContext context) async {
    if (_open.pending != null) {
      _open.discard();
      return Navigator.pop(context);
    }
    await _open.flush();
    final actions = ref.read(noteActionsProvider);
    final deleted = await actions.delete(_open.note!, _open.text);
    if (!context.mounted) return;
    switch (deleted) {
      case Ok(:final value):
        _offerUndo(actions, value);
        Navigator.pop(context);
      case Err(:final error):
        showSnack(context, error.text);
    }
  }

  /// Runs [action] on the note's file; a new note's file is created
  /// first. [context] is this screen's, below its own messenger.
  Future<void> _withFile(
    BuildContext context,
    FutureOr<void> Function(Note note) action,
  ) async {
    await _open.flush();
    if (!context.mounted) return;
    switch (_open.note) {
      case final note?:
        await action(note);
      case null when _open.state == EditState.saved:
        showSnack(
          context,
          'Write something first: an empty note is not saved.',
        );
      case null:
        // Not created: the banner tells why.
        break;
    }
  }

  /// The hint outlives this screen, so it shows on the app's messenger,
  /// found from above this screen's own.
  void _offerUndo(NoteActions actions, DeletedNote deleted) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showHint(
      'Note deleted',
      actionLabel: 'Undo',
      onAction: () async {
        if (await actions.undoDelete(deleted) case Err(:final error)) {
          messenger.showHint(error.text);
        }
      },
    );
  }

  /// [context] is this screen's, below its own messenger; [settings] are
  /// the note's.
  Widget _menu(BuildContext context, NoteSettings settings) =>
      PopupMenuButton<VoidCallback>(
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          if (_view == NoteView.list) ...[
            PopupMenuItem(value: _clearDone, child: const Text('Clear done')),
            PopupMenuItem(
              value: () => _withFile(
                context,
                (note) => _pickCheckedItems(note, settings.checkedItems),
              ),
              child: Text(
                'Checked items: ${checkedItemsName(settings.checkedItems)}',
              ),
            ),
          ],
          PopupMenuItem(
            value: () => _withFile(
              context,
              (note) => editPinOrColor(context, ref, note),
            ),
            child: const Text('Pin or color'),
          ),
          PopupMenuItem(
            value: () => _delete(context),
            child: const Text('Delete note'),
          ),
        ],
      );

  /// Asks where [note]'s checked items go, on this device.
  Future<void> _pickCheckedItems(Note note, CheckedItems current) async {
    final chosen = await showCheckedItemsDialog(context, current: current);
    if (chosen == null || chosen == current) return;
    // Items checked before follow the new order too: the user chose it.
    if (chosen == CheckedItems.toEnd) _checklist.sortChecked();
    await _settings.edit(
      note.key,
      (settings) => settings.withCheckedItems(chosen),
    );
  }

  void _showView(NoteView view) {
    setState(() => _view = view);
    _saveView(view);
  }

  /// Remembers [view] on this device; for a new note, once it has a file.
  void _saveView(NoteView view) {
    final note = _open.note;
    if (note == null) {
      _viewToSave = true;
      return;
    }
    unawaited(_settings.edit(note.key, (settings) => settings.withView(view)));
  }

  void _clearDone() => showChecklistUndoHint(
    _messenger.currentState!,
    _checklist,
    'Done items cleared',
    _checklist.clearDone(),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(folderScansProvider, (_, next) {
      if (next.value case final scans? when _controller.onScans(scans)) {
        _messenger.currentState?.showHint(
          'Updated with a change from another device or app',
        );
      }
    });
    return PopScope(
      canPop: _open.state == EditState.saved || _isDone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: _scaffold(),
    );
  }

  /// Esc leaves the note, as the back arrow does; Ctrl+1, 2, 3 pick the
  /// views in the view menu's order.
  late final Map<SingleActivator, VoidCallback> _keys = {
    const SingleActivator(LogicalKeyboardKey.escape): () =>
        unawaited(Navigator.maybePop(context)),
    for (final (index, view) in NoteView.values.indexed)
      SingleActivator(_digits[index], control: true): () {
        if (!_isReadOnly && view != _view) _showView(view);
      },
  };

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
  ];

  /// The edits were kept as a conflict copy; nothing more to edit here.
  bool get _isDone => _open.state == EditState.keptAsConflict;

  /// Hints whose action works on this screen (e.g. undoing a checklist
  /// action) show on this screen's own messenger, so they go with it: once
  /// it is closed, there is nothing left to act on.
  Widget _scaffold() => ScaffoldMessenger(
    key: _messenger,
    child: ScreenShortcuts(
      bindings: _keys,
      child: Builder(builder: _content),
    ),
  );

  /// Only rendered: no view to pick (see [_body]).
  bool get _isReadOnly => _isDone || _isUnreachable;

  bool get _isUnreachable =>
      ref.read(folderReachProvider(_open.folder.location)) == Reach.unreachable;

  Widget _content(BuildContext context) {
    // Rebuilds when the folder's reach changes.
    ref.watch(folderReachProvider(_open.folder.location));
    final unreachable = _isUnreachable;
    final readOnly = _isReadOnly;
    final scans = ref.watch(folderScansProvider).value;
    final key = _open.note?.key;
    final mark = key == null
        ? NoteMark.none
        : scans?.markOf(key) ?? NoteMark.none;
    ref.watch(noteSettingsProvider);
    final settings = _settingsNow;
    final tint = noteTint(mark.color, Theme.of(context).colorScheme);
    return Scaffold(
      backgroundColor: tint,
      appBar: AppBar(
        backgroundColor: tint,
        title: ListenableBuilder(
          listenable: _text,
          builder: (context, _) => NoteHeading(
            title: noteTitle(_text.text, _open.path),
            edited: _open.note?.modified,
          ),
        ),
        actions: [
          SaveIndicator(_open.state, onSave: _open.flush),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _scans.refresh,
          ),
          if (!readOnly) ...[
            NoteViewButton(view: _view, onChanged: _showView),
            _menu(context, settings),
          ],
        ],
      ),
      body: Column(
        children: [
          if (key != null)
            if (scans?.conflicts.forNote(key) case final conflict?)
              ConflictBanner(conflict),
          UnreachableBanner(
            _open.folder,
            message: 'Your text is kept on this device.',
          ),
          // Its ways out need the folder.
          if (!unreachable) EditStateBanner(_open, onClose: _leave),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              // A new note can still go to another folder.
              child: NotePlaceChip(
                _open,
                enabled: _open.pending != null || !readOnly,
              ),
            ),
          ),
          Expanded(
            // The views scroll inside, e.g. the text field's own
            // scrollable.
            child: PullToRefresh(
              onRefresh: _scans.refresh,
              child: _body(settings, readOnly: readOnly),
            ),
          ),
        ],
      ),
    );
  }

  /// The note in the chosen view, a list as its [settings] say; rendered
  /// while [readOnly]: once done, as the session takes no more edits, or
  /// while the folder can't be reached.
  Widget _body(NoteSettings settings, {required bool readOnly}) =>
      switch (readOnly ? NoteView.rendered : _view) {
        NoteView.list => ChecklistView(
          _checklist,
          separateDone: settings.checkedItems.shownApart,
          checkedToEnd: settings.checkedItems == CheckedItems.toEnd,
        ),
        NoteView.rendered => MarkdownView(_open.text),
        NoteView.text => TextField(
          controller: _text,
          // A new note is for typing right away.
          autofocus: widget.note == null,
          maxLines: null,
          expands: true,
          keyboardType: TextInputType.multiline,
          inputFormatters: [lineBreakFormatter],
          // The raw source, so monospace: Markdown syntax lines up as
          // in a code editor.
          style: const TextStyle(fontFamily: 'monospace'),
          // Highlights only the selected text, not up to the longest
          // line (Flutter's default outside the web).
          selectionWidthStyle: BoxWidthStyle.tight,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            // Never saved: an empty note gets its name from the first line
            // typed.
            hintText: 'Untitled',
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16),
          ),
          // Pulls down even when the text fits, to refresh.
          scrollPhysics: const AlwaysScrollableScrollPhysics(),
        ),
      };
}

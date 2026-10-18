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
import '../../common/screen_shortcuts.dart';
import '../../common/snack.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../folders/folders_controller.dart';
import '../../folders/ui/folder_badge.dart';
import '../../markdown/markdown_view.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../scan/folder_scans_controller.dart';
import '../checked_items.dart';
import '../note.dart';
import '../note_actions.dart';
import '../note_colors.dart';
import '../note_drafts.dart';
import '../note_edit_session.dart';
import '../note_editor_controller.dart';
import '../note_files.dart';
import '../note_settings.dart';
import '../note_settings_controller.dart';
import '../note_title.dart';
import '../note_view.dart';
import 'checked_items_dialog.dart';
import 'edit_state_banner.dart';
import 'line_break_formatter.dart';
import 'move_failure_text.dart';
import 'note_heading.dart';
import 'note_place_dialog.dart';
import 'note_view_button.dart';
import 'pin_or_color_sheet.dart';
import 'save_indicator.dart';

/// Editor for one note, as plain text or as a checklist. Saves as the user
/// types.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen(this.note, {super.key});

  final Note note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final NoteFiles _files = ref.read(noteFilesProvider(widget.note.folder));
  // Read up front: dispose() needs it, and ref is unusable by then.
  late final FolderScansController _scans;
  late final _session = NoteEditSession(
    widget.note,
    _files,
    ref.read(noteDraftsProvider(widget.note.folder.id)),
  );
  late final _controller = NoteEditorController(
    _session,
    reachSettled: ref
        .read(folderReachProvider(widget.note.folder.location).notifier)
        .settled,
  );
  late final _text = TextEditingController(text: _session.text);
  late final AppLifecycleListener _lifecycle;
  late final _checklist = ChecklistEditor(_session);
  late final NoteSettingsController _settings;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// The note's last view on this device, else its first one.
  late NoteView _view =
      _settings.settingsOf(widget.note.key).view ??
      NoteView.first(hasItems: _checklist.list.hasItems);

  @override
  void initState() {
    super.initState();
    _scans = ref.read(folderScansProvider.notifier);
    _settings = ref.read(noteSettingsProvider.notifier);
    _text.addListener(() => _session.edit(_text.text));
    _session.addListener(_onSessionChanged);
    _lifecycle = AppLifecycleListener(
      onHide: _session.secure,
      onExitRequested: _onExitRequested,
    );
    // The note may have changed since the last scan.
    unawaited(_scans.refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _checklist.dispose();
    _session.removeListener(_onSessionChanged);
    final session = _session;
    unawaited(
      session.secure().whenComplete(() {
        session.dispose();
        unawaited(_scans.refresh());
      }),
    );
    _text.dispose();
    super.dispose();
  }

  /// Shows text the session took from the file (rescan or "load theirs").
  void _onSessionChanged() {
    if (_text.text != _session.text) {
      final offset = _text.selection.baseOffset.clamp(0, _session.text.length);
      _text.value = TextEditingValue(
        text: _session.text,
        selection: TextSelection.collapsed(offset: offset),
      );
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
      _session.discard();
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

  /// [context] is this screen's, below its own messenger.
  Future<void> _delete(BuildContext context) async {
    await _session.flush();
    final actions = ref.read(noteActionsProvider);
    final deleted = await actions.delete(_session.note, _session.text);
    if (!context.mounted) return;
    switch (deleted) {
      case Ok(:final value):
        _offerUndo(actions, value);
        Navigator.pop(context);
      case Err(:final error):
        showSnack(context, error.text);
    }
  }

  /// Asks where to, moves the note there and leaves; [context] is this
  /// screen's, below its own messenger. Only a note saved in its folder
  /// moves, so the move takes every edit along.
  Future<void> _move(BuildContext context) async {
    // The hint outlives this screen, as in [_offerUndo].
    final appMessenger = ScaffoldMessenger.of(this.context);
    await _session.flush();
    if (!context.mounted) return;
    if (_session.state != EditState.saved) {
      return showSnack(context, 'The note must be saved in its folder first.');
    }
    // Change events don't tell about new empty subfolders; a rescan finds
    // them, so the dialog offers them.
    await _scans.refresh();
    if (!context.mounted) return;
    final actions = ref.read(noteActionsProvider);
    final note = _session.note;
    final here = (folder: note.folder, subfolder: note.path.parent);
    final place = await showNotePlaceDialog(
      context,
      title: 'Move note',
      action: 'Move',
      folders: actions.reachableOf(ref.read(foldersProvider).value ?? []),
      initial: here,
      subfoldersOf: actions.subfoldersOf,
    );
    if (place == null || !context.mounted) return;
    if (place.folder.id == here.folder.id &&
        place.subfolder == here.subfolder) {
      return;
    }
    final moved = await actions.move(note, _session.text, place);
    if (!context.mounted) return;
    switch (moved) {
      case Ok(value: final copy):
        appMessenger.showHint(
          'Moved to ${placeName(copy.folder, copy.path.parent)}',
        );
        Navigator.pop(context);
      case Err(:final error):
        showSnack(context, moveFailureText(error));
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
              value: () => _pickCheckedItems(settings.checkedItems),
              child: Text(
                'Checked items: ${checkedItemsName(settings.checkedItems)}',
              ),
            ),
          ],
          PopupMenuItem(
            value: () => editPinOrColor(context, ref, widget.note),
            child: const Text('Pin or color'),
          ),
          PopupMenuItem(
            value: () => _move(context),
            child: const Text('Move note'),
          ),
          PopupMenuItem(
            value: () => _delete(context),
            child: const Text('Delete note'),
          ),
        ],
      );

  /// Asks where this note's checked items go, on this device.
  Future<void> _pickCheckedItems(CheckedItems current) async {
    final chosen = await showCheckedItemsDialog(context, current: current);
    if (chosen == null || chosen == current) return;
    // Items checked before follow the new order too: the user chose it.
    if (chosen == CheckedItems.toEnd) _checklist.sortChecked();
    await _settings.edit(
      widget.note.key,
      (settings) => settings.withCheckedItems(chosen),
    );
  }

  void _showView(NoteView view) {
    setState(() => _view = view);
    unawaited(
      _settings.edit(widget.note.key, (settings) => settings.withView(view)),
    );
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
      canPop: _session.state == EditState.saved || _isDone,
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
  bool get _isDone => _session.state == EditState.keptAsConflict;

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
      ref.read(folderReachProvider(widget.note.folder.location)) ==
      Reach.unreachable;

  Widget _content(BuildContext context) {
    // Rebuilds when the folder's reach changes.
    ref.watch(folderReachProvider(widget.note.folder.location));
    final unreachable = _isUnreachable;
    final readOnly = _isReadOnly;
    final scans = ref.watch(folderScansProvider).value;
    final mark = scans?.markOf(widget.note.key) ?? NoteMark.none;
    ref.watch(noteSettingsProvider);
    final settings = _settings.settingsOf(widget.note.key);
    final tint = noteTint(mark.color, Theme.of(context).colorScheme);
    return Scaffold(
      backgroundColor: tint,
      appBar: AppBar(
        backgroundColor: tint,
        title: ListenableBuilder(
          listenable: _text,
          builder: (context, _) => NoteHeading(
            title: noteTitle(_text.text, widget.note.path),
            folder: widget.note.folder,
            file: widget.note.path,
            edited: _session.note.modified,
          ),
        ),
        actions: [
          SaveIndicator(_session.state, onSave: _session.flush),
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
          if (scans?.conflicts.forNote(widget.note.key) case final conflict?)
            ConflictBanner(conflict),
          UnreachableBanner(
            widget.note.folder,
            message: 'Your text is kept on this device.',
          ),
          // Its ways out need the folder.
          if (!unreachable) EditStateBanner(_session, onClose: _leave),
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
        NoteView.rendered => MarkdownView(_session.text),
        NoteView.text => TextField(
          controller: _text,
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
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16),
          ),
          // Pulls down even when the text fits, to refresh.
          scrollPhysics: const AlwaysScrollableScrollPhysics(),
        ),
      };
}

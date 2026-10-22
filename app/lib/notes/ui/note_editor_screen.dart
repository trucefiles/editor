import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/moment.dart';
import '../../common/screen_shortcuts.dart';
import '../../common/snack.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../editor/add_item_place/add_item_place_controller.dart';
import '../../editor/checked_items.dart';
import '../../editor/note_document_controller.dart';
import '../../editor/note_editor.dart';
import '../../editor/note_mode.dart';
import '../../editor/text_size/note_text_size.dart';
import '../../editor/text_size/note_text_size_controller.dart';
import '../../editor/text_size/ui/note_text_scale.dart';
import '../../editor/text_size/ui/pinch_to_zoom.dart';
import '../../editor/ui/undo_hint.dart';
import '../../markdown/markdown_links.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../scan/folder_scans_controller.dart';
import '../new_note_session.dart';
import '../note.dart';
import '../note_actions.dart';
import '../note_colors.dart';
import '../note_drafts.dart';
import '../note_edit_session.dart';
import '../note_editor_controller.dart';
import '../note_files.dart';
import '../note_images.dart';
import '../note_place.dart';
import '../note_settings.dart';
import '../note_settings_controller.dart';
import '../note_staging.dart';
import '../note_title.dart';
import '../open_note.dart';
import 'checked_items_dialog.dart';
import 'delete_failure_text.dart';
import 'edit_state_banner.dart';
import 'note_heading.dart';
import 'note_mode_button.dart';
import 'note_place_chip.dart';
import 'pin_or_color_sheet.dart';
import 'save_indicator.dart';

/// Editor for one note, in Visual edit, Markdown edit or Read. Saves as
/// the user types; a new note's file is created as the user leaves it or the app is
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
  late final AppLifecycleListener _lifecycle;
  late final NoteSettingsController _settings;
  late final NoteDocumentController _note;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _pull = GlobalKey<PullToRefreshState>();

  /// The note's last mode on this device, else its first one.
  late NoteMode _mode =
      _settingsNow.mode ??
      NoteMode.first(
        hasCheckboxes: MarkdownDocument.parse(_open.text).hasCheckboxes,
        typing: widget.note == null,
      );

  /// A mode picked before the note had a file, to remember once it has.
  bool _modeToSave = false;

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
    _note = NoteDocumentController(
      _open,
      mode: _shownMode,
      checkedItems: _settingsNow.checkedItems,
      addItems: ref.read(addItemPlaceProvider).value ?? AddItemPlace.top,
    );
    _shownLook = _sessionLook;
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
    _note.dispose();
    _open.removeListener(_onOpenChanged);
    final open = _open;
    unawaited(
      open.secure().whenComplete(() {
        open.dispose();
        unawaited(_scans.refresh());
      }),
    );
    super.dispose();
  }

  /// Follows the session: Read once it takes no more edits, and the
  /// mode picked before the note had a file, remembered once it has.
  /// Rebuilds only when what the screen shows of it changes; the editor
  /// and the title follow the text on their own.
  void _onOpenChanged() {
    if (_modeToSave && _open.note != null) {
      _modeToSave = false;
      _saveMode(_mode);
    }
    final look = _sessionLook;
    if (look == _shownLook && _note.mode == _shownMode) return;
    _shownLook = look;
    _showShownMode();
  }

  /// What the screen shows of the session besides its text.
  Object get _sessionLook =>
      (_open.state, _open.note?.key, _open.path, _open.pending != null);

  late Object _shownLook;

  /// The mode the note shows in: Read while it can't be edited.
  NoteMode get _shownMode => _isReadOnly ? NoteMode.read : _mode;

  /// Shows the note in [_shownMode]; the view is built anew for it.
  void _showShownMode() => setState(() => _note.mode = _shownMode);

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
        showSnack(context, deleteFailureText(error));
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
        showSnack(context, "Write something first. An empty note isn't saved.");
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
          if (_note.document.hasCheckboxes) ...[
            PopupMenuItem(
              value: _clearDone,
              child: const Text('Clear checked items'),
            ),
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
    _note.setCheckedItems(chosen, chose: true);
    await _settings.edit(
      note.key,
      (settings) => settings.withCheckedItems(chosen),
    );
  }

  void _showMode(NoteMode mode) {
    _mode = mode;
    _showShownMode();
    _saveMode(mode);
  }

  /// Remembers [mode] on this device; for a new note, once it has a file.
  void _saveMode(NoteMode mode) {
    final note = _open.note;
    if (note == null) {
      _modeToSave = true;
      return;
    }
    unawaited(_settings.edit(note.key, (settings) => settings.withMode(mode)));
  }

  void _clearDone() => _offerUndoOf('Checked items cleared', _note.clearDone());

  /// Hint with an undo for an action on the note's items.
  void _offerUndoOf(String message, EditUndo undo) =>
      showUndoHint(_messenger.currentState!, _note, message, undo);

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(folderReachProvider(_open.folder.location), (_, _) {
        _showShownMode();
      })
      ..listen(noteSettingsProvider, (_, _) {
        _note.setCheckedItems(_settingsNow.checkedItems);
      })
      ..listen(addItemPlaceProvider, (_, next) {
        if (next.value case final place?) _note.addItems = place;
      });
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
  /// modes in the mode menu's order; Ctrl+=, Ctrl+- and Ctrl+0 make notes'
  /// text larger, smaller or its base size again.
  late final Map<SingleActivator, VoidCallback> _keys = {
    const SingleActivator(LogicalKeyboardKey.escape): () =>
        unawaited(Navigator.maybePop(context)),
    for (final (index, mode) in NoteMode.values.indexed)
      SingleActivator(_digits[index], control: true): () {
        if (!_isReadOnly && mode != _mode) _showMode(mode);
      },
    for (final (keys, size) in [
      (_larger, (NoteTextSize size) => size.larger),
      (_smaller, (NoteTextSize size) => size.smaller),
      (_normal, (NoteTextSize _) => NoteTextSize.normal),
    ])
      for (final key in keys)
        SingleActivator(key, control: true): () =>
            unawaited(ref.read(noteTextSizeProvider.notifier).change(size)),
  };

  static const _larger = [
    LogicalKeyboardKey.equal,
    LogicalKeyboardKey.numpadAdd,
  ];
  static const _smaller = [
    LogicalKeyboardKey.minus,
    LogicalKeyboardKey.numpadSubtract,
  ];
  static const _normal = [
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.numpad0,
  ];

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
  ];

  /// The edits were kept as a conflict copy; nothing more to edit here.
  bool get _isDone => _open.state == EditState.keptAsConflict;

  /// Hints whose action works on this screen (e.g. undoing a deleted
  /// item) show on this screen's own messenger, so they go with it: once
  /// it is closed, there is nothing left to act on.
  Widget _scaffold() => ScaffoldMessenger(
    key: _messenger,
    child: ScreenShortcuts(
      bindings: _keys,
      child: Builder(builder: _content),
    ),
  );

  /// Only shown in Read: no mode to pick.
  bool get _isReadOnly => _isDone || _isUnreachable;

  bool get _isUnreachable =>
      ref.read(folderReachProvider(_open.folder.location)) == Reach.unreachable;

  Widget _content(BuildContext context) {
    // Rebuilds when the folder's reach changes.
    ref.watch(folderReachProvider(_open.folder.location));
    final unreachable = _isUnreachable;
    final readOnly = _isReadOnly;
    final scans = ref.watch(folderScansProvider).value;
    final textSize =
        ref.watch(noteTextSizeProvider).value ?? NoteTextSize.normal;
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
          listenable: _open,
          builder: (context, _) => NoteHeading(
            title: noteTitle(_open.text, _open.path),
            edited: _open.note?.modified,
          ),
        ),
        actions: [
          SaveIndicator(
            _open.state,
            hasFile: _open.note != null,
            onSave: _open.flush,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _pull.currentState!.refresh(),
          ),
          if (!readOnly) ...[
            NoteModeButton(mode: _mode, onChanged: _showMode),
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
            // The editor scrolls inside.
            child: PullToRefresh(
              key: _pull,
              onRefresh: _scans.refresh,
              child: PinchToZoom(
                size: textSize,
                onSize: ref.read(noteTextSizeProvider.notifier).set,
                child: NoteTextScale(
                  size: textSize,
                  child: NoteEditorView(
                    _note,
                    key: ValueKey(_note.mode),
                    onRemoved: _offerUndoOf,
                    onLink: (url) => openMarkdownLink(context, ref, url),
                    images: noteImages(
                      _container.read(noteFilesProvider(_open.folder)),
                      folder: _open.folder,
                      note: _open.path,
                    ),
                    // A new note is for typing right away.
                    autofocus: widget.note == null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

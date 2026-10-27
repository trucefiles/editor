import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../../common/error_text.dart';
import '../../common/screen_shortcuts.dart';
import '../../common/snack.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../editor/add_item_place/add_item_place.dart';
import '../../editor/add_item_place/add_item_place_controller.dart';
import '../../editor/document_editor.dart';
import '../../editor/editor_gate.dart';
import '../../editor/first_mode.dart';
import '../../editor/run_command.dart';
import '../../folders/note_folder.dart';
import '../../markdown/markdown_links.dart';
import '../../notes/note.dart';
import '../../notes/note_actions.dart';
import '../../notes/note_colors.dart';
import '../../notes/note_drafts.dart';
import '../../notes/note_files.dart';
import '../../notes/note_images.dart';
import '../../notes/note_place.dart';
import '../../notes/note_settings.dart';
import '../../notes/note_settings_controller.dart';
import '../../notes/note_title.dart';
import '../../notes/ui/checked_items_dialog.dart';
import '../../notes/ui/delete_failure_text.dart';
import '../../notes/ui/edit_mode_button.dart';
import '../../notes/ui/note_heading.dart';
import '../../notes/ui/pin_or_color_sheet.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../scan/folder_scans_controller.dart';
import '../../text_zoom/ui/note_text_zoom.dart';
import '../document_controller.dart';
import '../document_file.dart';
import '../document_session.dart';
import '../file_effects.dart';
import 'document_place_chip.dart';
import 'edit_state_banner.dart';
import 'save_indicator.dart';

/// Editor for one document, in Visual edit, Markdown edit or Read. Saves
/// as the user types; a new document's file is created as the user
/// leaves it or the app is hidden.
class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen(Note this.note, {super.key}) : place = null;

  /// A new document, to go into [place].
  const DocumentScreen.fresh(NotePlace this.place, {super.key}) : note = null;

  /// The note to open; `null` for a new one.
  final Note? note;
  final NotePlace? place;

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  // Read up front: dispose() needs them, and ref is unusable by then.
  late final FolderScansController _scans;
  late final ProviderContainer _container;
  late final NoteSettingsController _settings;
  late final DocumentSession _session;
  late final DocumentController _controller;
  late final AppLifecycleListener _lifecycle;
  late final List<StreamSubscription<Object>> _notices;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _pull = GlobalKey<PullToRefreshState>();

  /// The mode the user picked last; it shows unless the document is read
  /// only.
  late EditMode _mode;

  /// A mode picked before the document had a file, to remember once it
  /// has.
  bool _modeToSave = false;

  EditorGate get _gate => _session.gate;

  /// Where the document is now: it changes when the user moves it, or
  /// picks another place for a new one.
  NoteFolder get _folder => _session.file.folder;

  /// The document's settings on this device; the defaults until it has a
  /// file.
  NoteSettings get _settingsNow => switch (_session.note) {
    final note? => _settings.settingsOf(note.key),
    null => NoteSettings.defaults,
  };

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _scans = ref.read(folderScansProvider.notifier);
    _settings = ref.read(noteSettingsProvider.notifier);
    final note = widget.note;
    final settings = switch (note) {
      final note? => _settings.settingsOf(note.key),
      null => NoteSettings.defaults,
    };
    _mode =
        settings.mode ??
        firstMode(
          hasCheckboxes:
              note != null && DocumentSummary.of(note.file.text).hasCheckboxes,
          typing: note == null,
        );
    final file = switch ((note, widget.place)) {
      (final note?, _) => ExistingFile(note),
      (_, final place?) => NewFile(place),
      _ => throw StateError('A note or a place is needed.'),
    };
    _session = DocumentSession(
      FileEffects(
        file,
        filesOf: (folder) => _container.read(noteFilesProvider(folder)),
        draftsOf: (folder) => _container.read(noteDraftsProvider(folder.id)),
        create: ref.read(noteActionsProvider).create,
      ),
      // Not yet kept as a conflict copy: only an unreachable folder
      // makes it read only.
      mode: _unreachable(file.folder) ? EditMode.read : _mode,
      checkedItems: settings.checkedItems,
    );
    _controller = DocumentController(
      _session,
      reachSettled: () =>
          ref.read(folderReachProvider(_folder.location).notifier).settled(),
    );
    _session.addListener(_onSessionChanged);
    _notices = [
      _session.editorNotices.listen(_onEditorNotice),
      _session.fileNotices.listen(_onFileNotice),
    ];
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(_session.secure(SecureReason.hide)),
      onExitRequested: _onExitRequested,
    );
    // The document may have changed since the last scan.
    unawaited(_scans.refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    for (final notices in _notices) {
      unawaited(notices.cancel());
    }
    _session.removeListener(_onSessionChanged);
    final session = _session;
    // Also after a leave that kept the edits: the screen may also go
    // without one (its route removed), and a second answer is quick.
    unawaited(
      session.secure(SecureReason.close).whenComplete(() {
        session.dispose();
        unawaited(_scans.refresh());
      }),
    );
    super.dispose();
  }

  /// Follows the session: Read once it takes no more edits, and the
  /// mode picked before the document had a file, remembered once it has.
  void _onSessionChanged() {
    if (_modeToSave && _session.note != null) {
      _modeToSave = false;
      _saveMode(_mode);
    }
    _showShownMode();
  }

  /// Shows the document in the mode it shows in: Read while it can't be
  /// edited.
  void _showShownMode() {
    final shown = _isReadOnly ? EditMode.read : _mode;
    if (_gate.state.mode != shown) _gate.send((_) => SetMode(shown));
    if (mounted) setState(() {});
  }

  void _onEditorNotice(EditorOutput notice) {
    final messenger = _messenger.currentState;
    if (messenger == null) return;
    switch (notice) {
      case ItemsRemoved(:final id):
        messenger.showHint(
          'Removed',
          actionLabel: 'Undo',
          onAction: () => _gate.send((_) => UndoRemoval(id)),
        );
      case UndoRefused():
        messenger.showHint("Can't undo, because the note has changed since.");
      case _:
        break;
    }
  }

  void _onFileNotice(FileOutput notice) {
    if (notice is Replaced) {
      _messenger.currentState?.showHint(
        'Updated with a change from another device or app',
      );
    }
  }

  /// Leaves once the edits are kept (see [DocumentController.keep]);
  /// asks if they can be kept nowhere. While the folder can't be reached,
  /// they stay on this device and go into the file at the next start.
  Future<void> _leave() async {
    if (await _controller.keep(SecureReason.close) || await _askToDiscard()) {
      _close();
    }
  }

  /// On desktop: quits once the edits are kept, or the user discards them.
  Future<AppExitResponse> _onExitRequested() async {
    if (await _controller.keep(SecureReason.exit) || await _askToDiscard()) {
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

  /// Whether the screen can close at once: nothing is left to keep.
  bool get _canLeaveNow => switch (_session.status) {
    InStep() || Unwritten() => !_gate.state.unsent,
    KeptAsConflict() || Closed() => true,
    Editing() ||
    ChangedElsewhere() ||
    DeletedElsewhere() ||
    SaveFailed() => false,
  };

  /// [context] is this screen's, below its own messenger. A new document
  /// is just dropped.
  Future<void> _delete(BuildContext context) async {
    if (_session.file is NewFile) {
      _session.discard();
      return Navigator.pop(context);
    }
    await _session.secure(SecureReason.hide);
    final note = _session.note;
    if (!context.mounted || note == null) return;
    final actions = ref.read(noteActionsProvider);
    final deleted = await actions.delete(note, _session.text);
    if (!context.mounted) return;
    switch (deleted) {
      case Ok(:final value):
        _offerUndo(actions, value);
        Navigator.pop(context);
      case Err(:final error):
        showSnack(context, deleteFailureText(error));
    }
  }

  /// Runs [action] on the document's file; a new document's file is
  /// created first. [context] is this screen's, below its own messenger.
  Future<void> _withFile(
    BuildContext context,
    FutureOr<void> Function(Note note) action,
  ) async {
    await _session.secure(SecureReason.hide);
    if (!context.mounted) return;
    switch ((_session.note, _session.status)) {
      case (final note?, _):
        await action(note);
      case (null, Unwritten()):
        showSnack(context, "Write something first. An empty note isn't saved.");
      case (null, _):
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

  /// Whether the document has checklist items. Read when the menu
  /// opens; in Markdown edit it reads the text.
  bool get _hasCheckboxes => switch (_gate.state.content) {
    FormattedContent(:final view) => view.doc.hasCheckboxes,
    MarkdownContent() => DocumentSummary.of(_session.text).hasCheckboxes,
  };

  /// Whether the menu's commands on checked items run: in Visual edit and
  /// Read, while the document takes edits.
  bool get _runsCheckedCommands =>
      _gate.state.mode != EditMode.markdown && !_isReadOnly;

  /// [context] is this screen's, below its own messenger; [settings] are
  /// the document's.
  Widget _menu(BuildContext context, NoteSettings settings) =>
      PopupMenuButton<VoidCallback>(
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          if (_hasCheckboxes) ...[
            if (_runsCheckedCommands) ...[
              PopupMenuItem(
                value: () => _gate.run(MoveToEnd.new),
                child: const Text('Move checked items to end now'),
              ),
              PopupMenuItem(
                value: () => _gate.run(ClearChecked.new),
                child: const Text('Clear checked items now'),
              ),
            ],
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

  /// Asks how [note]'s checked items show, on this device; nothing moves.
  Future<void> _pickCheckedItems(Note note, CheckedItems current) async {
    final chosen = await showCheckedItemsDialog(context, current: current);
    if (chosen == null || chosen == current) return;
    await _settings.edit(
      note.key,
      (settings) => settings.withCheckedItems(chosen),
    );
  }

  void _showMode(EditMode mode) {
    _mode = mode;
    _showShownMode();
    _saveMode(mode);
  }

  /// Remembers [mode] on this device; for a new document, once it has a
  /// file.
  void _saveMode(EditMode mode) {
    final note = _session.note;
    if (note == null) {
      _modeToSave = true;
      return;
    }
    unawaited(_settings.edit(note.key, (settings) => settings.withMode(mode)));
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(folderReachProvider(_folder.location), (_, _) {
        _showShownMode();
      })
      ..listen(noteSettingsProvider, (_, _) {
        final checkedItems = _settingsNow.checkedItems;
        if (_gate.state.checkedItems != checkedItems) {
          _gate.send((_) => SetCheckedItems(checkedItems));
        }
      })
      ..listen(folderScansProvider, (_, next) {
        if (next.value case final scans?) _session.observe(scans);
      });
    return PopScope(
      canPop: _canLeaveNow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: _scaffold(),
    );
  }

  /// Esc leaves the document, as the back arrow does; Ctrl+1, 2, 3 pick
  /// the modes in the mode menu's order.
  late final Map<SingleActivator, VoidCallback> _keys = {
    const SingleActivator(LogicalKeyboardKey.escape): () =>
        unawaited(Navigator.maybePop(context)),
    for (final (index, mode) in EditMode.values.indexed)
      SingleActivator(_digits[index], control: true): () {
        if (!_isReadOnly && mode != _mode) _showMode(mode);
      },
  };

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
  ];

  /// Hints whose action works on this screen (e.g. undoing a removed
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

  /// The edits were kept as a conflict copy; nothing more to edit here.
  bool get _isDone => _session.status is KeptAsConflict;

  bool get _isUnreachable => _unreachable(_folder);

  bool _unreachable(NoteFolder folder) =>
      ref.read(folderReachProvider(folder.location)) == Reach.unreachable;

  Widget _content(BuildContext context) {
    // Rebuilds when the folder's reach changes.
    ref.watch(folderReachProvider(_folder.location));
    final unreachable = _isUnreachable;
    final readOnly = _isReadOnly;
    final scans = ref.watch(folderScansProvider).value;
    final key = _session.note?.key;
    final mark = key == null
        ? NoteMark.none
        : scans?.markOf(key) ?? NoteMark.none;
    ref.watch(noteSettingsProvider);
    final settings = _settingsNow;
    final addItems = ref.watch(addItemPlaceProvider).value ?? AddItemPlace.top;
    final tint = noteTint(mark.color, Theme.of(context).colorScheme);
    final text = _session.text;
    final path = _session.file.pathFor(text);
    return Scaffold(
      backgroundColor: tint,
      appBar: AppBar(
        backgroundColor: tint,
        title: NoteHeading(
          title: noteTitle(text, path),
          edited: _session.note?.modified,
        ),
        actions: [
          SaveIndicator(_session.saveState, onSave: _session.saveNow),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _pull.currentState!.refresh(),
          ),
          if (!readOnly) ...[
            EditModeButton(mode: _mode, onChanged: _showMode),
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
            _folder,
            message: 'Your text is kept on this device.',
          ),
          // Its ways out need the folder.
          if (!unreachable) EditStateBanner(_session, onClose: _leave),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              // A new document can still go to another folder.
              child: DocumentPlaceChip(
                _session,
                enabled: _session.file is NewFile || !readOnly,
              ),
            ),
          ),
          Expanded(
            // The editor scrolls inside.
            child: PullToRefresh(
              key: _pull,
              onRefresh: _scans.refresh,
              child: NoteTextZoom(
                child: DocumentEditor(
                  _gate,
                  text: text,
                  notices: _session.editorNotices,
                  addItems: addItems,
                  onLink: (url) => openMarkdownLink(context, ref, url),
                  images: noteImages(
                    _container.read(noteFilesProvider(_folder)),
                    folder: _folder,
                    note: path,
                  ),
                  // A new document is for typing right away.
                  autofocus: widget.note == null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

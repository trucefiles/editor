import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../common/open_link.dart';
import '../../common/screen_shortcuts.dart';
import '../../common/snack.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../file_types/editable_type.dart';
import '../../files/file_actions.dart';
import '../../files/file_colors.dart';
import '../../files/file_settings_controller.dart';
import '../../files/files_wiring.dart';
import '../../files/ui/delete_failure_text.dart';
import '../../files/ui/file_heading.dart';
import '../../files/ui/pin_or_color_sheet.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folders/folders_controller.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../settings/device_settings_controller.dart';
import '../../text_zoom/ui/document_text_zoom.dart';
import '../../versions/merge_outcome.dart';
import '../file_controller.dart';
import '../file_page_wiring.dart';
import '../file_pages.dart';
import 'edit_state_banner.dart';
import 'file_backups.dart';
import 'file_place_chip.dart';
import 'history_end_text.dart';
import 'save_indicator.dart';

/// The one page for an open text document of any type; its type's editor
/// part shows the text (e.g. Visual edit, Markdown edit or Read of a
/// Markdown document). Saves as the user types; a new file is
/// created as the user leaves it or the app is hidden.
class FileScreen extends ConsumerStatefulWidget {
  const FileScreen(FileText this.file, {super.key})
    : place = null,
      made = null,
      name = '';

  /// A new file, to go into [place]: [made] (a plain one if `null`),
  /// named [name] if it is named first.
  const FileScreen.fresh(
    FilePlace this.place, {
    this.made,
    this.name = '',
    super.key,
  }) : file = null;

  /// The file to open, as read just before; `null` for a new one.
  final FileText? file;
  final FilePlace? place;
  final NewFileChoice<EditableType>? made;
  final String name;

  @override
  ConsumerState<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends ConsumerState<FileScreen> {
  late final FilePage _page;
  late final StreamSubscription<void> _partChanges;
  late final AppLifecycleListener _lifecycle;
  late final List<StreamSubscription<Object>> _notices;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _pull = GlobalKey<PullToRefreshState>();

  /// When the file was opened: its pictures are read anew each open.
  final _openedAt = DateTime.now();

  FileSession get _session => _page.session;
  FileController get _controller => _page.controller;
  PageEditor get _editor => _session.editor;

  /// Where the file is now: it changes when the user moves it, or
  /// picks another place for a new one.
  Folder get _folder => _session.file.folder;

  @override
  void initState() {
    super.initState();
    final pages = ref.read(filePagesProvider);
    _page = switch ((widget.file, widget.place)) {
      (final file?, _) => pages.open(file, withFile: _withFile),
      (_, final place?) => pages.openNew(
        place,
        made: widget.made,
        name: widget.name,
        withFile: _withFile,
      ),
      _ => throw StateError('A file or a place is needed.'),
    };
    _partChanges = _page.part.changes.listen((_) => _rebuild());
    _controller.addListener(_rebuild);
    _notices = [
      _session.editorNotices.listen(_onEditorNotice),
      _session.fileNotices.listen(_onFileNotice),
      _session.stopNotices.listen(_onStopped),
    ];
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(_session.secure(SecureReason.hide)),
      onExitRequested: _onExitRequested,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    for (final notices in _notices) {
      unawaited(notices.cancel());
    }
    unawaited(_partChanges.cancel());
    _controller.removeListener(_rebuild);
    unawaited(_page.close());
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Tells that the file stopped taking edits, why, and whether its
  /// edits are kept.
  void _onStopped(Stopped stopped) =>
      _messenger.currentState?.showHint(switch (stopped) {
        Stopped(cause: StopCause.folderGone) =>
          "This file's folder was removed from the app, so the file is read "
              'only now. Its latest edits are kept only here, until it '
              'closes.',
        Stopped(kept: true) =>
          'Something went wrong, so this file is read only now. Its edits '
              'are kept on this device and go into the file at the next '
              'start.',
        Stopped() =>
          'Something went wrong, so this file is read only now, and its '
              "latest edits couldn't be kept. They stay only here, until it "
              'closes.',
      });

  void _onEditorNotice(EditorNotice notice) {
    final messenger = _messenger.currentState;
    if (messenger == null) return;
    switch (notice) {
      case UndoOffered(:final id, :final what):
        messenger.showHint(
          switch (what) {
            OfferedUndo.removal => 'Removed',
            OfferedUndo.restore => 'Backup restored',
          },
          actionLabel: 'Undo',
          onAction: () => _editor.send(UndoStep(id)),
        );
      case UndoRefused():
        messenger.showHint("Can't undo, because the file has changed since.");
      case HistoryEnd(:final start):
        final context = _messenger.currentContext;
        messenger.showHint(
          '${start.text} Older versions are in Backups.',
          actionLabel: 'Backups',
          onAction: context == null || _session.read == null
              ? null
              : () => unawaited(_openBackups(context)),
        );
      case ToFile():
        break;
    }
  }

  void _onFileNotice(FileEvent notice) {
    final messenger = _messenger.currentState;
    switch (notice) {
      case Replaced():
        messenger?.showHint('Updated with a change from another device or app');
      case PickMerged(:final lost):
        messenger?.showNotice(mergeOutcome(lost));
      case _:
        break;
    }
  }

  /// Leaves once the edits are kept (see [FileController.mayGo]).
  /// While the folder can't be reached, they stay on this device and go
  /// into the file at the next start.
  Future<void> _leave() async {
    if (await _controller.mayGo(SecureReason.close, _askToDiscard)) _close();
  }

  /// On desktop: quits once the edits are kept, or the user discards them.
  Future<AppExitResponse> _onExitRequested() async =>
      await _controller.mayGo(SecureReason.exit, _askToDiscard)
      ? AppExitResponse.exit
      : AppExitResponse.cancel;

  /// Whether the user drops edits that can be kept nowhere.
  Future<bool> _askToDiscard() async {
    if (!mounted) return false;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("The edits can't be saved"),
        content: const Text(
          'Neither the file nor a conflict copy could be written. '
          'Staying keeps the text here, to copy elsewhere.',
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
    return discard ?? false;
  }

  /// Closes once the file's folder was removed: its edits were saved
  /// before (see `FolderListWork.secureOpen`), and its drafts go with the
  /// folder, so the hint promises nothing.
  void _closeIfNotShown(List<Folder> folders) {
    if (_controller.folderShownIn(folders)) return;
    ScaffoldMessenger.of(context)
        .showHint('The folder was removed, so the file closed.');
    _closeWithAllOnTop();
  }

  /// Closes the editor and every screen or dialog open on top of it.
  void _closeWithAllOnTop() {
    final route = mounted ? ModalRoute.of(context) : null;
    if (route == null || !route.isActive) return;
    Navigator.of(context)
      ..popUntil((top) => top == route)
      ..pop();
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
    final outcome = await _controller.deleteFile();
    if (!context.mounted) return;
    switch (outcome) {
      case NewDropped():
        Navigator.pop(context);
      case DeletedForUndo(:final deleted):
        _offerUndo(ref.read(fileActionsProvider), deleted);
        Navigator.pop(context);
      case DeleteRefused(:final failure):
        showSnack(context, deleteFailureText(failure));
      case AlreadyGone() || FileStopped():
        break;
    }
  }

  /// Runs [action] on the file (see
  /// [FileController.withFile]).
  Future<void> _withFile(
    FutureOr<void> Function(ListedFile file) action,
  ) async {
    final file = await _controller.withFile();
    if (!mounted) return;
    switch (file) {
      case Ok(value: final file):
        await action(file.listed);
      case Err(error: NoFile.empty):
        _messenger.currentState?.showHint(
          "Write something first. An empty file isn't saved.",
        );
      case Err(error: NoFile.notCreated):
        // The banner tells why.
        break;
      case Err(error: NoFile.stopped):
        // Told as it stopped.
        break;
    }
  }

  /// The hint outlives this screen, so it shows on the app's messenger,
  /// found from above this screen's own.
  void _offerUndo(FileActions actions, UndoableDelete deleted) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showHint(
      'File deleted',
      actionLabel: 'Undo',
      onAction: () async {
        if (await actions.undoDelete(deleted) case Err(:final error)) {
          messenger.showHint(error.text);
        }
      },
    );
  }

  /// [context] is this screen's, below its own messenger; [settings] are
  /// the file's.
  Widget _menu(BuildContext context, FileSettings settings) =>
      PopupMenuButton<VoidCallback>(
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          ..._page.view.menu(context, settings.view),
          PopupMenuItem(
            value: () =>
                _withFile((file) => editPinOrColor(context, ref, file)),
            child: const Text('Pin or color'),
          ),
          if (_session.read != null)
            PopupMenuItem(
              value: () => unawaited(_openBackups(context)),
              child: const Text('Backups'),
            ),
          if (usesTouch(Theme.of(context)))
            PopupMenuItem(value: _refresh, child: const Text('Refresh')),
          PopupMenuItem(
            value: () => _delete(context),
            child: const Text('Delete file'),
          ),
        ],
      );

  void _refresh() => unawaited(_pull.currentState!.refresh());

  /// Opens this file's backups; [context] is below this screen's
  /// messenger.
  Future<void> _openBackups(BuildContext context) async {
    final file = _session.read;
    final messenger = _messenger.currentState;
    if (file == null || messenger == null) return;
    await openFileBackups(
      context,
      file: file.listed,
      title: _session.title,
      controller: _controller,
      messenger: messenger,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(folderReachProvider(_folder.id), (_, _) {
        _controller.reachChanged();
      })
      ..listen(fileSettingsProvider, (_, _) {
        _page.part.viewChanged(_controller.settings.view);
      })
      ..listen(folderContentsProvider, (_, next) {
        if (next.value case final contents?) _session.observe(contents);
      })
      ..listen(foldersProvider, (_, next) {
        if (next.value case final folders?) _closeIfNotShown(folders);
      });
    return PopScope(
      canPop: _controller.canLeaveNow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: _scaffold(),
    );
  }

  /// Esc leaves the file, as the back arrow does; Ctrl+Z undoes,
  /// Ctrl+Shift+Z and Ctrl+Y redo while the file is edited; the
  /// type's own keys work while it can be edited.
  late final Map<SingleActivator, VoidCallback> _keys = {
    const SingleActivator(LogicalKeyboardKey.escape): () =>
        unawaited(Navigator.maybePop(context)),
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
      if (_isEdited) _editor.send(const Undo());
    },
    const SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: true,
      shift: true,
    ): () {
      if (_isEdited) _editor.send(const Redo());
    },
    const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
      if (_isEdited) _editor.send(const Redo());
    },
    for (final MapEntry(key: keys, value: action) in _page.view.keys.entries)
      keys: () {
        if (!_controller.readOnly) action();
      },
  };

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

  /// Open for editing: undo and redo work.
  bool get _isEdited => !_controller.readOnly && _page.part.isEditing;

  Widget _content(BuildContext context) {
    // Rebuilds when the folder's reach changes.
    ref.watch(folderReachProvider(_folder.id));
    final unreachable = _controller.unreachable;
    final readOnly = _controller.readOnly;
    final contents = ref.watch(folderContentsProvider).value;
    final key = _session.read?.key;
    final mark = _controller.markIn(contents);
    ref.watch(fileSettingsProvider);
    final settings = _controller.settings;
    final tint = fileTint(mark.color, Theme.of(context).colorScheme);
    final text = _session.text;
    final path = _session.path;
    return Scaffold(
      backgroundColor: tint,
      appBar: AppBar(
        backgroundColor: tint,
        title: FileHeading(
          title: _session.title,
          edited: _session.read?.listed.modified,
        ),
        actions: [
          SaveIndicator(_session.saveState, onSave: _session.saveNow),
          if (_isEdited) HistoryButtons(_editor),
          // On touch, pulling down refreshes, and the menu has it.
          if (readOnly || !usesTouch(Theme.of(context)))
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          if (!readOnly) ...[
            ..._page.view.actions(context),
            _menu(context, settings),
          ],
        ],
      ),
      body: Column(
        children: [
          if (key != null)
            if (contents?.conflicts.forFile(key) case final conflict?)
              ConflictBanner(conflict),
          UnreachableBanner(
            _folder,
            message: 'The text is kept on this device.',
          ),
          // Its ways out need the folder.
          if (!unreachable) EditStateBanner(_controller, onClose: _leave),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              // A new file can still go to another folder.
              child: FilePlaceChip(
                _session,
                enabled: _session.file is NewFile || !readOnly,
              ),
            ),
          ),
          Expanded(
            // The editor scrolls inside.
            child: PullToRefresh(
              key: _pull,
              onRefresh: ref.read(folderContentsProvider.notifier).refresh,
              child: DocumentTextZoom(
                // Only the editor shows the add-item setting, so only it
                // builds again when the setting changes.
                child: _tinted(
                  tint,
                  Consumer(
                    // Every view gets the text host; text types use all
                    // of it.
                    builder: (context, ref, _) => _page.view.view(
                      TextHost(
                        kept: text,
                        addItems: ref.watch(
                          deviceSettingsProvider.select(
                            (s) => s.requireValue.addItemPlace,
                          ),
                        ),
                        openLink: (link) => openLink(context, ref, link),
                        hint: (message) => showSnack(context, message),
                        images: FolderImages(
                          ref.read(fileAccessProvider).of(_folder),
                          folder: _folder.id,
                          document: path,
                          openedAt: _openedAt,
                        ),
                      ),
                      // A new file is for typing right away.
                      autofocus: widget.file == null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [child] with its lines in [tint]'s colors: only the file's own
  /// view, so menus and dialogs on plain surfaces keep the plain colors.
  Widget _tinted(Color? tint, Widget child) => switch (tint) {
    final tint? => Theme(
      data: tintedTheme(Theme.of(context), tint),
      child: child,
    ),
    null => child,
  };
}

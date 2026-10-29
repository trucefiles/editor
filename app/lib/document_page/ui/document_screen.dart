import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/open_link.dart';
import '../../common/screen_shortcuts.dart';
import '../../common/snack.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../documents/deleted_document.dart';
import '../../documents/document.dart';
import '../../documents/document_actions.dart';
import '../../documents/document_colors.dart';
import '../../documents/document_images.dart';
import '../../documents/document_place.dart';
import '../../documents/document_settings.dart';
import '../../documents/document_settings_controller.dart';
import '../../documents/document_text.dart';
import '../../documents/document_title.dart';
import '../../documents/documents_wiring.dart';
import '../../documents/ui/delete_failure_text.dart';
import '../../documents/ui/document_heading.dart';
import '../../documents/ui/pin_or_color_sheet.dart';
import '../../editor/ui/history_buttons.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folders/document_folder.dart';
import '../../folders/folders_controller.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../settings/device_settings_controller.dart';
import '../../text_zoom/ui/document_text_zoom.dart';
import '../../theme/touch.dart';
import '../document_controller.dart';
import '../document_file.dart';
import '../document_page_wiring.dart';
import '../document_pages.dart';
import '../document_session.dart';
import 'document_backups.dart';
import 'document_place_chip.dart';
import 'edit_state_banner.dart';
import 'history_end_text.dart';
import 'save_indicator.dart';

/// The one page for an open text document of any type; its type's editor
/// part shows the text (e.g. Visual edit, Markdown edit or Read of a
/// Markdown document). Saves as the user types; a new document's file is
/// created as the user leaves it or the app is hidden.
class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen(DocumentText this.document, {super.key}) : place = null;

  /// A new document, to go into [place].
  const DocumentScreen.fresh(DocumentPlace this.place, {super.key})
    : document = null;

  /// The document to open, as read just before; `null` for a new one.
  final DocumentText? document;
  final DocumentPlace? place;

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  late final DocumentPage _page;
  late final StreamSubscription<void> _partChanges;
  late final AppLifecycleListener _lifecycle;
  late final List<StreamSubscription<Object>> _notices;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _pull = GlobalKey<PullToRefreshState>();

  DocumentSession get _session => _page.session;
  DocumentController get _controller => _page.controller;
  PageEditor get _editor => _session.editor;

  /// Where the document is now: it changes when the user moves it, or
  /// picks another place for a new one.
  DocumentFolder get _folder => _session.file.folder;

  @override
  void initState() {
    super.initState();
    final pages = ref.read(documentPagesProvider);
    _page = switch ((widget.document, widget.place)) {
      (final document?, _) => pages.open(document, withFile: _withFile),
      (_, final place?) => pages.openNew(place, withFile: _withFile),
      _ => throw StateError('A document or a place is needed.'),
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

  /// Tells that the document stopped taking edits (a bug), and whether
  /// its edits are [kept].
  void _onStopped(bool kept) => _messenger.currentState?.showHint(
    kept
        ? 'Something went wrong, so this document is read only now. Your '
              'edits are kept on this device and go into the file at the '
              'next start.'
        : 'Something went wrong, so this document is read only now, and '
              "your latest edits couldn't be kept. Copy them elsewhere "
              'before you leave.',
  );

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
        messenger.showHint(
          "Can't undo, because the document has changed since.",
        );
      case HistoryEnd(:final start):
        final context = _messenger.currentContext;
        messenger.showHint(
          '${start.text} Older versions are in Backups.',
          actionLabel: 'Backups',
          onAction: context == null || _session.document == null
              ? null
              : () => unawaited(_openBackups(context)),
        );
      case ToFile():
        break;
    }
  }

  void _onFileNotice(FileEvent notice) {
    if (notice is Replaced) {
      _messenger.currentState?.showHint(
        'Updated with a change from another device or app',
      );
    }
  }

  /// Leaves once the edits are kept (see [DocumentController.mayGo]).
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
        title: const Text("Your edits can't be saved"),
        content: const Text(
          'Neither the document nor a conflict copy could be written. '
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
    return discard ?? false;
  }

  /// Closes once no folder shows the document any more: its edits were
  /// saved before (see `FolderListWork.secureOpen`). As the user narrowed
  /// its folder, what is left stays on this device; as they removed it,
  /// its drafts go with it, so the hint promises nothing.
  void _closeIfNotShown(List<DocumentFolder> folders) {
    final hint = switch (_controller.shownIn(folders)) {
      DocumentShown.shown => null,
      DocumentShown.narrowedAway =>
        'The document is no longer in a folder shown here. Your edits are '
            'kept.',
      DocumentShown.folderRemoved =>
        'The folder was removed, so the document closed.',
    };
    if (hint == null) return;
    ScaffoldMessenger.of(context).showHint(hint);
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
    final outcome = await _controller.deleteDocument();
    if (!context.mounted) return;
    switch (outcome) {
      case NewDropped():
        Navigator.pop(context);
      case DocumentDeleted(:final deleted):
        _offerUndo(ref.read(documentActionsProvider), deleted);
        Navigator.pop(context);
      case DeleteRefused(:final failure):
        showSnack(context, deleteFailureText(failure));
      case AlreadyGone() || DocumentStopped():
        break;
    }
  }

  /// Runs [action] on the document's file (see
  /// [DocumentController.withFile]).
  Future<void> _withFile(
    FutureOr<void> Function(Document document) action,
  ) async {
    final file = await _controller.withFile();
    if (!mounted) return;
    switch (file) {
      case Ok(value: final document):
        await action(document.document);
      case Err(error: NoFile.empty):
        _messenger.currentState?.showHint(
          "Write something first. An empty document isn't saved.",
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
  void _offerUndo(DocumentActions actions, DeletedDocument deleted) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showHint(
      'Document deleted',
      actionLabel: 'Undo',
      onAction: () async {
        if (await actions.undoDelete(deleted) case Err(:final error)) {
          messenger.showHint(error.text);
        }
      },
    );
  }

  /// [context] is this screen's, below its own messenger; [settings] are
  /// the document's.
  Widget _menu(BuildContext context, DocumentSettings settings) =>
      PopupMenuButton<VoidCallback>(
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          ..._page.view.menu(context, settings.view),
          PopupMenuItem(
            value: () =>
                _withFile((document) => editPinOrColor(context, ref, document)),
            child: const Text('Pin or color'),
          ),
          if (_session.document != null)
            PopupMenuItem(
              value: () => unawaited(_openBackups(context)),
              child: const Text('Backups'),
            ),
          if (usesTouch(Theme.of(context)))
            PopupMenuItem(value: _refresh, child: const Text('Refresh')),
          PopupMenuItem(
            value: () => _delete(context),
            child: const Text('Delete document'),
          ),
        ],
      );

  void _refresh() => unawaited(_pull.currentState!.refresh());

  /// Opens this document's backups; [context] is below this screen's
  /// messenger.
  Future<void> _openBackups(BuildContext context) async {
    final document = _session.document;
    final messenger = _messenger.currentState;
    if (document == null || messenger == null) return;
    final text = _session.text;
    await openDocumentBackups(
      context,
      document: document.document,
      title: documentTitle(
        text,
        _session.file.pathFor(text),
        _page.type.support,
      ),
      controller: _controller,
      messenger: messenger,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(folderReachProvider(_folder.base), (_, _) {
        _controller.reachChanged();
      })
      ..listen(documentSettingsProvider, (_, _) {
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

  /// Esc leaves the document, as the back arrow does; Ctrl+Z undoes,
  /// Ctrl+Shift+Z and Ctrl+Y redo while the document is edited; the
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
    ref.watch(folderReachProvider(_folder.base));
    final unreachable = _controller.unreachable;
    final readOnly = _controller.readOnly;
    final contents = ref.watch(folderContentsProvider).value;
    final key = _session.document?.key;
    final mark = _controller.markIn(contents);
    ref.watch(documentSettingsProvider);
    final settings = _controller.settings;
    final tint = documentTint(mark.color, Theme.of(context).colorScheme);
    final text = _session.text;
    final path = _session.file.pathFor(text);
    return Scaffold(
      backgroundColor: tint,
      appBar: AppBar(
        backgroundColor: tint,
        title: DocumentHeading(
          title: documentTitle(text, path, _page.type.support),
          edited: _session.document?.document.modified,
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
            if (contents?.conflicts.forDocument(key) case final conflict?)
              ConflictBanner(conflict),
          UnreachableBanner(
            _folder,
            message: 'Your text is kept on this device.',
          ),
          // Its ways out need the folder.
          if (!unreachable) EditStateBanner(_controller, onClose: _leave),
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
              onRefresh: ref.read(folderContentsProvider.notifier).refresh,
              child: DocumentTextZoom(
                child: _page.view.view(
                  (
                    kept: text,
                    addItems: ref.watch(
                      deviceSettingsProvider.select(
                        (s) => s.requireValue.addItemPlace,
                      ),
                    ),
                    openLink: (link) => openLink(context, ref, link),
                    images: documentImages(
                      ref.read(folderFilesProvider).of(_folder),
                      folder: _folder,
                      document: path,
                    ),
                  ),
                  // A new document is for typing right away.
                  autofocus: widget.document == null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

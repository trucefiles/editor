import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/screen_shortcuts.dart';
import '../../common/snack.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../documents/deleted_note.dart';
import '../../documents/document.dart';
import '../../documents/document_actions.dart';
import '../../documents/document_colors.dart';
import '../../documents/document_drafts.dart';
import '../../documents/document_files.dart';
import '../../documents/document_place.dart';
import '../../documents/document_settings.dart';
import '../../documents/document_settings_controller.dart';
import '../../documents/document_text.dart';
import '../../documents/document_title.dart';
import '../../documents/document_version.dart';
import '../../documents/ui/delete_failure_text.dart';
import '../../documents/ui/document_heading.dart';
import '../../documents/ui/pin_or_color_sheet.dart';
import '../../editor/ui/history_buttons.dart';
import '../../file_types/document_type.dart';
import '../../file_types/document_types.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folders/document_folder.dart';
import '../../folders/folder_lookup.dart';
import '../../folders/folders_controller.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../text_zoom/ui/document_text_zoom.dart';
import '../../theme/touch.dart';
import '../document_controller.dart';
import '../document_file.dart';
import '../document_session.dart';
import '../editor_part.dart';
import '../file_effects.dart';
import '../open_documents.dart';
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
  // Read up front: dispose() needs them, and ref is unusable by then.
  late final FolderStateController _folderState;
  late final ProviderContainer _container;
  late final DocumentSettingsController _settings;
  late final DocumentType _type;
  late final EditorPart _part;
  late final DocumentSession _session;
  late final DocumentController _controller;
  late final AppLifecycleListener _lifecycle;
  late final List<StreamSubscription<Object>> _notices;
  late final void Function() _leaveOpenDocuments;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _pull = GlobalKey<PullToRefreshState>();

  PageEditor get _editor => _session.editor;

  /// Where the document is now: it changes when the user moves it, or
  /// picks another place for a new one.
  DocumentFolder get _folder => _session.file.folder;

  /// The document's settings on this device; the defaults until it has a
  /// file.
  DocumentSettings get _settingsNow => switch (_session.document) {
    final document? => _settings.settingsOf(document.key),
    null => DocumentSettings.defaults,
  };

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _folderState = ref.read(folderContentsProvider.notifier);
    _settings = ref.read(documentSettingsProvider.notifier);
    final document = widget.document;
    final settings = switch (document) {
      final document? => _settings.settingsOf(document.key),
      null => DocumentSettings.defaults,
    };
    final types = ref.read(documentTypesProvider);
    _type = switch (document) {
      final document? => types.ofFile(document.type),
      null => types.forNew,
    };
    final file = switch ((document, widget.place)) {
      (final document?, _) => ExistingFile(document),
      (_, final place?) => NewFile(place, type: _type),
      _ => throw StateError('A document or a place is needed.'),
    };
    final opened = document?.seen;
    _part = _type.editorPart(
      (
        text: opened?.text ?? '',
        version: opened?.version,
        view: settings.view,
        // Not yet kept as a conflict copy: only an unreachable folder
        // makes it read only.
        readOnly: _unreachable(file.folder),
        isNew: document == null,
      ),
      EditorPage(
        keepView: (change) => _controller.keepSettings(
          (settings) => settings.withView(change(settings.view)),
        ),
        withFile: _withFile,
      ),
    );
    _session = DocumentSession(
      FileEffects(
        file,
        filesOf: (folder) => _container.read(documentFilesProvider(folder)),
        draftsOf: (folder) =>
            _container.read(documentDraftsProvider(folder.base.id)),
        create: ref.read(documentActionsProvider).create,
      ),
      _part.editor,
    );
    _controller = DocumentController(
      _session,
      reachSettled: () =>
          ref.read(folderReachProvider(_folder.base).notifier).settled(),
      backUp: _backUp,
      canEdit: () => !_isReadOnly,
      delete: ref.read(documentActionsProvider).delete,
      editSettings: _settings.edit,
    );
    _part.addListener(_onPartChanged);
    _session
      ..addListener(_showShownMode)
      ..addListener(_tellIfStopped);
    _notices = [
      _session.editorNotices.listen(_onEditorNotice),
      _session.fileNotices.listen(_onFileNotice),
    ];
    _leaveOpenDocuments = ref
        .read(openDocumentsProvider)
        .add(
          base: () => _folder.base,
          secure: () => _session.secure(SecureReason.hide),
        );
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(_session.secure(SecureReason.hide)),
      onExitRequested: _onExitRequested,
    );
    // Opening a document lists the folders again, as the refresh setting
    // promises; its own text was read just before.
    unawaited(_folderState.refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    for (final notices in _notices) {
      unawaited(notices.cancel());
    }
    _part
      ..removeListener(_onPartChanged)
      ..dispose();
    _session
      ..removeListener(_showShownMode)
      ..removeListener(_tellIfStopped);
    _controller.dispose();
    final session = _session;
    final leaveOpenDocuments = _leaveOpenDocuments;
    // Also after a leave that kept the edits: the screen may also go
    // without one (its route removed), and a second answer is quick. It
    // stays an open document until then, so a folder change waits for it.
    unawaited(
      session.secure(SecureReason.close).whenComplete(() {
        leaveOpenDocuments();
        session.dispose();
      }),
    );
    super.dispose();
  }

  /// Backs up [text], the document's text now.
  Future<Result<void, StoreError>> _backUp(String text) async =>
      switch (_session.document) {
        final document? =>
          await _container
              .read(documentFilesProvider(document.folder))
              .backUpCurrent(document, text),
        null => const Err(StoreError.notFound),
      };

  /// Shows the document only to read while it can't be edited.
  void _showShownMode() {
    _part.showReadOnly(readOnly: _isReadOnly);
    if (mounted) setState(() {});
  }

  void _onPartChanged() {
    if (mounted) setState(() {});
  }

  bool _toldStopped = false;

  /// Tells once that the document stopped taking edits (a bug), once
  /// it is known whether its edits are kept.
  void _tellIfStopped() {
    final kept = _session.editsKept;
    if (!_session.stopped || kept == null || _toldStopped) return;
    _toldStopped = true;
    _messenger.currentState?.showHint(
      kept
          ? 'Something went wrong, so this document is read only now. Your '
                'edits are kept on this device and go into the file at the '
                'next start.'
          : 'Something went wrong, so this document is read only now, and '
                "your latest edits couldn't be kept. Copy them elsewhere "
                'before you leave.',
    );
  }

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
    final path = _session.file.pathFor(_session.text);
    if (folders.folderOf(_folder.base.id, path) != null) return;
    final removed = !folders.any((folder) => folder.id == _folder.id);
    ScaffoldMessenger.of(context).showHint(
      removed
          ? 'The folder was removed, so the document closed.'
          : 'The document is no longer in a folder shown here. Your edits '
                'are kept.',
    );
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

  /// Whether the screen can close at once: nothing is left to keep.
  bool get _canLeaveNow => switch (_session.status) {
    InStep() || Unwritten() => !_editor.state.unsent,
    KeptAsConflict() || Closed() => true,
    Editing() ||
    ChangedElsewhere() ||
    DeletedElsewhere() ||
    SaveFailed() => false,
  };

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
  /// [DocumentController.withFile]). [context] is this screen's, below
  /// its own messenger.
  Future<void> _withFile(
    BuildContext context,
    FutureOr<void> Function(Document document) action,
  ) async {
    final file = await _controller.withFile();
    if (!context.mounted) return;
    switch (file) {
      case Ok(value: final document):
        await action(document.document);
      case Err(error: NoFile.empty):
        showSnack(
          context,
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
  void _offerUndo(DocumentActions actions, DeletedNote deleted) {
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
          ..._part.menu(context, settings.view),
          PopupMenuItem(
            value: () => _withFile(
              context,
              (document) => editPinOrColor(context, ref, document),
            ),
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
      title: documentTitle(text, _session.file.pathFor(text), _type.support),
      controller: _controller,
      messenger: messenger,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(folderReachProvider(_folder.base), (_, _) {
        _showShownMode();
      })
      ..listen(documentSettingsProvider, (_, _) {
        _part.viewChanged(_settingsNow.view);
      })
      ..listen(folderContentsProvider, (_, next) {
        if (next.value case final contents?) _session.observe(contents);
      })
      ..listen(foldersProvider, (_, next) {
        if (next.value case final folders?) _closeIfNotShown(folders);
      });
    return PopScope(
      canPop: _canLeaveNow,
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
    for (final MapEntry(key: keys, value: action) in _part.keys.entries)
      keys: () {
        if (!_isReadOnly) action();
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

  /// Only shown in Read: no mode to pick.
  bool get _isReadOnly => _isDone || _isUnreachable || _session.stopped;

  /// Open for editing: undo and redo work.
  bool get _isEdited => !_isReadOnly && _part.isEditing;

  /// The edits were kept as a conflict copy; nothing more to edit here.
  bool get _isDone => _session.status is KeptAsConflict;

  bool get _isUnreachable => _unreachable(_folder);

  bool _unreachable(DocumentFolder folder) =>
      ref.read(folderReachProvider(folder.base)) == Reach.unreachable;

  Widget _content(BuildContext context) {
    // Rebuilds when the folder's reach changes.
    ref.watch(folderReachProvider(_folder.base));
    final unreachable = _isUnreachable;
    final readOnly = _isReadOnly;
    final contents = ref.watch(folderContentsProvider).value;
    final key = _session.document?.key;
    final mark = key == null
        ? DocumentMark.none
        : contents?.markOf(key) ?? DocumentMark.none;
    ref.watch(documentSettingsProvider);
    final settings = _settingsNow;
    final tint = documentTint(mark.color, Theme.of(context).colorScheme);
    final text = _session.text;
    final path = _session.file.pathFor(text);
    return Scaffold(
      backgroundColor: tint,
      appBar: AppBar(
        backgroundColor: tint,
        title: DocumentHeading(
          title: documentTitle(text, path, _type.support),
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
            ..._part.actions(context),
            _menu(context, settings),
          ],
        ],
      ),
      body: Column(
        children: [
          if (key != null)
            if (contents?.conflicts.forNote(key) case final conflict?)
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
              onRefresh: _folderState.refresh,
              child: DocumentTextZoom(
                child: _part.view(
                  (folder: _folder, path: path, kept: text),
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

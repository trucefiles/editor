import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../documents/document.dart';
import '../editor/editor_gate.dart';
import '../scan/folder_scans.dart';
import 'document_file.dart';
import 'document_version.dart';
import 'file_effects.dart';
import 'save_state.dart';

/// One open document, its page model: its editor owner (what shows,
/// behind its [gate]) and its file owner (where the edits are kept),
/// joined: each one's events become the other's inputs. Their effects run
/// inside the owners. No UI. Listeners hear of every change of where the
/// edits are ([status], [saveState]); the [gate] tells of changes to what
/// shows.
final class DocumentSession extends ChangeNotifier {
  /// The document whose file [effects] reads and writes; it opens in
  /// [mode], its checked items shown as [checkedItems].
  DocumentSession(
    this._effects, {
    EditMode mode = EditMode.visual,
    CheckedItems checkedItems = CheckedItems.moveToEnd,
  }) : _file = fileOwner(switch (_effects.file) {
         ExistingFile(:final document) => openedFile(document.seen),
         NewFile() => newFile(),
       }, _effects.run) {
    final opened = switch (_effects.file) {
      ExistingFile(:final document) => document.seen,
      NewFile() => null,
    };
    gate = EditorGate(
      editorOwner(
        opened?.text ?? '',
        version: opened?.version,
        mode: mode,
        checkedItems: checkedItems,
      ),
    );
    _subscriptions = [
      gate.events.listen(_onEditorEvent),
      _file.events.listen(_onFileEvent),
      _file.changes.listen((_) => notifyListeners()),
    ];
    gate.addListener(_onEditorChanged);
  }

  final FileEffects _effects;
  final FileOwner _file;

  /// The way into the editor owner.
  late final EditorGate gate;

  late final List<StreamSubscription<Object>> _subscriptions;
  final _editorNotices = StreamController<EditorEvent>.broadcast(sync: true);
  final _fileNotices = StreamController<FileEvent>.broadcast(sync: true);

  /// Whether the editor held edits not yet sent, as listeners last heard.
  bool _unsent = false;

  /// Where the file is.
  DocumentFile get file => switch (document) {
    final document? => ExistingFile(document),
    null => _effects.file,
  };

  /// The document's file as last read or written, or where the user moved
  /// it; `null` until a new document's file is created.
  Document? get document => switch (_file.state.file) {
    final version? => documentOf(version),
    null => null,
  };

  /// Where the document stands against its file.
  FileStatus get status => _file.state.status;

  /// The edits as last sent to be kept, and their rev.
  String get text => _file.state.text;
  int get rev => _file.state.rev;

  SaveState get saveState => saveStateOf(status, unsent: gate.state.unsent);

  /// What the editor asks of the user or tells them: [AskLink],
  /// [UndoOffered], [UndoRefused], [HistoryEnd].
  Stream<EditorEvent> get editorNotices => _editorNotices.stream;

  /// What the user is told of the file: [Replaced], [PickNotKept].
  Stream<FileEvent> get fileNotices => _fileNotices.stream;

  /// Keeps the edits somewhere lasting now, for [reason]; whether they
  /// are kept. A new document's file is created now, unless it is empty.
  /// The question goes to the editor, which sends its text first; the
  /// file owner answers.
  Future<bool> secure(SecureReason reason) async {
    final answer = await ask<EditorInput, Answer>(
      (input) => gate.send((_) => input),
      _file.events,
      (ticket) => SecureEditor(ticket, reason),
    );
    return answer?.kept ?? false;
  }

  /// Writes the edits kept on this device into the file now; a new
  /// document's file is created, as only securing it does.
  void saveNow() => switch (file) {
    ExistingFile() => _file.send(const SaveNow()),
    // As when the app hides: kept, and the document stays open.
    NewFile() => unawaited(secure(SecureReason.hide)),
  };

  /// What [scans] found of the file.
  void observe(FolderScans scans) {
    if (document?.key case final key?) {
      _file.send(Observed(scans.observe(key), startedAt: scans.startedAt));
    }
  }

  /// The user's pick between the edits at [rev] and [theirs], as the
  /// compare view showed them.
  void pick(PickChoice choice, {required Seen theirs, required int rev}) =>
      _file.send(Pick(choice, seen: theirs.version, rev: rev));

  /// The document reads [text] instead (a backup restored), as one edit
  /// that undo takes back.
  void replaceAll(String text) =>
      gate.send((now) => ReplaceAll(text, revision: now.revision));

  /// Writes the edits as the file again, after it was deleted elsewhere.
  void restoreMine() => _file.send(const RestoreMine());

  /// Drops the edits that could be kept nowhere.
  void discard() => _file.send(const Discard());

  /// The user moved or renamed the document to [copy].
  void moved(Document copy) {
    _effects.moved(copy);
    _file.send(Moved(copy.seen));
  }

  /// The user picked where a new document's file goes.
  void place(NewFile to) {
    _effects.place(to);
    notifyListeners();
  }

  void _onEditorEvent(EditorEvent event) => switch (event) {
    ToFile(:final input) => _file.send(input),
    AskLink() ||
    UndoOffered() ||
    UndoRefused() ||
    HistoryEnd() => _editorNotices.add(event),
  };

  /// Edits held in the editor change where the edits are, before they
  /// reach the file owner.
  void _onEditorChanged() {
    final unsent = gate.state.unsent;
    if (unsent == _unsent) return;
    _unsent = unsent;
    notifyListeners();
  }

  void _onFileEvent(FileEvent event) {
    switch (event) {
      case ToEditor():
        gate.external(FromFile(event));
        if (event is Replaced) _fileNotices.add(event);
      case PickNotKept():
        _fileNotices.add(event);
      case Answer():
        // [ask] hears it.
        break;
    }
  }

  /// Closes both owners; work under way still ends.
  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_editorNotices.close());
    unawaited(_fileNotices.close());
    gate
      ..removeListener(_onEditorChanged)
      ..dispose();
    unawaited(_file.close());
    super.dispose();
  }
}

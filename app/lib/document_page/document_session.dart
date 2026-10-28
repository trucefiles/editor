import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../documents/document_version.dart';
import '../scan/folder_scans.dart';
import 'document_file.dart';
import 'file_effects.dart';
import 'save_state.dart';

/// One open document, its page model: its editor owner (what shows, of
/// the document's type, seen through the shared [editor] contract) and
/// its file owner (where the edits are kept), joined: each one's events
/// become the other's inputs. Their effects run inside the owners. No UI.
/// Listeners hear of every change of where the edits are ([status],
/// [saveState]).
final class DocumentSession extends ChangeNotifier {
  /// The document whose file [effects] reads and writes, edited by
  /// [editor], which opened with the file's text as [effects] last saw
  /// it.
  DocumentSession(this._effects, this.editor)
    : _file = fileOwner(switch (_effects.file) {
        ExistingFile(:final document) => openedFile(document.seen),
        NewFile() => newFile(),
      }, _effects.run) {
    _subscriptions = [
      editor.events.listen(_onEditorEvent),
      editor.changes.listen(_onEditorChanged),
      _file.events.listen(_onFileEvent),
      _file.changes.listen((_) => notifyListeners(), onDone: _onFileStopped),
    ];
  }

  final FileEffects _effects;
  final FileOwner _file;

  /// The way into the editor owner.
  final PageEditor editor;

  late final List<StreamSubscription<Object>> _subscriptions;
  final _editorNotices = StreamController<EditorNotice>.broadcast(sync: true);
  final _fileNotices = StreamController<FileEvent>.broadcast(sync: true);

  /// Whether the editor held edits not yet sent, as listeners last heard.
  bool _unsent = false;

  bool _disposed = false;
  bool _stopped = false;

  /// Whether the file owner stopped by a bug: the document takes no more
  /// edits; those made so far are kept on this device ([editsKept]) and
  /// go into the file at the next start.
  bool get stopped => _stopped;

  /// Once [stopped]: whether the edits are kept on this device; `null`
  /// while that is not known yet.
  bool? get editsKept => _editsKept;
  bool? _editsKept;

  /// The keeps of the last draft started since [stopped]; the last one
  /// holds every edit.
  int _lastKeeps = 0;

  /// The text of the last draft started since [stopped].
  String? _lastDraft;

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

  /// The edits as last sent to be kept, and their rev. Once [stopped],
  /// the text kept as the last draft: the latest edits.
  String get text => _lastDraft ?? _file.state.text;
  int get rev => _file.state.rev;

  SaveState get saveState => saveStateOf(status, unsent: editor.state.unsent);

  /// What the editor tells the user: [UndoOffered], [UndoRefused],
  /// [HistoryEnd].
  Stream<EditorNotice> get editorNotices => _editorNotices.stream;

  /// What the user is told of the file: [Replaced], [PickNotKept].
  Stream<FileEvent> get fileNotices => _fileNotices.stream;

  /// Keeps the edits somewhere lasting now, for [reason]; whether they
  /// are kept. A new document's file is created now, unless it is empty.
  /// The question goes to the editor, which sends its text first; the
  /// file owner answers.
  Future<bool> secure(SecureReason reason) async {
    final answer = await ask<EditorRequest, Answer>(
      editor.send,
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
  void replaceAll(String text) => editor.send(ReplaceAll(text));

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

  void _onEditorEvent(EditorNotice event) => switch (event) {
    ToFile(input: Edited(:final text)) when _stopped => _keepLastDraft(text),
    ToFile() when _stopped => null,
    ToFile(:final input) => _file.send(input),
    UndoOffered() || UndoRefused() || HistoryEnd() => _editorNotices.add(event),
  };

  /// The file owner ended before [dispose]: it stopped by a bug. The
  /// edits it holds, and those the editor still holds, are kept as the
  /// draft.
  void _onFileStopped() {
    if (_disposed) return;
    _stopped = true;
    _keepLastDraft(text);
    // The editor sends what it still holds; [_keepLastDraft] keeps it.
    editor.send(SecureEditor(Ticket(), SecureReason.hide));
    notifyListeners();
  }

  void _keepLastDraft(String text) {
    _lastDraft = text;
    final keep = ++_lastKeeps;
    unawaited(
      _effects.keepLastDraft(text).then((kept) {
        if (keep != _lastKeeps || _disposed) return;
        _editsKept = kept;
        notifyListeners();
      }),
    );
  }

  /// Edits held in the editor change where the edits are, before they
  /// reach the file owner.
  void _onEditorChanged(EditorStatus status) {
    final unsent = status.unsent;
    if (unsent == _unsent) return;
    _unsent = unsent;
    notifyListeners();
  }

  void _onFileEvent(FileEvent event) {
    switch (event) {
      case ToEditor():
        editor.send(FromFile(event));
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
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_editorNotices.close());
    unawaited(_fileNotices.close());
    unawaited(editor.close());
    unawaited(_file.close());
    super.dispose();
  }
}

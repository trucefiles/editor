import 'dart:async';

import 'package:truce_core/truce_core.dart';

import '../document_text.dart';
import '../document_title.dart';
import '../document_version.dart';
import '../folder_state/folder_contents.dart';
import '../move_failure.dart';
import 'document_file.dart';
import 'file_effects.dart';
import 'save_state.dart';

/// Whether an open document takes edits.
sealed class SessionState {
  const SessionState();
}

/// Edits go to the file owner, which keeps them.
final class Running extends SessionState {
  const Running();
}

/// The file owner stopped by a bug: the document takes no more edits. The
/// latest ones, [text], are kept on this device as the draft and go into
/// the file at the next start. [kept]: whether the device keeps them, as
/// last known; `null` until first known.
final class Stopped extends SessionState {
  const Stopped(this.text, {this.kept});

  final String text;
  final bool? kept;
}

/// The page is gone: both owners are closed.
final class Ended extends SessionState {
  const Ended();
}

/// One open document, its page model: its editor owner (what shows, of
/// the document's type, seen through the shared [editor] contract) and
/// its file owner (where the edits are kept), joined: each one's events
/// become the other's inputs. Their effects run inside the owners. No UI.
/// [changes] tells of every change of where the edits are ([status],
/// [saveState]) and of [state].
final class DocumentSession {
  /// The document [opened] (`null` for a new one, which goes where
  /// [effects] say), its file read and written by [effects], edited by
  /// [editor], which opened with [opened]'s text.
  DocumentSession(DocumentText? opened, this._effects, this.editor)
    : _file = fileOwner(switch (opened) {
        final opened? => openedFile(opened.seen),
        null => newFile(),
      }, _effects.run) {
    _subscriptions = [
      editor.events.listen(_onEditorEvent),
      editor.changes.listen(_onEditorChanged),
      _file.events.listen(_onFileEvent),
      _file.changes.listen((_) => _changed(), onDone: _onFileStopped),
    ];
  }

  final FileEffects _effects;
  final FileOwner<DocumentVersion> _file;

  /// The way into the editor owner.
  final PageEditor editor;

  late final List<StreamSubscription<Object>> _subscriptions;
  final _editorNotices = StreamController<EditorNotice>.broadcast(sync: true);
  final _fileNotices = StreamController<FileEvent>.broadcast(sync: true);
  final _changes = StreamController<void>.broadcast(sync: true);
  final _stopNotices = StreamController<bool>.broadcast(sync: true);

  /// Whether the editor held edits not yet sent, and the summary it told,
  /// as listeners last heard.
  late ({bool unsent, TextSummary<Object?> summary}) _heard = (
    unsent: false,
    summary: summary,
  );

  /// Whether the document takes edits.
  SessionState get state => _state;
  SessionState _state = const Running();

  /// Where the file is: the file the file owner names, else where a new
  /// document's file goes.
  DocumentFile get file => _effects.whereOf(_file.state.file);

  /// The document's file as last read or written, or where the user moved
  /// it; `null` until a new document's file is created.
  DocumentText? get document => _file.state.file?.read;

  /// Where the document stands against its file.
  FileStatus<DocumentVersion> get status => _file.state.status;

  /// The edits as last sent to be kept, and their rev. Once [Stopped],
  /// its text: the latest edits.
  String get text => switch (_state) {
    Stopped(:final text) => text,
    Running() || Ended() => _file.state.text,
  };
  int get rev => _file.state.rev;

  /// What lists show of [text], as the editor tells it.
  TextSummary<Object?> get summary => editor.state.summary;

  /// Where [file] is, or goes, for [text].
  RelPath get path => switch (file) {
    ExistingFile(:final path) => path,
    final NewFile file => file.pathFor(summary.firstLine),
  };

  /// The document's title, for [text] at [path].
  String get title => titleOf(summary, path);

  SaveState get saveState => saveStateOf(status, unsent: editor.state.unsent);

  /// What the editor tells the user: [UndoOffered], [UndoRefused],
  /// [HistoryEnd].
  Stream<EditorNotice> get editorNotices => _editorNotices.stream;

  /// What the user is told of the file: [Replaced], [PickNotKept].
  Stream<FileEvent> get fileNotices => _fileNotices.stream;

  /// Fires on every change of where the edits are, of where the file is,
  /// and of [state].
  Stream<void> get changes => _changes.stream;

  /// Fires once after the document [Stopped], as it is first known
  /// whether its edits are kept on this device.
  Stream<bool> get stopNotices => _stopNotices.stream;

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

  /// What [contents] know of the file.
  void observe(FolderContents contents) {
    if (document?.key case final key?) {
      if (contents.seenAt(key) case final seenAt?) {
        _file.send(Observed(contents.observe(key), startedAt: seenAt));
      } else {
        // Not listed: what it holds is unknown.
        _file.send(Observed(const Unknown(), startedAt: Moment.now()));
      }
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

  /// Moves or renames the document to [to], with every edit: those not in
  /// its file yet are saved first; how it went.
  Future<Result<DocumentText, MoveFailure>> move(MoveTarget to) async {
    late final Ticket asked;
    await ask<FileInput<DocumentVersion>, MoveAnswer>(
      _file.send,
      _file.events,
      (ticket) {
        asked = ticket;
        _effects.aimMove(ticket, to);
        return Move(ticket);
      },
    );
    return _effects.takeMoveResult(asked) ?? const Err(MoveNotSaved());
  }

  /// The user picked where a new document's file goes.
  void place(NewFile to) {
    _effects.place(to);
    _changed();
  }

  void _onEditorEvent(EditorNotice event) => switch ((event, _state)) {
    (ToFile(input: final Edited edited), Running()) => _file.send(
      _toFile(edited),
    ),
    (ToFile(input: Edited(:final text)), Stopped()) => _keepLastDraft(text),
    (ToFile(:final input), Running()) => _file.send(input),
    (ToFile(), Stopped() || Ended()) => null,
    (UndoOffered() || UndoRefused() || HistoryEnd(), _) => _editorNotices.add(
      event,
    ),
  };

  /// [edited] as the file owner takes it: while the document has no
  /// file, with the name its file gets. The editor told the summary of
  /// [edited]'s text with it.
  FileInput<DocumentVersion> _toFile(Edited edited) => switch (file) {
    NewFile() => NewEdited(edited, name: summary.firstLine),
    ExistingFile() => edited,
  };

  /// The file owner ended before [dispose]: it stopped by a bug. The
  /// edits it holds, and those the editor still holds, are kept as the
  /// draft.
  void _onFileStopped() {
    if (_state is! Running) return;
    _keepLastDraft(_file.state.text);
    // The editor sends what it still holds; [_keepLastDraft] keeps it.
    editor.send(SecureEditor(Ticket(), SecureReason.hide));
  }

  /// Keeps [text], the latest edits, as the draft; only the latest keep's
  /// outcome counts.
  void _keepLastDraft(String text) {
    final known = switch (_state) {
      Stopped(:final kept) => kept,
      Running() || Ended() => null,
    };
    final keeping = Stopped(text, kept: known);
    _setState(keeping);
    unawaited(
      _effects
          .keepLastDraft(text, file: _file.state.file, name: summary.firstLine)
          .then((kept) {
            if (!identical(_state, keeping)) return;
            _setState(Stopped(text, kept: kept));
            if (known == null) _stopNotices.add(kept);
          }),
    );
  }

  void _setState(SessionState state) {
    _state = state;
    _changed();
  }

  /// Edits held in the editor change where the edits are, before they
  /// reach the file owner; a new summary changes the title and path.
  void _onEditorChanged(EditorStatus status) {
    final heard = (unsent: status.unsent, summary: status.summary);
    if (heard.unsent == _heard.unsent &&
        identical(heard.summary, _heard.summary)) {
      return;
    }
    _heard = heard;
    _changed();
  }

  void _onFileEvent(FileEvent event) {
    switch (event) {
      case ToEditor():
        editor.send(FromFile(event));
        if (event is Replaced) _fileNotices.add(event);
      case PickNotKept():
        _fileNotices.add(event);
      case Answer() || MoveAnswer():
        // [ask] hears it.
        break;
    }
  }

  void _changed() {
    if (_state is! Ended) _changes.add(null);
  }

  /// Closes both owners; work under way still ends.
  void dispose() {
    _state = const Ended();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_editorNotices.close());
    unawaited(_fileNotices.close());
    unawaited(_changes.close());
    unawaited(_stopNotices.close());
    unawaited(editor.close());
    unawaited(_file.close());
  }
}

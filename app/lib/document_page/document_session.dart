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

/// One open document: its editor owner (what shows, behind its [gate])
/// and its file owner (where the edits are kept), connected; their
/// effects and timers run here. No UI. Listeners hear of every change of
/// where the edits are ([status], [saveState]); the [gate] tells of
/// changes to what shows.
final class DocumentSession extends ChangeNotifier {
  /// The document whose file [effects] reads and writes; it opens in
  /// [mode], its checked items shown as [checkedItems].
  DocumentSession(
    this._effects, {
    EditMode mode = EditMode.visual,
    CheckedItems checkedItems = CheckedItems.moveToEnd,
  }) : _file = switch (_effects.file) {
         ExistingFile(:final document) => openedFileOwner(document.seen),
         NewFile() => newFileOwner(),
       } {
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
      gate.outputs.listen(_onEditorOutput),
      _file.outputs.listen(_onFileOutput),
    ];
    gate.addListener(_onEditorChanged);
  }

  final FileEffects _effects;
  final FileOwner _file;

  /// The way into the editor owner.
  late final EditorGate gate;

  late final List<StreamSubscription<Object>> _subscriptions;
  final _timers = <Timer>{};
  final _answers = <SecureReason, List<Completer<bool>>>{};
  final _editorNotices = StreamController<EditorOutput>.broadcast(sync: true);
  final _fileNotices = StreamController<FileOutput>.broadcast(sync: true);
  bool _disposed = false;

  /// Whether the editor held edits not yet sent, as listeners last heard.
  bool _unsent = false;

  /// Where the file is.
  DocumentFile get file => _effects.file;

  /// The document's file as last read or written; `null` until a new
  /// document's file is created.
  Document? get document => switch (_effects.file) {
    ExistingFile(:final document) => document,
    NewFile() => null,
  };

  /// Where the document stands against its file.
  FileStatus get status => _file.state.status;

  /// The edits as last sent to be kept, and their rev.
  String get text => _file.state.text;
  int get rev => _file.state.rev;

  SaveState get saveState => saveStateOf(status, unsent: gate.state.unsent);

  /// What the editor asks of the user or tells them: [AskLink],
  /// [UndoOffered], [UndoRefused], [HistoryEnd].
  Stream<EditorOutput> get editorNotices => _editorNotices.stream;

  /// What the user is told of the file: [Replaced], [PickNotKept].
  Stream<FileOutput> get fileNotices => _fileNotices.stream;

  /// Keeps the edits somewhere lasting now, for [reason]; whether they
  /// are kept. A new document's file is created now, unless it is empty.
  Future<bool> secure(SecureReason reason) {
    final answer = Completer<bool>();
    (_answers[reason] ??= []).add(answer);
    gate.send((_) => SecureEditor(reason));
    return answer.future;
  }

  /// Writes the edits kept on this device into the file now; a new
  /// document's file is created, as only securing it does.
  void saveNow() => switch (_effects.file) {
    ExistingFile() => _toFile(const SaveNow()),
    // As when the app hides: kept, and the document stays open.
    NewFile() => unawaited(secure(SecureReason.hide)),
  };

  /// What [scans] found of the file; skipped where they could not see it
  /// (its folder failed, or a subfolder above it was unreadable): not
  /// finding it there says nothing about it.
  void observe(FolderScans scans) {
    final key = document?.key;
    if (key == null || !scans.covers(key)) return;
    _toFile(
      Observed(switch (scans.findNote(key)) {
        final found? => Found(found.seen),
        null => const Gone(),
      }, startedAt: scans.startedAt),
    );
  }

  /// The user's pick between the edits at [rev] and [theirs], as the
  /// compare view showed them.
  void pick(PickChoice choice, {required Seen theirs, required int rev}) =>
      _toFile(Pick(choice, seen: theirs.version, rev: rev));

  /// The document reads [text] instead (a backup restored), as one edit
  /// that undo takes back.
  void replaceAll(String text) =>
      gate.send((now) => ReplaceAll(text, revision: now.revision));

  /// Writes the edits as the file again, after it was deleted elsewhere.
  void restoreMine() => _toFile(const RestoreMine());

  /// Drops the edits that could be kept nowhere.
  void discard() => _toFile(const Discard());

  /// The user moved or renamed the document to [copy].
  void moved(Document copy) {
    _effects.moved(copy);
    _toFile(Moved(copy.seen));
  }

  /// The user picked where a new document's file goes.
  void place(NewFile to) {
    _effects.place(to);
    notifyListeners();
  }

  void _onEditorOutput(EditorOutput output) => switch (output) {
    ToFile(:final input) => _toFile(input),
    StartSaveTimer(:final id, :final delay) => _startTimer(id, delay),
    AskLink() ||
    UndoOffered() ||
    UndoRefused() ||
    HistoryEnd() => _editorNotices.add(output),
  };

  /// Edits held in the editor change where the edits are, before they
  /// reach the file owner.
  void _onEditorChanged() {
    final unsent = gate.state.unsent;
    if (unsent == _unsent) return;
    _unsent = unsent;
    notifyListeners();
  }

  void _onFileOutput(FileOutput output) {
    switch (output) {
      case ToEditor():
        if (output case Replaced(:final version) || Picked(:final version?)) {
          _effects.follow(version);
        }
        gate.external(FromFile(output));
        if (output is Replaced) _fileNotices.add(output);
      case FileEffect():
        unawaited(_run(output));
      case Answer(:final reason, :final kept):
        for (final answer
            in _answers.remove(reason) ?? const <Completer<bool>>[]) {
          answer.complete(kept);
        }
      case PickNotKept():
        _fileNotices.add(output);
    }
  }

  Future<void> _run(FileEffect effect) async {
    final result = await _effects.run(effect);
    if (result != null && !_disposed) _toFile(result);
  }

  void _startTimer(int id, Duration delay) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      gate.external(SaveTimerFired(id));
    });
    _timers.add(timer);
  }

  void _toFile(FileInput input) {
    _file.send(input);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_editorNotices.close());
    unawaited(_fileNotices.close());
    gate
      ..removeListener(_onEditorChanged)
      ..dispose();
    super.dispose();
  }
}

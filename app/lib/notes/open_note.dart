import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/note_folder.dart';
import 'new_note_session.dart';
import 'note.dart';
import 'note_edit_session.dart';
import 'note_text.dart';

/// The note open in the editor, new or with a file: a new note is kept by
/// a [NewNoteSession] until its first write creates the file, then by a
/// [NoteEditSession], as a note opened from its file is. No UI. Listeners
/// hear of every change of either.
final class OpenNote extends ChangeNotifier implements NoteText {
  /// [sessionOf] starts the session of a note this app just wrote.
  OpenNote(NoteEditSession session, {required this.sessionOf})
    : _session = session {
    session.addListener(notifyListeners);
  }

  OpenNote.fresh(NewNoteSession pending, {required this.sessionOf})
    : _pending = pending {
    pending.addListener(notifyListeners);
  }

  final NoteEditSession Function(Note note) sessionOf;

  // Exactly one of them is set.
  NewNoteSession? _pending;
  NoteEditSession? _session;

  Future<bool> _creating = Future.value(true);

  /// Set until the note's file is created.
  NewNoteSession? get pending => _pending;

  /// Set once the note has its file.
  NoteEditSession? get session => _session;

  /// The note's file as last read or written; `null` until it is created.
  Note? get note => _session?.note;

  NoteFolder get folder => _session?.note.folder ?? _pending!.place.folder;

  /// The note's file in [folder]; for a new note, where it goes.
  RelPath get path => _session?.note.path ?? _pending!.path;

  @override
  String get text => _session?.text ?? _pending!.text;

  EditState get state => _session?.state ?? _pending!.state;

  @override
  void edit(String text) {
    if (_session case final session?) return session.edit(text);
    _pending!.edit(text);
  }

  /// Writes pending edits into the file now; a new note's file is created.
  Future<void> flush() async {
    if (_session case final session?) return session.flush();
    await _create();
  }

  /// Keeps the edits, see [NoteEditSession.secure]; a new note's file is
  /// created first. Returns `false` if they could not go into the folder.
  Future<bool> secure() async {
    if (!await _create()) return false;
    return await _session?.secure() ?? true;
  }

  /// Drops edits that could be kept nowhere, when the user chose so; a new
  /// note is dropped.
  void discard() {
    if (_session case final session?) return session.discard();
    _pending!.discard();
  }

  /// The note was moved or renamed to [copy], with every edit kept there:
  /// edits go on in it.
  void moved(Note copy) {
    final old = _session!;
    final text = old.text;
    old
      ..removeListener(notifyListeners)
      ..discard()
      ..dispose();
    _start(copy, text: text);
  }

  /// Creates a new note's file, once at a time; `true` if it has one, or
  /// is empty, so there is nothing to write.
  Future<bool> _create() => _creating = _creating.then((_) async {
    final pending = _pending;
    if (pending == null) return true;
    switch (await pending.write()) {
      case Ok(value: final note?):
        final text = pending.text;
        _pending = null;
        pending
          ..removeListener(notifyListeners)
          ..dispose();
        _start(note, text: text);
        return true;
      case Ok():
        return true;
      case Err():
        return false;
    }
  });

  /// Edits [note] on, holding [text]: the edits since it was written.
  void _start(Note note, {required String text}) {
    final session = sessionOf(note)..addListener(notifyListeners);
    _session = session;
    if (text != note.file.text) session.edit(text);
    notifyListeners();
  }

  @override
  void dispose() {
    _pending?.dispose();
    _session?.dispose();
    super.dispose();
  }
}

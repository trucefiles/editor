import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/note_folder.dart';
import 'note.dart';
import 'note_edit_session.dart';
import 'note_file_name.dart';
import 'note_place.dart';
import 'note_staging.dart';
import 'note_text.dart';
import 'note_title.dart';

/// Creates a note's file holding [text] at [place], named after [title].
typedef CreateNote = Future<Result<Note, StoreError>> Function(
  NotePlace place, {
  required String title,
  required String text,
});

/// A new note before its first write: its text, place and name stay on
/// this device until [write] creates its file, as the user leaves it or
/// the app is hidden. Nothing is due before that: only the user's own
/// action writes into the folder. An empty note is never written. No UI.
///
/// Its draft survives the app being ended; the next start creates the file
/// (see `DraftRecovery`).
final class NewNoteSession extends ChangeNotifier implements NoteText {
  /// [stagingOf] keeps drafts in a folder's store; [saveDelay]: how long
  /// after the last edit the text is kept on the device.
  NewNoteSession(
    this._place, {
    required NoteStaging Function(NoteFolder folder) stagingOf,
    required this._create,
    this.saveDelay = const Duration(seconds: 2),
  }) : _stagingOf = stagingOf,
       _staging = stagingOf(_place.folder);

  final NoteStaging Function(NoteFolder folder) _stagingOf;
  final CreateNote _create;
  final Duration saveDelay;

  NoteStaging _staging;
  NotePlace _place;
  String _text = '';
  String? _name;
  EditState _state = EditState.saved;
  Timer? _timer;

  NotePlace get place => _place;

  @override
  String get text => _text;

  /// [EditState.saved] while there is nothing to keep, else
  /// [EditState.unsaved], [EditState.savedOnDevice] or, after a failed
  /// [write], [EditState.saveFailed].
  EditState get state => _state;

  /// The file's name without its extension: the one the user set, else the
  /// words of the first line.
  String get title => _name ?? noteTitleLine(_text);

  /// Where the file goes; a number is added if the name is taken then.
  RelPath get path {
    final name = noteFileName(title);
    return _place.subfolder?.child(name) ?? RelPath.parse(name)!;
  }

  bool get _isEmpty => _text.trim().isEmpty;

  /// The user changed the text; keeps it on the device after [saveDelay]
  /// without edits. Once empty again, there is nothing to keep.
  @override
  void edit(String text) {
    if (text == _text) return;
    _text = text;
    _timer?.cancel();
    if (_isEmpty) {
      _staging.drop();
      return _set(EditState.saved);
    }
    _timer = Timer(saveDelay, _stash);
    if (_state != EditState.unsaved) return _set(EditState.unsaved);
    notifyListeners();
  }

  /// The user picked [place] and [title] for the file. An empty [title]
  /// lets the name follow the first line again; the one shown keeps it as
  /// it is.
  void moveTo(NotePlace place, {required String title}) {
    if (place.folder.id != _place.folder.id) {
      _staging
        ..drop()
        ..dispose();
      _staging = _stagingOf(place.folder);
    }
    _place = place;
    final picked = title.trim();
    if (picked.isEmpty) {
      _name = null;
    } else if (picked != this.title) {
      _name = picked;
    }
    notifyListeners();
    if (!_isEmpty) unawaited(_keepDraft());
  }

  /// Creates the file and drops the draft; `Ok(null)` if the note is
  /// empty: it is never written. On failure the text stays kept on this
  /// device.
  Future<Result<Note?, StoreError>> write() async {
    _timer?.cancel();
    if (_isEmpty) return const Ok(null);
    final created = await _create(_place, title: title, text: _text);
    switch (created) {
      case Ok():
        _staging.drop();
      case Err():
        await _keepDraft();
        _set(EditState.saveFailed);
    }
    return created;
  }

  /// Drops the note, when the user chose so.
  void discard() {
    _timer?.cancel();
    _text = '';
    _staging.drop();
    _set(EditState.saved);
  }

  Future<void> _stash() async {
    final text = _text;
    if (await _keepDraft() && text == _text && _state == EditState.unsaved) {
      _set(EditState.savedOnDevice);
    }
  }

  Future<bool> _keepDraft() => _staging.keep(path, base: null, text: _text);

  void _set(EditState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _staging.dispose();
    super.dispose();
  }
}

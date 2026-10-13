import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import 'note.dart';
import 'note_files.dart';

/// Where an open note stands against its file.
enum EditState {
  /// The file holds the text being edited.
  saved,

  /// Edits are waiting for or in their save.
  unsaved,

  /// The file changed elsewhere while there were unsaved edits; the user
  /// picks [NoteEditSession.keepMine] or [NoteEditSession.loadTheirs].
  changedElsewhere,

  /// The file was deleted elsewhere. Nothing is saved until the user
  /// picks [NoteEditSession.restoreMine] or closes the note.
  deletedElsewhere,

  /// Saving failed for another reason (e.g. no access); edits are kept.
  saveFailed,
}

/// Saves the text of one open note shortly after the user stops typing and
/// keeps it in step with changes from elsewhere. No UI. Listeners hear of
/// every change to [text] or [state].
///
/// Never overwrites a change from elsewhere and never recreates a deleted
/// file without the user's choice.
final class NoteEditSession extends ChangeNotifier {
  NoteEditSession(this._note, this._files, {this.saveDelay = _defaultDelay})
    : _text = _note.file.text;

  static const _defaultDelay = Duration(seconds: 2);

  final NoteFiles _files;
  final Duration saveDelay;

  Note _note;
  String _text;
  EditState _state = EditState.saved;
  Note? _theirs;
  Timer? _timer;
  Future<void>? _saving;
  bool _writing = false;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  /// The version the edits are based on; its stamp guards the next save.
  Note get note => _note;

  String get text => _text;

  EditState get state => _state;

  /// The user changed the text; saves after [saveDelay] without edits.
  void edit(String text) {
    if (text == _text) return;
    _text = text;
    if (_state == EditState.saved || _state == EditState.saveFailed) {
      _state = EditState.unsaved;
    }
    notifyListeners();
    _timer?.cancel();
    if (_state == EditState.unsaved) _timer = Timer(saveDelay, _save);
  }

  /// Saves pending edits now, e.g. when the editor closes.
  Future<void> flush() async {
    _timer?.cancel();
    await _save();
  }

  /// A rescan that started at [scannedAt] found [latest] for this note;
  /// `null` if the file is gone. Ignored while this session writes, and
  /// for scans that started before its last write: they may hold the old
  /// version.
  ///
  /// Returns `true` if [text] was replaced by the latest file content.
  bool onRescan(Note? latest, {required DateTime scannedAt}) {
    if (_writing || scannedAt.isBefore(_lastWrite)) return false;
    if (latest == null) {
      _goneElsewhere();
      return false;
    }
    if (latest.stamp == _note.stamp) return false;
    if (_isRestamped(latest)) {
      _note = latest;
      return false;
    }
    if (_state == EditState.saved) {
      _note = latest;
      _text = latest.file.text;
      notifyListeners();
      return true;
    }
    _theirs = latest;
    if (_state == EditState.unsaved) _set(EditState.changedElsewhere);
    return false;
  }

  /// Overwrites the version from elsewhere with the text being edited.
  Future<void> keepMine() async {
    final theirs = _theirs ?? await _reload();
    if (theirs == null) return;
    _note = theirs;
    _theirs = null;
    _set(EditState.unsaved);
    await flush();
  }

  /// Drops the edits and shows the version from elsewhere.
  void loadTheirs() {
    _timer?.cancel();
    if (_theirs case final theirs?) {
      _note = theirs;
      _text = theirs.file.text;
    }
    _theirs = null;
    _set(EditState.saved);
  }

  /// Writes the text being edited as the note's file again, after it was
  /// deleted elsewhere.
  Future<void> restoreMine() async {
    final text = _text;
    switch (await _write(() => _files.restore(_note, text))) {
      case Ok(value: final restored):
        _note = restored;
        _set(text == _text ? EditState.saved : EditState.unsaved);
        if (_state == EditState.unsaved) await flush();
      case Err(error: StoreError.alreadyExists):
        _theirs = await _reload();
        if (_theirs != null) _set(EditState.changedElsewhere);
      case Err():
        _set(EditState.saveFailed);
    }
  }

  Future<void> _save() {
    final previous = _saving ?? Future<void>.value();
    return _saving = previous.then((_) => _saveOnce());
  }

  /// [retried] after the file turned out to be only restamped, so a stamp
  /// that keeps changing cannot loop.
  Future<void> _saveOnce({bool retried = false}) async {
    if (_state != EditState.unsaved && _state != EditState.saveFailed) return;
    final text = _text;
    switch (await _write(() => _files.save(_note, text))) {
      case Ok(value: final saved):
        _note = saved;
        if (text == _text) _set(EditState.saved);
      case Err(error: StoreError.notFound):
        _goneElsewhere();
      case Err(error: StoreError.changedSinceRead):
        final theirs = await _reload();
        if (theirs == null) return;
        if (!retried && _isRestamped(theirs)) {
          _note = theirs;
          return _saveOnce(retried: true);
        }
        _theirs = theirs;
        _set(EditState.changedElsewhere);
      case Err():
        _set(EditState.saveFailed);
    }
  }

  /// Whether [latest] has a new stamp but the same text as [note]: not a
  /// change from elsewhere. Some file systems (e.g. Android's shared
  /// storage) report a stale stamp right after a write and the real one
  /// a moment later.
  bool _isRestamped(Note latest) => latest.file.text == _note.file.text;

  /// Runs one write, marking it so rescans in the meantime are ignored.
  Future<Result<Note, StoreError>> _write(
    Future<Result<Note, StoreError>> Function() write,
  ) async {
    _writing = true;
    _lastWrite = DateTime.now();
    try {
      return await write();
    } finally {
      _writing = false;
    }
  }

  /// The current version from elsewhere; `null` if the file is gone, in
  /// which case the state says so.
  Future<Note?> _reload() async {
    switch (await _files.reload(_note)) {
      case Ok(:final value):
        return value;
      case Err(error: StoreError.notFound):
        _goneElsewhere();
      case Err():
        _set(EditState.saveFailed);
    }
    return null;
  }

  void _goneElsewhere() {
    _timer?.cancel();
    _theirs = null;
    if (_state != EditState.deletedElsewhere) _set(EditState.deletedElsewhere);
  }

  void _set(EditState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

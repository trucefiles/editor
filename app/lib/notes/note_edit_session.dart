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

  /// Edits that could not go into the file were kept as a conflict copy
  /// by [NoteEditSession.secure]. The session is done.
  keptAsConflict,
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
    if (text == _text || _state == EditState.keptAsConflict) return;
    _text = text;
    if (_state == EditState.saved || _state == EditState.saveFailed) {
      _state = EditState.unsaved;
    }
    notifyListeners();
    _timer?.cancel();
    if (_state == EditState.unsaved) _timer = Timer(saveDelay, _save);
  }

  /// Saves pending edits now.
  Future<void> flush() async {
    _timer?.cancel();
    await _save();
  }

  /// Saves pending edits, or keeps them as a conflict copy if they cannot
  /// go into the file (changed or deleted elsewhere, or saving failed), so
  /// nothing is left only in memory. For when the editor closes or the app
  /// is hidden and may be ended. Returns `false` if the edits could be kept
  /// nowhere.
  Future<bool> secure() {
    _timer?.cancel();
    final secured = (_saving ?? Future<void>.value()).then(
      (_) => _secureOnce(),
    );
    _saving = secured;
    return secured;
  }

  Future<bool> _secureOnce() async {
    await _saveOnce();
    switch (_state) {
      case EditState.saved || EditState.keptAsConflict:
        return true;
      case EditState.unsaved:
        // Edited during the save: save that too.
        return _secureOnce();
      case EditState.deletedElsewhere when _text == _note.file.text:
        // No edits: nothing to keep.
        return true;
      case EditState.changedElsewhere ||
          EditState.deletedElsewhere ||
          EditState.saveFailed:
        if (await _files.saveAsConflict(_note, _text) is Err) return false;
        _timer?.cancel();
        _theirs = null;
        _set(EditState.keptAsConflict);
        return true;
    }
  }

  /// A rescan that started at [scannedAt] found [latest] for this note;
  /// `null` if the file is gone. Ignored while this session writes, and
  /// for scans that started before its last write ended: they may hold
  /// the old version.
  ///
  /// Returns `true` if [text] was replaced by the latest file content.
  bool onRescan(Note? latest, {required DateTime scannedAt}) {
    if (_writing ||
        scannedAt.isBefore(_lastWrite) ||
        _state == EditState.keptAsConflict) {
      return false;
    }
    if (latest == null) {
      _goneElsewhere();
      return false;
    }
    if (_state == EditState.deletedElsewhere) {
      _cameBack(latest);
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
    try {
      return await write();
    } finally {
      _writing = false;
      // A scan that started during the write may have listed the old
      // version and still be running; it must be ignored too.
      _lastWrite = DateTime.now();
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

  /// The file is back after it looked deleted: in step if it holds [text];
  /// saving again if it is the version the edits are based on; else a
  /// change from elsewhere.
  void _cameBack(Note latest) {
    if (latest.file.text == _text) {
      _note = latest;
      _set(EditState.saved);
    } else if (latest.stamp == _note.stamp) {
      _set(EditState.unsaved);
      _timer = Timer(saveDelay, _save);
    } else {
      _theirs = latest;
      _set(EditState.changedElsewhere);
    }
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

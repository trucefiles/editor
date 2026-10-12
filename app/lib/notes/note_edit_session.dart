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

  /// Saving failed for another reason (e.g. no access); edits are kept.
  saveFailed,
}

/// Saves the text of one open note shortly after each edit and keeps it in
/// step with changes from elsewhere. No UI.
///
/// A file deleted elsewhere is written again on the next save, so typed
/// text is never lost.
final class NoteEditSession extends ChangeNotifier {
  NoteEditSession(this._note, this._files, {this.saveDelay = _defaultDelay})
    : _text = _note.file.text;

  static const _defaultDelay = Duration(milliseconds: 800);

  final NoteFiles _files;
  final Duration saveDelay;

  Note _note;
  String _text;
  EditState _state = EditState.saved;
  Note? _theirs;
  Timer? _timer;
  Future<void>? _saving;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  /// The version the edits are based on; its stamp guards the next save.
  Note get note => _note;

  String get text => _text;

  EditState get state => _state;

  /// The user changed the text; saves after [saveDelay] without edits.
  void edit(String text) {
    if (text == _text) return;
    _text = text;
    if (_state != EditState.changedElsewhere) _set(EditState.unsaved);
    _timer?.cancel();
    _timer = Timer(saveDelay, _save);
  }

  /// Saves pending edits now, e.g. when the editor closes.
  Future<void> flush() async {
    _timer?.cancel();
    await _save();
  }

  /// A rescan that started at [scannedAt] found [latest] for this note;
  /// `null` if it is gone. Scans that started before this session's last
  /// write may hold the old version and are ignored.
  ///
  /// Returns `true` if [text] was replaced by the latest file content.
  bool onRescan(Note? latest, {required DateTime scannedAt}) {
    if (latest == null ||
        latest.stamp == _note.stamp ||
        scannedAt.isBefore(_lastWrite)) {
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
    if (_theirs case final theirs?) _note = theirs;
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

  Future<void> _save() {
    final previous = _saving ?? Future<void>.value();
    return _saving = previous.then((_) => _saveOnce());
  }

  Future<void> _saveOnce() async {
    if (_state != EditState.unsaved && _state != EditState.saveFailed) return;
    final text = _text;
    _lastWrite = DateTime.now();
    final written = await _files.save(_note, text);
    final result = switch (written) {
      Err(error: StoreError.notFound) => await _files.restore(_note, text),
      _ => written,
    };
    switch (result) {
      case Ok(value: final saved):
        _note = saved;
        if (text == _text) _set(EditState.saved);
      case Err(error: StoreError.changedSinceRead):
        if (await _files.reload(_note) case Ok(value: final theirs)) {
          _theirs = theirs;
        }
        _set(EditState.changedElsewhere);
      case Err():
        _set(EditState.saveFailed);
    }
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

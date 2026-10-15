import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import 'note.dart';
import 'note_drafts.dart';
import 'note_files.dart';
import 'note_staging.dart';

/// Where an open note stands against its file.
enum EditState {
  /// The file holds the text being edited.
  saved,

  /// Edits are kept on this device; they go into the file when the note
  /// closes, the app is hidden, or a while after they were first kept.
  savedOnDevice,

  /// Edits are waiting to be kept on this device, or are being saved.
  unsaved,

  /// The file changed elsewhere while there were unsaved edits; the user
  /// picks [NoteEditSession.keepMine] or [NoteEditSession.loadTheirs].
  changedElsewhere,

  /// The file was deleted elsewhere. Nothing is saved until the user
  /// picks [NoteEditSession.restoreMine] or closes the note.
  deletedElsewhere,

  /// Saving failed for another reason (e.g. no access); edits are kept.
  saveFailed,

  /// Edits that could not go into the file are kept as a conflict copy
  /// by [NoteEditSession.secure]. Set as the copy is written, so no edit
  /// can slip past it. The session is done: it takes no more edits.
  keptAsConflict,
}

/// Keeps the text of one open note on this device shortly after the user
/// stops typing, writes it into the note's file less often, and keeps it in
/// step with changes from elsewhere. No UI. Listeners hear of every change
/// to [text] or [state].
///
/// Edits kept on the device survive the app being ended; the next start
/// puts them into the file (see `DraftRecovery`). Writing the file less
/// often puts less load on the sync tool.
///
/// Never overwrites a change from elsewhere and never recreates a deleted
/// file without the user's choice.
final class NoteEditSession extends ChangeNotifier {
  /// [publishDelay]: how long after edits were first kept on the device
  /// they go into the file at the latest, for a note that stays open.
  NoteEditSession(
    this._note,
    this._files,
    NoteDrafts drafts, {
    this.saveDelay = const Duration(seconds: 2),
    Duration publishDelay = const Duration(minutes: 1),
  }) : _text = _note.file.text {
    _staging = NoteStaging(
      drafts,
      publishDelay: publishDelay,
      onDue: () => unawaited(_save()),
    );
  }

  final NoteFiles _files;
  late final NoteStaging _staging;

  /// How long after the last edit the edits are kept on the device.
  final Duration saveDelay;

  Note _note;
  String _text;
  EditState _state = EditState.saved;
  Note? _theirs;
  Timer? _timer;
  Future<void>? _saving;
  bool _writing = false;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  /// The version the edits are based on; it guards the next save.
  Note get note => _note;

  String get text => _text;

  EditState get state => _state;

  /// The version from elsewhere the user picks against, while
  /// [EditState.changedElsewhere].
  Note? get theirs => _theirs;

  /// The user changed the text; keeps it on the device after [saveDelay]
  /// without edits.
  void edit(String text) {
    if (text == _text || _state == EditState.keptAsConflict) return;
    _text = text;
    if (_state == EditState.saved ||
        _state == EditState.savedOnDevice ||
        _state == EditState.saveFailed) {
      _state = EditState.unsaved;
    }
    notifyListeners();
    _timer?.cancel();
    if (_state == EditState.unsaved) _timer = Timer(saveDelay, _stash);
  }

  /// Writes pending edits into the file now.
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
      case EditState.unsaved || EditState.savedOnDevice:
        // Edited during the save: save that too.
        return _secureOnce();
      case EditState.deletedElsewhere when _text == _note.file.text:
        // No edits: nothing to keep.
        _staging.drop();
        return true;
      case EditState.changedElsewhere ||
          EditState.deletedElsewhere ||
          EditState.saveFailed:
        if (await _keepAsConflict()) return true;
        // Kept on the device at least: the next start tries again.
        await _keepDraft(_text);
        return false;
    }
  }

  Future<bool> _keepAsConflict() async {
    final before = _state;
    _timer?.cancel();
    _set(EditState.keptAsConflict);
    if (await _files.saveAsConflict(_note, _text) is Err) {
      _set(before);
      return false;
    }
    _theirs = null;
    _settle(EditState.keptAsConflict);
    return true;
  }

  /// Drops edits that could be kept nowhere, when the user chose so: the
  /// text goes back to the file's.
  void discard() {
    _text = _note.file.text;
    _theirs = null;
    _settle(EditState.saved);
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
    if (latest.version == _note.version) return false;
    if (_isRestamped(latest)) {
      _note = latest;
      return false;
    }
    if (_holdsText(latest)) {
      _inStepWith(latest);
      return false;
    }
    if (_state == EditState.saved) {
      _note = latest;
      _text = latest.file.text;
      notifyListeners();
      return true;
    }
    _theirs = latest;
    if (_state == EditState.unsaved || _state == EditState.savedOnDevice) {
      _set(EditState.changedElsewhere);
    } else if (_state == EditState.changedElsewhere) {
      // The user must pick against the newest version.
      notifyListeners();
    }
    return false;
  }

  /// Overwrites the version from elsewhere with the text being edited,
  /// after a backup of both. `false` if no backup could be made: nothing
  /// changed.
  Future<bool> keepMine() async {
    final theirs = _theirs ?? await _reload();
    if (theirs == null) return true;
    if (!await _backUp(theirs)) return false;
    // Settled meanwhile, e.g. the file came back to the edits.
    if (_state != EditState.changedElsewhere) return true;
    // The backed-up version: if a newer one came meanwhile, saving over
    // it fails and asks again, so no version is lost unseen.
    _note = theirs;
    _theirs = null;
    _set(EditState.unsaved);
    await flush();
    return true;
  }

  /// Drops the edits and shows the version from elsewhere, after a backup
  /// of both. `false` if no backup could be made: nothing changed.
  Future<bool> loadTheirs() async {
    if (_theirs case final theirs?) {
      if (!await _backUp(theirs)) return false;
      if (_state != EditState.changedElsewhere) return true;
      // The newest version from elsewhere, which may have come meanwhile.
      final latest = _theirs ?? theirs;
      _note = latest;
      _text = latest.file.text;
    }
    _theirs = null;
    _settle(EditState.saved);
    return true;
  }

  Future<bool> _backUp(Note theirs) async =>
      await _files.backUp(theirs, _text) is Ok;

  /// Writes the text being edited as the note's file again, after it was
  /// deleted elsewhere.
  Future<void> restoreMine() async {
    final text = _text;
    switch (await _write(() => _files.restore(_note, text))) {
      case Ok(value: final restored):
        _note = restored;
        if (text == _text) {
          _settle(EditState.saved);
        } else {
          _set(EditState.unsaved);
          await flush();
        }
      case Err(error: StoreError.alreadyExists):
        _theirs = await _reload();
        if (_theirs != null) _set(EditState.changedElsewhere);
      case Err():
        _set(EditState.saveFailed);
    }
  }

  /// Keeps the edits on the device; they go into the file when due. Writes
  /// the file right away if the device cannot keep them.
  Future<void> _stash() async {
    if (_state != EditState.unsaved) return;
    final text = _text;
    if (!await _keepDraft(text)) return _save();
    if (_state == EditState.unsaved && text == _text) {
      _set(EditState.savedOnDevice);
    }
  }

  /// Writes the edits into the file.
  Future<void> _save() {
    final previous = _saving ?? Future<void>.value();
    return _saving = previous.then((_) => _saveOnce());
  }

  /// [retried] after the file turned out to be only restamped, so a
  /// version that keeps changing cannot loop.
  Future<void> _saveOnce({bool retried = false}) async {
    if (_state != EditState.unsaved &&
        _state != EditState.savedOnDevice &&
        _state != EditState.saveFailed) {
      return;
    }
    final text = _text;
    switch (await _write(() => _files.save(_note, text))) {
      case Ok(value: final saved):
        _note = saved;
        if (text == _text) _settle(EditState.saved);
      case Err(error: StoreError.notFound):
        _goneElsewhere();
      case Err(error: StoreError.changedSinceRead):
        final theirs = await _reload();
        if (theirs == null) return;
        if (!retried && _isRestamped(theirs)) {
          _note = theirs;
          return _saveOnce(retried: true);
        }
        if (_holdsText(theirs)) return _inStepWith(theirs);
        _theirs = theirs;
        _set(EditState.changedElsewhere);
      case Err():
        _set(EditState.saveFailed);
    }
  }

  /// Whether [latest] is a new version but holds the same text as [note]:
  /// not a change from elsewhere. Some file systems (e.g. Android's shared
  /// storage) report stale file times right after a write and the real
  /// ones a moment later.
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
  /// shown as is if there are no edits; saving again if it is the version
  /// the edits are based on; else a change from elsewhere.
  void _cameBack(Note latest) {
    if (_holdsText(latest)) {
      _inStepWith(latest);
    } else if (_text == _note.file.text) {
      _note = latest;
      _text = latest.file.text;
      _settle(EditState.saved);
    } else if (latest.version == _note.version) {
      _set(EditState.unsaved);
      _timer = Timer(saveDelay, _stash);
    } else {
      _theirs = latest;
      _set(EditState.changedElsewhere);
    }
  }

  /// Whether [latest] holds exactly the text being edited: nothing to
  /// save or ask.
  bool _holdsText(Note latest) => latest.file.text == _text;

  void _inStepWith(Note latest) {
    _note = latest;
    _theirs = null;
    _settle(EditState.saved);
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

  /// No edits are pending any more: in the file, in a conflict copy, or
  /// dropped.
  void _settle(EditState state) {
    _timer?.cancel();
    _staging.drop();
    _set(state);
  }

  Future<bool> _keepDraft(String text) =>
      _staging.keep(_note.path, base: _note.file.text, text: text);

  @override
  void dispose() {
    _timer?.cancel();
    _staging.dispose();
    super.dispose();
  }
}

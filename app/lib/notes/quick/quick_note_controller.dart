import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/debouncer.dart';
import '../../folders/note_folder.dart';
import '../note.dart';
import '../note_actions.dart';
import '../note_place.dart';
import 'quick_note_draft.dart';
import 'quick_note_place.dart';

/// One quick note being written: its text and place stay on this device
/// (see [QuickNoteDrafts]) until [file] puts it into a folder. No UI.
///
/// Continues a quick note left from before, e.g. when the app was ended
/// while it was open.
final class QuickNoteController extends ChangeNotifier {
  QuickNoteController(this._drafts, this._actions);

  final QuickNoteDrafts _drafts;
  final NoteActions _actions;

  late final _keeper = Debouncer(
    _keepNow,
    settle: const Duration(milliseconds: 300),
    maxWait: const Duration(seconds: 2),
  );

  String _text = '';
  QuickNotePlace? _picked;
  Future<void> _kept = Future.value();

  /// In a folder, or dropped: nothing to keep any more.
  bool _filed = false;

  String get text => _text;

  /// Loads the quick note left from before, if any; returns its text.
  Future<String> start() async {
    if (await _drafts.load() case final draft?) {
      _text = draft.text;
      _picked = draft.place;
      notifyListeners();
    }
    return _text;
  }

  /// Where the note goes among [folders]: the place picked for it, else
  /// the place for new notes.
  NotePlace placeAmong(List<NoteFolder> folders) =>
      resolveQuickNotePlace(_picked, folders, _actions.subfoldersOf) ??
      _actions.newNotePlace(folders);

  void edit(String text) {
    if (text == _text) return;
    _text = text;
    _keeper();
  }

  void pick(NotePlace place) {
    _picked = (folderId: place.folder.id, subfolder: place.subfolder);
    _keeper();
    notifyListeners();
  }

  /// Keeps the note on this device now, e.g. as the app is hidden.
  Future<void> secure() {
    _keeper.cancel();
    return _keepNow();
  }

  /// Puts the note into its place among [folders] and drops it from this
  /// device; a note with only whitespace is just dropped (`Ok(null)`). On
  /// failure it stays on this device.
  Future<Result<Note?, StoreError>> file(List<NoteFolder> folders) async {
    await secure();
    if (_text.trim().isEmpty) {
      _filed = true;
      await _drafts.remove();
      return const Ok(null);
    }
    final created = await _actions.create(placeAmong(folders), text: _text);
    if (created is Ok) {
      _filed = true;
      await _drafts.remove();
    }
    return created;
  }

  /// Keeps the text and place, after the keep before, so the last one
  /// lands last.
  Future<void> _keepNow() => _kept = _kept.then((_) async {
    if (_filed) return;
    await _drafts.keep(QuickNoteDraft(text: _text, place: _picked));
  });

  /// Keeps what is not kept yet, unless the note is filed.
  @override
  void dispose() {
    _keeper.cancel();
    unawaited(_keepNow());
    super.dispose();
  }
}

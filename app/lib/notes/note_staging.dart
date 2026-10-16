import 'dart:async';

import 'package:truce_core/truce_core.dart';

import 'note_draft.dart';
import 'note_drafts.dart';

/// Keeps one open note's edits on this device until they are in the
/// note's file, and calls [onDue] when they should go into the file. One
/// per edit session; its draft writes run in order.
final class NoteStaging {
  NoteStaging(this._drafts, {required this.publishDelay, required this.onDue});

  final NoteDrafts _drafts;

  /// How long after edits were first kept [onDue] is called, unless they
  /// are dropped first.
  final Duration publishDelay;

  final void Function() onDue;

  final _id = NoteDraft.newId();
  bool _kept = false;
  Timer? _due;
  final _work = TaskQueue();

  /// Keeps [text] of the note at [path], edited from the file's [base]
  /// text; `false` if it could not be written.
  Future<bool> keep(
    RelPath path, {
    required String base,
    required String text,
  }) {
    _kept = true;
    final kept = _work.run(
      () =>
          _drafts.keep(NoteDraft(id: _id, path: path, base: base, text: text)),
    );
    return kept.then((written) {
      // Not if dropped meanwhile.
      if (written && _kept) {
        _due ??= Timer(publishDelay, () {
          _due = null;
          onDue();
        });
      }
      return written;
    });
  }

  /// The edits are in the file, in a conflict copy, or dropped: removes
  /// the draft.
  void drop() {
    _cancelDue();
    if (!_kept) return;
    _kept = false;
    unawaited(_work.run(() => _drafts.remove(_id)));
  }

  void dispose() => _cancelDue();

  void _cancelDue() {
    _due?.cancel();
    _due = null;
  }
}

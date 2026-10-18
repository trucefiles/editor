import 'dart:async';

import 'package:pool/pool.dart';
import 'package:truce_core/truce_core.dart';

import 'note_draft.dart';
import 'note_drafts.dart';

/// Keeps one open note's edits on this device until they are in the
/// note's file, and calls `onDue` when they should go into the file. One
/// per edit session; its draft writes run in order.
final class NoteStaging {
  /// [publishDelay]: how long after edits were first kept [onDue] is
  /// called, unless they are dropped first.
  NoteStaging(
    this._drafts, {
    required Duration publishDelay,
    required void Function() onDue,
  }) : _publish = (delay: publishDelay, onDue: onDue);

  /// For a new note: its edits wait for the user's first write, so
  /// nothing is ever due.
  NoteStaging.unpublished(this._drafts) : _publish = null;

  final NoteDrafts _drafts;
  final ({Duration delay, void Function() onDue})? _publish;

  final _id = NoteDraft.newId();
  bool _kept = false;
  Timer? _due;
  final _work = Pool(1);

  /// Keeps [text] of the note at [path], edited from the file's [base]
  /// text (`null` for a new note); `false` if it could not be written.
  Future<bool> keep(
    RelPath path, {
    required String? base,
    required String text,
  }) {
    _kept = true;
    final kept = _work.withResource(
      () =>
          _drafts.keep(NoteDraft(id: _id, path: path, base: base, text: text)),
    );
    return kept.then((written) {
      // Not if dropped meanwhile.
      if ((written && _kept, _publish) case (true, final publish?)) {
        _due ??= Timer(publish.delay, () {
          _due = null;
          publish.onDue();
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
    unawaited(_work.withResource(() => _drafts.remove(_id)));
  }

  void dispose() => _cancelDue();

  void _cancelDue() {
    _due?.cancel();
    _due = null;
  }
}

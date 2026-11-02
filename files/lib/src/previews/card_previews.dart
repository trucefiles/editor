import 'dart:async';

import '../file_card_summary.dart';
import '../listed_file.dart';
import 'card_preview.dart';

/// Reads what cards show of files' texts, only for the cards that ask,
/// and keeps the newest [capacity] of them, so memory stays small however
/// many files the folders hold. A preview is kept only as long as its
/// type says it holds ([FileCardSummary.holdsUntil]), as [now] tells.
///
/// Reads at most [readsAtOnce] files at a time; of the cards waiting, the
/// one that asked last is read first, as it is the most likely on screen.
/// A card that goes away drops its waiting read. Own code: a pool of
/// package:pool can't drop or reorder work that waits.
final class CardPreviews {
  CardPreviews(
    this._read, {
    this.capacity = 500,
    this.readsAtOnce = 4,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Reads one file's preview; never throws.
  final Future<CardPreview> Function(ListedFile file) _read;

  final DateTime Function() _now;

  final int capacity;
  final int readsAtOnce;

  /// The previews read, one per file (its newest version read), the one
  /// used last at the end.
  final _known = <FileKey, ({ListedFile file, CardPreview preview})>{};

  /// The reads asked for and not started, the one asked last at the end.
  final _waiting = <ListedFile, Completer<CardPreview>>{};

  final _running = <ListedFile, Future<CardPreview>>{};

  /// [file]'s preview if it was read and still holds; marks its file
  /// as used.
  CardPreview? known(ListedFile file) => switch (_known.remove(file.key)) {
    final read? =>
      (_known[file.key] = read).file == file &&
              holdsFor(read.preview) != Duration.zero
          ? read.preview
          : null,
    null => null,
  };

  /// How much longer [preview] holds, as its type says; `null` while its
  /// text doesn't change; [Duration.zero] once it no longer holds.
  Duration? holdsFor(CardPreview preview) => switch (preview) {
    Previewed(summary: FileCardSummary(:final holdsUntil?)) =>
      switch (holdsUntil.difference(_now())) {
        final left when left > Duration.zero => left,
        _ => Duration.zero,
      },
    _ => null,
  };

  /// The preview last read of [file]'s file, maybe of an older
  /// version: what its card shows while the new version is read, so it
  /// keeps its size until then.
  CardPreview? lastKnown(ListedFile file) => _known[file.key]?.preview;

  /// [file]'s preview, read when a read is free.
  Future<CardPreview> read(ListedFile file) {
    if (known(file) case final preview?) return Future.value(preview);
    if (_running[file] case final running?) return running;
    final waiting = _waiting.remove(file) ?? Completer<CardPreview>();
    _waiting[file] = waiting;
    _startNext();
    return waiting.future;
  }

  /// Drops [file]'s read if it has not started: its card went away.
  void drop(ListedFile file) => _waiting.remove(file);

  void _startNext() {
    if (_running.length >= readsAtOnce || _waiting.isEmpty) return;
    final MapEntry(key: file, value: waiting) = _waiting.entries.last;
    _waiting.remove(file);
    final reading = _running[file] = _read(file);
    unawaited(
      reading.then((preview) {
        _running.remove(file);
        _keep(file, preview);
        waiting.complete(preview);
        _startNext();
      }),
    );
  }

  /// Keeps [preview] if the file told it (its text, or that it holds
  /// none): a read that failed may work next time (e.g. a folder briefly
  /// out of reach), so it is tried again.
  void _keep(ListedFile file, CardPreview preview) {
    if (preview is! Previewed && preview is! PreviewNotText) return;
    _known.remove(file.key);
    _known[file.key] = (file: file, preview: preview);
    if (_known.length > capacity) _known.remove(_known.keys.first);
  }
}

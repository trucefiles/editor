import 'dart:async';

import '../document.dart';
import 'card_preview.dart';

/// Reads what cards show of documents' texts, only for the cards that ask,
/// and keeps the newest [capacity] of them, so memory stays small however
/// many documents the folders hold.
///
/// Reads at most [readsAtOnce] files at a time; of the cards waiting, the
/// one that asked last is read first, as it is the most likely on screen.
/// A card that goes away drops its waiting read. Own code: a pool of
/// package:pool can't drop or reorder work that waits.
final class CardPreviews {
  CardPreviews(this._read, {this.capacity = 500, this.readsAtOnce = 4});

  /// Reads one document's preview; never throws.
  final Future<CardPreview> Function(Document document) _read;

  final int capacity;
  final int readsAtOnce;

  /// The previews read, the one used last at the end. Keyed by the listed
  /// document, version included: a new version is read again.
  final _known = <Document, CardPreview>{};

  /// The reads asked for and not started, the one asked last at the end.
  final _waiting = <Document, Completer<CardPreview>>{};

  final _running = <Document, Future<CardPreview>>{};

  /// [document]'s preview if it was read; marks it as used.
  CardPreview? known(Document document) => switch (_known.remove(document)) {
    final preview? => _known[document] = preview,
    null => null,
  };

  /// [document]'s preview, read when a read is free.
  Future<CardPreview> read(Document document) {
    if (known(document) case final preview?) return Future.value(preview);
    if (_running[document] case final running?) return running;
    final waiting = _waiting.remove(document) ?? Completer<CardPreview>();
    _waiting[document] = waiting;
    _startNext();
    return waiting.future;
  }

  /// Drops [document]'s read if it has not started: its card went away.
  void drop(Document document) => _waiting.remove(document);

  void _startNext() {
    if (_running.length >= readsAtOnce || _waiting.isEmpty) return;
    final MapEntry(key: document, value: waiting) = _waiting.entries.last;
    _waiting.remove(document);
    final reading = _running[document] = _read(document);
    unawaited(
      reading.then((preview) {
        _running.remove(document);
        _keep(document, preview);
        waiting.complete(preview);
        _startNext();
      }),
    );
  }

  /// Keeps [preview] if the file told it (its text, or that it holds
  /// none): a read that failed may work next time (e.g. a folder briefly
  /// out of reach), so it is tried again.
  void _keep(Document document, CardPreview preview) {
    if (preview is! Previewed && preview is! PreviewNotText) return;
    _known[document] = preview;
    if (_known.length > capacity) _known.remove(_known.keys.first);
  }
}

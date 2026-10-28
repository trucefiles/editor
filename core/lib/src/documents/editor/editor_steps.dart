import '../../owners/effects.dart';
import '../file_owner/file_contract.dart';
import 'editor_book.dart';
import 'editor_contract.dart';
import 'history/typing.dart';
import 'save_clock.dart';

/// How every editor handles what all document types share, inside the
/// step of its own machine: the page's requests, the save timing, and
/// undo and redo. The type keeps its [book] and gives what differs: what
/// shows ([snapshot], [restore], [reload], [replaceText]) and the text it
/// sends ([text]).
mixin EditorSteps<S> {
  EditorBook<S> get book;
  set book(EditorBook<S> book);

  /// Tells the page [notice].
  void notify(EditorNotice notice);

  /// Starts save timer [id], to fire after [delay].
  void startTimer(EffectId id, Duration delay);

  /// What shows now, to come back to.
  S snapshot();

  /// [back], a snapshot, shows again.
  void restore(S back);

  /// The file's [text] shows instead, read anew; what shows follows it
  /// where it can.
  void reload(String text);

  /// [text] shows instead, from its start (a backup restored).
  void replaceText(String text);

  /// What the file says once the edits are sent.
  String get text;

  /// Whether each change is sent at once, e.g. while the text is only
  /// read, which shows the text kept.
  bool get sendsAtOnce;

  /// Handles the page's [request].
  void handleRequest(EditorRequest request) {
    switch (request) {
      case Undo():
        _undoLatest();
        if (!book.history.canUndo) notify(HistoryEnd(book.history.start));
      case Redo():
        if (book.history.redone(snapshot()) case (
          :final history,
          :final back,
        )) {
          book = book.copyWith(history: history);
          _back(back);
        }
      case UndoStep(:final id):
        if (book.history.latestId == id) {
          _undoLatest();
        } else {
          notify(UndoRefused(id));
        }
      case ReplaceAll(:final text):
        final before = snapshot();
        replaceText(text);
        _changedByHistory();
        record(before, null);
        notify(UndoOffered(book.history.latestId!, OfferedUndo.restore));
      case FromFile(
            message: Replaced(:final text, :final version, :final ackRev),
          )
          when ackRev == book.rev:
        book = book.copyWith(
          lineage: version,
          // Before the first edit, it still starts where the document
          // opened (e.g. a newer copy of an own save shows).
          history: book.history.nextId == 0
              ? book.history
              : book.history.cleared(HistoryStart.changedElsewhere),
        );
        reload(text);
      case FromFile(message: Replaced()):
        // Not on the edits the editor holds: news to come is on them.
        break;
      case FromFile(message: Picked(:final text, :final version, :final rev)):
        book = book.copyWith(
          lineage: version,
          rev: rev,
          sentRev: rev,
          picks: book.picks + 1,
          history: book.history.cleared(HistoryStart.replacedHere),
        );
        reload(text);
      case SecureEditor(:final ticket, :final reason):
        send();
        book = book.copyWith(clock: book.clock.left);
        notify(ToFile(Secure(ticket, reason)));
    }
  }

  /// A text change: its rev, and the save clock runs.
  void textChanged() {
    book = book.copyWith(rev: book.rev + 1);
    _tick(book.clock.typed());
  }

  /// Save timer [id] fired.
  void fired(EffectId id) => _tick(book.clock.fired(id.value));

  /// The edit that changed what showed from [before], typing [typing] if
  /// it was typing, as an undo step, or as part of the latest one where
  /// it goes on typing.
  void record(S before, Typing? typing) {
    final history = book.history;
    book = book.copyWith(
      history: history.continued(typing) ?? history.recorded(before, typing),
    );
  }

  /// The typing run ends: typing next starts a step of its own (e.g. the
  /// caret moved).
  void endTypingRun() => book = book.copyWith(history: book.history.runEnded());

  /// The text to the file owner, unless it has it.
  void send() {
    if (book.sentRev == book.rev) return;
    notify(
      ToFile(
        Edited(text, rev: book.rev, lineage: book.lineage, picks: book.picks),
      ),
    );
    book = book.copyWith(sentRev: book.rev);
  }

  void _undoLatest() {
    if (book.history.undone(snapshot()) case (:final history, :final back)) {
      book = book.copyWith(history: history);
      _back(back);
    }
  }

  /// [back] shows again, as a text change.
  void _back(S back) {
    restore(back);
    _changedByHistory();
  }

  /// A text change not typed: saved as typing is, and sent at once where
  /// changes are.
  void _changedByHistory() {
    textChanged();
    if (sendsAtOnce) send();
  }

  void _tick(Tick tick) {
    book = book.copyWith(clock: tick.clock);
    for (final (:timer, :id) in tick.started) {
      startTimer(EffectId(id), timer.delay);
    }
    switch (tick.save) {
      case Save.draft:
        send();
      case Save.folder:
        send();
        notify(const ToFile(SaveNow()));
      case null:
        break;
    }
  }
}

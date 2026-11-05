import '../../filetypes/file_type_support.dart';
import '../../owners/effects.dart';
import '../file_owner/file_contract.dart';
import 'editor_book.dart';
import 'editor_contract.dart';
import 'history/typing.dart';
import 'history/undoable_edit.dart';
import 'save_clock.dart';

/// How every editor handles what all file types share, inside the
/// step of its own machine: the page's requests, the save timing, and
/// undo and redo. The type keeps its [book] and gives what differs: what
/// shows ([undo], [redo], [reload], [replaceText]) and the text it sends,
/// with its summary ([sent]).
mixin EditorSteps<S extends UndoableEdit<S>> {
  EditorBook<S> get book;
  set book(EditorBook<S> book);

  /// Tells the page [notice].
  void notify(EditorNotice notice);

  /// Starts save timer [id], to fire after [delay].
  void startTimer(EffectId id, Duration delay);

  /// What showed before [step] shows again.
  void undo(S step);

  /// What showed after [step] shows again.
  void redo(S step);

  /// The file's [text] shows instead, read anew; what shows follows it
  /// where it can.
  void reload(String text);

  /// [text] shows instead, from its start (a backup restored); gives
  /// that edit as a step.
  S replaceText(String text);

  /// What the file says once the edits are sent, and what lists show of
  /// it.
  SentText get sent;

  /// What lists show of [text], which shows now as taken from the file.
  TextSummary<Object?> summaryOfShown(String text);

  /// Whether each change is sent at once, e.g. while the text is only
  /// read, which shows the text kept.
  bool get sendsAtOnce;

  /// Handles the page's [request].
  void handleRequest(EditorRequest request) {
    switch (request) {
      case Undo():
        // Told only when asked for more than there is, not as the last
        // step goes, so the user hears it only when it matters.
        if (book.history.canUndo) {
          _undoLatest();
        } else {
          notify(HistoryEnd(book.history.start));
        }
      case Redo():
        if (book.history.redone() case (:final history, :final step)) {
          book = book.copyWith(history: history);
          redo(step);
          _changedByHistory();
        }
      case UndoStep(:final id):
        if (book.history.latestId == id) {
          _undoLatest();
        } else {
          notify(UndoRefused(id));
        }
      case ReplaceAll(:final text):
        final step = replaceText(text);
        _changedByHistory();
        record(step, null);
        notify(UndoOffered(book.history.latestId!, OfferedUndo.restore));
      case FromFile(
            message: Replaced(:final text, :final version, :final ackRev),
          )
          when ackRev == book.rev:
        book = book.copyWith(
          lineage: version,
          // Before the first edit, it still starts where the file
          // opened (e.g. a newer copy of an own save shows).
          history: book.history.nextId == 0
              ? book.history
              : book.history.cleared(HistoryStart.changedElsewhere),
        );
        _reloaded(text);
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
        _reloaded(text);
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

  /// [step], typing [typing] if it was typing, as an undo step, or as
  /// part of the latest one where it goes on typing.
  void record(S step, Typing? typing) {
    final history = book.history;
    book = book.copyWith(
      history:
          history.continued(step, typing) ?? history.recorded(step, typing),
    );
  }

  /// The typing run ends: typing next starts a step of its own (e.g. the
  /// caret moved).
  void endTypingRun() => book = book.copyWith(history: book.history.runEnded());

  /// The text to the file owner, unless it has it.
  void send() {
    if (book.sentRev == book.rev) return;
    final SentText(:text, :summary) = sent;
    notify(
      ToFile(
        Edited(text, rev: book.rev, lineage: book.lineage, picks: book.picks),
      ),
    );
    book = book.copyWith(sentRev: book.rev, summary: summary);
  }

  /// The file's [text] shows instead, as the file owner has it, so the
  /// summary is of it.
  void _reloaded(String text) {
    reload(text);
    book = book.copyWith(summary: summaryOfShown(text));
  }

  void _undoLatest() {
    if (book.history.undone() case (:final history, :final step)) {
      book = book.copyWith(history: history);
      undo(step);
      _changedByHistory();
    }
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

/// The [text] an editor sends to be kept, and what lists show of it
/// ([summary]), worked out from what printed the text, not read anew.
final class SentText {
  const SentText(this.text, this.summary);

  final String text;
  final TextSummary<Object?> summary;
}

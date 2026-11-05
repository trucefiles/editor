import 'package:truce_core/truce_core.dart'
    show
        EditorBook,
        EditorNotice,
        EditorSteps,
        EffectId,
        SentText,
        TextStep,
        TextSummary,
        Step,
        StepRun,
        textChange,
        typingFrom;

import '../plain_summary.dart';
import 'plain_contract.dart';

/// The plain editor owner's decision on [message] in [state], with its
/// [book].
Step<PlainState, EditorBook<TextStep>, PlainNotice, PlainSaveTimer> plainStep(
  PlainState state,
  EditorBook<TextStep> book,
  PlainMessage message,
) {
  return _Step(state, book).run(message);
}

/// One message's handling: the state as it changes and what it leads to.
final class _Step
    extends
        StepRun<
          PlainMessage,
          PlainState,
          EditorBook<TextStep>,
          PlainNotice,
          PlainSaveTimer
        >
    with EditorSteps<TextStep> {
  _Step(super.state, super.work);

  @override
  EditorBook<TextStep> get book => work;

  @override
  set book(EditorBook<TextStep> book) => work = book;

  @override
  void handle(PlainMessage message) {
    _caretTold();
    switch (message) {
      case TextEdited(:final revision) when revision != state.revision:
        // Typed on what no longer shows.
        break;
      case TextEdited(:final edit, :final pasted) when edit.changes:
        if (!edit.isOf(state.text)) {
          throw StateError('a text edit made on a text not shown');
        }
        _show(edit.text);
        textChanged();
        record(
          TextStep(edit.change),
          pasted ? null : typingFrom(null, edit.change),
        );
      case TextEdited():
        break;
      case CaretMoved():
        endTypingRun();
      case PlainRequest(:final request):
        handleRequest(request);
      case PlainTimerFired(:final id):
        fired(id);
    }
    _settleStatus();
  }

  @override
  void notify(EditorNotice notice) => events.add(PlainNotice(notice));

  @override
  void startTimer(EffectId id, Duration delay) =>
      effects.add(PlainSaveTimer(id, delay));

  /// The caret goes to where the text changed.
  @override
  void undo(TextStep step) => _showAt(step.undoneIn(state.text));

  @override
  void redo(TextStep step) => _showAt(step.redoneIn(state.text));

  @override
  void reload(String text) => _show(text);

  @override
  TextStep replaceText(String text) {
    final step = TextStep(textChange(state.text, text));
    _show(text, caret: 0);
    return step;
  }

  @override
  SentText get sent =>
      SentText(state.text, PlainSummary(state.text, maxLines: 0));

  @override
  TextSummary<Object?> summaryOfShown(String text) =>
      PlainSummary(text, maxLines: 0);

  /// Only the editor shows the text; nothing shows the text kept.
  @override
  bool get sendsAtOnce => false;

  /// [text] shows, the caret at [caret] if given.
  void _show(String text, {int? caret}) => state = PlainState(
    text,
    caret: caret,
    revision: state.revision + 1,
    status: book.status,
  );

  void _showAt(({String text, int caret}) shown) =>
      _show(shown.text, caret: shown.caret);

  /// The caret was told with the last state; it stays where it is now.
  void _caretTold() {
    if (state.caret == null) return;
    state = PlainState(
      state.text,
      revision: state.revision,
      status: state.status,
    );
  }

  void _settleStatus() {
    if (state.status == book.status) return;
    state = PlainState(
      state.text,
      caret: state.caret,
      revision: state.revision,
      status: book.status,
    );
  }
}

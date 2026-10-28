import 'package:truce_core/truce_core.dart'
    show
        EditorBook,
        EditorNotice,
        EditorSteps,
        EffectId,
        Step,
        textChange,
        typingIn;

import 'plain_contract.dart';

/// The plain editor owner's decision on [message] in [state], with its
/// [book].
Step<PlainState, EditorBook<String>, PlainNotice, PlainSaveTimer> plainStep(
  PlainState state,
  EditorBook<String> book,
  PlainMessage message,
) {
  final step = _Step(state, book)..handle(message);
  return (
    state: step.state,
    work: step.book,
    events: step.events,
    effects: step.effects,
  );
}

/// One message's handling: the state as it changes and what it leads to.
final class _Step with EditorSteps<String> {
  _Step(this.state, this.book);

  PlainState state;

  @override
  EditorBook<String> book;

  final events = <PlainNotice>[];
  final effects = <PlainSaveTimer>[];

  void handle(PlainMessage message) {
    _caretTold();
    switch (message) {
      case TextEdited(:final revision) when revision != state.revision:
        // Typed on what no longer shows.
        break;
      case TextEdited(:final text, :final pasted) when text != state.text:
        final before = state.text;
        _show(text);
        textChanged();
        record(before, pasted ? null : typingIn(null, before, text));
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

  @override
  String snapshot() => state.text;

  /// The caret goes to where the text changed.
  @override
  void restore(String back) {
    final change = textChange(state.text, back);
    _show(back, caret: change.start + change.added.length);
  }

  @override
  void reload(String text) => _show(text);

  @override
  void replaceText(String text) => _show(text, caret: 0);

  @override
  String get text => state.text;

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

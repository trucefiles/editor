/// The plain text editor owner's contract: what reaches it, what it
/// decides, what it leads to. One per open plain text document; it holds
/// the text the editor shows and handles what every type's editor shares
/// (core's editor contract): the page's requests, undo, and sending the
/// text to the file owner as the save timing says.
library;

import 'package:truce_core/truce_core.dart'
    show EditorNotice, EditorRequest, EditorStatus, EffectId, Wait;

/// What the plain editor owner handles: inputs anyone may send, and the
/// results of its effects.
sealed class PlainMessage {
  const PlainMessage();
}

// Inputs.

sealed class PlainInput extends PlainMessage {
  const PlainInput();
}

/// The text is now [text], as the editor shows it at [revision]; dropped
/// if the state moved on since. A [pasted] text is an undo step of its
/// own, never part of the typing around it.
final class TextEdited extends PlainInput {
  const TextEdited(this.text, {required this.revision, this.pasted = false});

  final String text;
  final int revision;
  final bool pasted;
}

/// The user moved the caret: typing next is an undo step of its own.
final class CaretMoved extends PlainInput {
  const CaretMoved();
}

/// A request of the document page (see core's editor contract).
final class PlainRequest extends PlainInput {
  const PlainRequest(this.request);

  final EditorRequest request;
}

// Results.

/// The save timer [PlainSaveTimer] started with [id] fired.
final class PlainTimerFired extends PlainMessage {
  const PlainTimerFired(this.id);

  final EffectId id;
}

// Effects.

/// Fire [PlainTimerFired] with [id] after [delay]: the one effect.
final class PlainSaveTimer implements Wait<PlainTimerFired> {
  const PlainSaveTimer(this.id, this.delay);

  @override
  final EffectId id;
  @override
  final Duration delay;

  @override
  PlainTimerFired get done => PlainTimerFired(id);
}

// Events.

/// What the document page hears (see core's editor contract): the one
/// kind of event.
final class PlainNotice {
  const PlainNotice(this.notice);

  final EditorNotice notice;
}

// State.

/// The text the editor shows: the plain editor owner's state. After an
/// undo, a redo or a backup restored, the [caret] goes to the offset in
/// [text] where it changed (`null`: the caret stays where it is). The
/// caret is told once: the next state has none, unless it moves again.
final class PlainState {
  const PlainState(
    this.text, {
    required this.revision,
    required this.status,
    this.caret,
  });

  final String text;
  final int? caret;

  /// Counts the changes to what shows; inputs name the one they saw.
  final int revision;

  /// What it tells of the edits: whether some are only in memory, and
  /// what undo and redo can do.
  final EditorStatus status;
}

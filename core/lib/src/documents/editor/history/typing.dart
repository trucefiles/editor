import 'text_change.dart';

/// A small edit at one place in one text, which an undo step may take in
/// with the edits right before it: text typed, or deleted by a key.
final class Typing {
  const Typing(
    this.text, {
    required this.from,
    required this.to,
    required this.added,
    required this.end,
  });

  /// Which text: an id the document type gives each text it edits apart.
  final Object? text;

  /// The stretch replaced, in the text before.
  final int from;
  final int to;

  /// What came in its place; empty for a deletion.
  final String added;

  /// Where the caret is after it.
  final int end;

  bool get adds => added.isNotEmpty;
}

/// The typing an undo step holds so far: in [text], from [start] to
/// [end], adding or deleting.
final class TypingRun {
  TypingRun(Typing typing)
    : text = typing.text,
      adds = typing.adds,
      start = typing.from,
      end = typing.end,
      endsInSpace = _endsInSpace(typing.added);

  const TypingRun._(
    this.text, {
    required this.adds,
    required this.start,
    required this.end,
    required this.endsInSpace,
  });

  final Object? text;
  final bool adds;
  final int start;
  final int end;

  /// Whether the last text typed ends in white space.
  final bool endsInSpace;

  /// Whether [next] goes on in this run: the same text and the same kind
  /// (typing or deleting), right where the run ended. A word typed after
  /// a space starts a new step: one undo per word.
  bool takes(Typing next) =>
      next.text == text &&
      next.adds == adds &&
      switch (adds) {
        // An input method may replace the word it composes.
        true =>
          next.from >= start &&
              next.to == end &&
              !(endsInSpace && !_startsWithSpace(next.added)),
        false => next.to == end || next.from == end,
      };

  /// This run with [next], which it [takes].
  TypingRun then(Typing next) => TypingRun._(
    text,
    adds: adds,
    start: next.from < start ? next.from : start,
    end: next.end,
    endsInSpace: adds ? _endsInSpace(next.added) : endsInSpace,
  );

  static bool _endsInSpace(String text) =>
      text.isNotEmpty && _space.hasMatch(text[text.length - 1]);

  static bool _startsWithSpace(String text) =>
      text.isNotEmpty && _space.hasMatch(text[0]);

  static final _space = RegExp(r'\s');
}

/// The change from [before] to [after] in [text], a text edited as a
/// whole (e.g. as plain text), as typing; a new line (Enter, a paste of
/// lines) is a step of its own.
Typing? typingIn(Object? text, String before, String after) =>
    switch (textChange(before, after)) {
      (:final start, :final removed, :final added)
          when (removed.isNotEmpty || added.isNotEmpty) &&
              !added.contains('\n') =>
        Typing(
          text,
          from: start,
          to: start + removed.length,
          added: added,
          end: start + added.length,
        ),
      _ => null,
    };

import 'package:truce_core/truce_core.dart' show splitLines;

import 'syntax/block_starts.dart';

/// How many of [lines] are front matter: a `---` first line and the
/// closing `---` or `...` line further down; 0 if there is none.
int frontMatterLength(List<String> lines) => switch (lines.firstOrNull) {
  final first? when frontMatterFence.hasMatch(first) => switch (lines
      .indexWhere(frontMatterEnd.hasMatch, 1)) {
    -1 => 0,
    final end => end + 1,
  },
  _ => 0,
};

/// [text] without its front matter, for readers that don't know front
/// matter; the whole text if it has none.
String textAfterFrontMatter(String text) {
  final lines = splitLines(text);
  return switch (frontMatterLength(lines)) {
    0 => text,
    final length => lines.skip(length).join('\n'),
  };
}

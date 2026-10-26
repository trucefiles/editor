import 'package:truce_markdown/truce_markdown.dart';

import 'editor_gate.dart';

/// Commands of the formatted views (Visual edit and Read).
extension RunCommand on EditorGate {
  /// Sends the command [build] makes of the selection as it is then;
  /// nothing in Markdown edit or if [build] makes none.
  void run(Command? Function(Selection selection) build) => send(
    (now) => switch (now.content) {
      FormattedContent(:final selection) => switch (build(selection)) {
        final command? => Run(command, revision: now.revision),
        null => null,
      },
      MarkdownContent() => null,
    },
  );
}

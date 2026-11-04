import 'package:truce_markdown/truce_markdown.dart';

import 'editor_gate.dart';

/// Commands of the formatted views (Visual edit and Read).
extension RunCommand on EditorGate {
  /// Sends the command [build] makes of the selection as it is then
  /// (`null`: no caret shows); nothing in Markdown edit or if [build]
  /// makes none. A raw block open as text closes first, so [build] sees
  /// the blocks as they then are. A command [byControl] (see
  /// [Run.byControl]) leaves no caret. A command made on what showed at
  /// an earlier [revision] (a gesture's start) is dropped if the text
  /// changed since. Whether a command went.
  bool run(
    Command? Function(Selection? selection) build, {
    bool byControl = false,
    int? revision,
  }) {
    send(
      (now) => switch (now.content) {
        FormattedContent(raw: _?) => CloseRawBlock(revision: now.revision),
        _ => null,
      },
    );
    return send(
      (now) => switch (now.content) {
        FormattedContent(:final selection) => switch (build(selection)) {
          final command? => Run(
            command,
            revision: revision ?? now.revision,
            byControl: byControl,
          ),
          null => null,
        },
        MarkdownContent() => null,
      },
    );
  }
}

import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../editor_gate.dart';

/// The Markdown editor owner behind [gate] as the document page sees it
/// (core's editor contract). The page's requests go through the gate, so
/// box taps still waiting go in first; what the file owner tells goes in
/// without them, as they wait on.
final class MarkdownPageEditor implements PageEditor {
  MarkdownPageEditor(this.gate);

  /// The way into the editor owner, for the views.
  final EditorGate gate;

  @override
  void send(EditorRequest input) => switch (input) {
    FromFile() => gate.external(Request(input)),
    _ => gate.send((_) => Request(input)),
  };

  @override
  EditorStatus get state => gate.state.status;

  @override
  late final Stream<EditorStatus> changes = gate.changes
      .map((state) => state.status)
      .distinct();

  @override
  Stream<EditorNotice> get events => gate.events.expand(
    (event) => [if (event case Notice(:final notice)) notice],
  );

  /// Also closes the gate.
  @override
  Future<void> close() {
    gate.dispose();
    return gate.closed;
  }
}

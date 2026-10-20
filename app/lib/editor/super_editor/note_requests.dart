import 'package:super_editor/super_editor.dart';

import 'key_actions.dart';

/// Hands the requests that would change a note's structure to [keys]
/// instead of the library, which knows no Markdown: Enter, joining nodes
/// with Backspace or Delete, and pasting. Hardware keys and soft
/// keyboards both end in these requests.
EditRequestHandler noteRequests(KeyActions keys) =>
    (editor, request) => switch (request) {
      InsertNewlineAtCaretRequest() => _Run(keys.enter),
      DeleteUpstreamAtBeginningOfNodeRequest(:final node) => _Run(
        () => keys.joinBackward(node.id),
      ),
      CombineParagraphsRequest(:final firstNodeId) => _Run(
        () => keys.joinForward(firstNodeId),
      ),
      PasteEditorRequest(:final content) => _Run(() => keys.paste(content)),
      _ => null,
    };

/// Runs [action], which edits the note: the editor shows the result once
/// the note has it.
final class _Run extends EditCommand {
  _Run(this.action);

  final void Function() action;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.nonHistorical;

  @override
  void execute(EditContext context, CommandExecutor executor) => action();
}

import 'package:truce_core/truce_core.dart';

/// Which editor node shows which line of the note. A line keeps its node
/// while it is shown, so the caret stays on it.
final class LineNodes {
  final _lineOfNode = <String, LineId>{};
  final _nodeOfLine = <LineId, String>{};

  /// The id of the node showing [line]: the one it has, else a new one.
  String nodeOf(LineId line) {
    if (_nodeOfLine[line] case final node?) return node;
    final node = 'line-$line';
    link(node, line);
    return node;
  }

  /// The line node [node] shows; `null` if it shows none.
  LineId? lineOf(String node) => _lineOfNode[node];

  /// Node [node], which the editor added, shows [line] now.
  void link(String node, LineId line) {
    _lineOfNode[node] = line;
    _nodeOfLine[line] = node;
  }

  /// Forgets every line but [lines], e.g. after lines were removed, so a
  /// node that comes back (an undo) counts as new.
  void retain(Set<LineId> lines) {
    _nodeOfLine.removeWhere((line, _) => !lines.contains(line));
    _lineOfNode.removeWhere((_, line) => !lines.contains(line));
  }
}

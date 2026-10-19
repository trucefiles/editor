import 'package:truce_core/truce_core.dart';

/// The text nodes shown formatted, by node id, with the offsets between
/// what shows and the node's text. Written by the phase that formats
/// them, read by their components to map positions.
final class VisualLines {
  final _byNode = <String, VisualLine>{};

  /// How node [nodeId] shows; `null` while it shows its own text.
  VisualLine? of(String nodeId) => _byNode[nodeId];

  void clear() => _byNode.clear();

  void set(String nodeId, VisualLine line) => _byNode[nodeId] = line;
}

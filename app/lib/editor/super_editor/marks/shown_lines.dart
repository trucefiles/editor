import 'package:truce_core/truce_core.dart';

/// How each text node shows, by node id, with the offsets between what
/// shows and the node's text. Written by the phase that styles them, read
/// by their components to map positions.
final class ShownLines {
  final _byNode = <String, ShownLine>{};

  /// How node [nodeId] shows; `null` if not styled.
  ShownLine? of(String nodeId) => _byNode[nodeId];

  void clear() => _byNode.clear();

  void set(String nodeId, ShownLine line) => _byNode[nodeId] = line;
}

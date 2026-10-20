/// What the user can do to a list item from its row in the editor, by the
/// id of the item's node.
abstract interface class LineActions {
  void indent(String nodeId);

  void outdent(String nodeId);

  /// Removes the item with its subitems.
  void delete(String nodeId);

  /// Drops the item [nodeId] with its subitems next to the item [target]:
  /// [below] it, else above it; [levels] deeper, or shallower if negative,
  /// as far as the spot allows.
  void move(
    String nodeId, {
    required String target,
    required bool below,
    required int levels,
  });
}

/// What the user can do to a checkbox item from its row in the editor, by
/// the id of the item's node.
abstract interface class LineActions {
  void indent(String nodeId);

  void outdent(String nodeId);

  /// Removes the item with its subitems.
  void delete(String nodeId);

  /// Moves the item [nodeId] with its subitems next to the item [target]:
  /// [below] it and its subitems, else above it.
  void move(String nodeId, {required String target, required bool below});
}

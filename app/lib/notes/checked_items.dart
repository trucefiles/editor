/// Where a checklist's checked items go.
enum CheckedItems {
  /// Where they are in the file, among the open items.
  inPlace,

  /// Shown apart, in a "Done" section at the bottom. View only: the file
  /// order never changes.
  doneSection,

  /// Moved in the file: checking moves an item to the end of the list,
  /// unchecking back below the open items. Shown apart too.
  toEnd;

  /// Whether a view shows them apart from the open items.
  bool get shownApart => this != inPlace;
}

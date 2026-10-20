import 'package:truce_core/truce_core.dart';

/// What the user can do with the parts of a note that are no text to
/// type in: the "Done" headings, add buttons and drawn tables.
abstract interface class DisplayActions {
  /// Folds or unfolds the "Done" section of the list [list].
  void toggleDone(LineId list);

  /// Adds an empty item where [button] says, with the caret in it.
  void addItem(AddItemEntry button);

  /// Shows the table whose first line is [table] as its text.
  void showRaw(LineId table);
}

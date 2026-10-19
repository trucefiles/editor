import 'package:truce_core/truce_core.dart';

/// What the user can do with the parts of a note that are no lines: the
/// "Done" headings, add buttons and drawn tables and images.
abstract interface class DisplayActions {
  /// Folds or unfolds the "Done" section of the list [list].
  void toggleDone(LineId list);

  /// Adds an empty item where [button] says, with the caret in it.
  void addItem(AddItemEntry button);

  /// Shows the table or image starting at line [first] as its lines.
  void showRaw(LineId first);
}

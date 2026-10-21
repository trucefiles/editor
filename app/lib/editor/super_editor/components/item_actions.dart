import 'package:truce_core/truce_core.dart';

/// What the user can do to a list item from its row in the editor, by the
/// item's marker line.
abstract interface class ItemActions {
  /// Checks or unchecks the checkbox [item].
  void toggle(LineId item);

  void indent(LineId item);

  void outdent(LineId item);

  /// Removes the item with its subitems.
  void delete(LineId item);

  /// Drops [item] with its subitems next to the item [target]: [below]
  /// it, else above it.
  void move(LineId item, {required LineId target, required bool below});
}

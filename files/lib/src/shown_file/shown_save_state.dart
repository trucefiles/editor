import '../save_state.dart';
import 'shown_file_contract.dart';

/// The [SaveState] of a shown file at [state]: a new one waiting on this
/// device, or the file in its folder. A new one being kept, or kept
/// nowhere (its page says so), shows none.
SaveState saveStateOfShown(ShownState state) => switch (state) {
  WaitingNew(kept: NewKept.onDevice) => SaveState.onDevice,
  WaitingNew() => SaveState.none,
  ShownListed() => SaveState.inFolder,
  ShownGone() || ShownDropped() => SaveState.none,
};

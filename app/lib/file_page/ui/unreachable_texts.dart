import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

/// What an unreachable folder means for an open text in [state]: that it
/// is kept on this device, unless it is known not to be (the edit state
/// banner then tells).
String? textUnreachableText(SessionState state) => switch (state) {
  Stopped(kept: false || null) => null,
  Stopped() || Running() || Ended() => 'Your text is kept on this device.',
};

/// What an unreachable folder means for a shown file in [state]: a new
/// one is kept on this device only once it is known to be (else its
/// state banner tells); any other shows its last version here.
String? shownUnreachableText(ShownState state) => switch (state) {
  WaitingNew(kept: NewKept.onDevice) => 'The file is kept on this device.',
  WaitingNew() => null,
  ShownListed() ||
  ShownGone() ||
  ShownDropped() => 'You see the last version on this device.',
};

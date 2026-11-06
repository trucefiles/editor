import 'package:truce_common_ui/truce_common_ui.dart';

/// What the user is told once both versions were merged: that nothing
/// was lost, or which older versions (e.g. of events) newer changes
/// replaced, the first few by name. [lost]: the names of those older
/// versions.
String mergeOutcome(List<String> lost) => switch (lost) {
  [] => 'Merged. No changes were lost.',
  _ =>
    'Merged. Some conflicts were resolved automatically; the overwritten '
        'changes are in Backups: ${fewNamed(lost)}.',
};

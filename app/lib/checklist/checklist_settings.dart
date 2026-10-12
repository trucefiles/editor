import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether checked items move to a collapsible "Done" section at the
/// bottom. View only: the file order never changes.
final doneSectionProvider = NotifierProvider<DoneSection, bool>(
  DoneSection.new,
);

class DoneSection extends Notifier<bool> {
  @override
  bool build() => true;

  void set({required bool enabled}) => state = enabled;
}

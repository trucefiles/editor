/// Who plans the alerts, where more than one part of the app could at
/// once (on Android the app and its background check run side by side):
/// only the one that holds the role plans, so one writer keeps the
/// planner's state.
abstract interface class PlannerRole {
  /// Takes the role, waiting while another holds it; [onAsked] is called
  /// whenever another part asks the holder to plan again.
  Future<void> take({required void Function() onAsked});

  /// Takes the role if it is free, or asks its holder to plan again;
  /// whether this one took it.
  Future<bool> takeOrAsk();

  /// Gives the role up.
  void release();
}

/// The role where nothing else plans: always free.
final class SoleRole implements PlannerRole {
  const SoleRole();

  @override
  Future<void> take({required void Function() onAsked}) async {}

  @override
  Future<bool> takeOrAsk() async => true;

  @override
  void release() {}
}

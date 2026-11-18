import 'planned_alert.dart';

/// What rings alerts on this device: the system's scheduled
/// notifications, or the app's own clock while it runs. Handed in from
/// above.
abstract interface class Ringer {
  /// Whether the alerts handed to it ring while the app isn't running
  /// (the system holds them), so ones that came then weren't missed.
  bool get ringsWhileClosed;

  /// When it rang an alert itself, while the app runs; none for a ringer
  /// the system rings.
  Stream<DateTime> get rang;

  /// Rings the alerts [changes] add at their time, and no longer those
  /// they take back, in order; the numbers of the alerts it couldn't take
  /// (the system refused them), none if it took all.
  Future<Set<int>> apply(List<RingChange> changes);

  /// Tells, quietly, the alerts [missed] while nothing could ring them.
  Future<void> showMissed(List<PlannedAlert> missed);
}

/// A change to what the ringer rings.
sealed class RingChange {
  const RingChange(this.number);

  /// The number the ringer knows the alert by.
  final int number;
}

/// Ring [alert] at its time, as [number] (in place of one by that
/// number).
final class Ring extends RingChange {
  const Ring(super.number, this.alert);

  final PlannedAlert alert;

  @override
  bool operator ==(Object other) =>
      other is Ring && other.number == number && other.alert == alert;

  @override
  int get hashCode => Object.hash(number, alert);
}

/// Don't ring the alert [number] any more.
final class Silence extends RingChange {
  const Silence(super.number);

  @override
  bool operator ==(Object other) => other is Silence && other.number == number;

  @override
  int get hashCode => number.hashCode;
}

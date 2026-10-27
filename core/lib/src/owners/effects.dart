/// What a machine owner asks to be done for it (effects), and how their
/// results come back.
library;

/// An effect's id; its result comes back with it. A result whose id the
/// machine no longer waits for is ignored.
extension type const EffectId(int value) {}

/// Carries out [effect], which starts before this returns; its result
/// for the machine, `null` for an effect without one.
typedef EffectHandler<Effect, Result> = Future<Result?> Function(Effect effect);

/// An effect that waits for [delay]; then the machine gets [done]. The
/// only way time reaches a machine.
abstract interface class Wait<Done> {
  EffectId get id;
  Duration get delay;

  /// The result once [delay] is over.
  Done get done;
}

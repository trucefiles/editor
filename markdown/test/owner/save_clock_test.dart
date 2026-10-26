import 'package:test/test.dart';
import 'package:truce_markdown/src/owner/save_clock.dart';

/// A clock driven by events, with the timers running and the saves made.
final class _Clock {
  SaveClock clock = const SaveClock();
  final running = <SaveTimer, int>{};
  final saves = <Save>[];

  void _take(Tick tick) {
    clock = tick.clock;
    for (final (:timer, :id) in tick.started) {
      running[timer] = id;
    }
    if (tick.save case final save?) saves.add(save);
  }

  void type() => _take(clock.typed());

  /// [timer] fires, as last started.
  void fire(SaveTimer timer) => _take(clock.fired(running[timer]!));
}

void main() {
  test('a pause keeps a draft, the folder follows 30 s later', () {
    final clock = _Clock()
      ..type()
      ..fire(SaveTimer.pause);
    expect(clock.saves, [Save.draft]);
    clock.fire(SaveTimer.folder);
    expect(clock.saves, [Save.draft, Save.folder]);
  });

  test('typing restarts the pause and stops the folder', () {
    final clock = _Clock()..type();
    final first = clock.running[SaveTimer.pause]!;
    clock.type();
    expect(clock.clock.fired(first).save, isNull);
    clock
      ..fire(SaveTimer.pause)
      ..type();
    expect(clock.clock.fired(clock.running[SaveTimer.folder]!).save, isNull);
  });

  test('long typing keeps a draft 30 s after its first keypress', () {
    final clock = _Clock()..type();
    final long = clock.running[SaveTimer.long]!;
    clock.type();
    expect(clock.running[SaveTimer.long], long, reason: 'not restarted');
    clock.fire(SaveTimer.long);
    expect(clock.saves, [Save.draft]);
    clock.type();
    expect(clock.running[SaveTimer.long], isNot(long), reason: 'anew');
  });

  test('a draft stops the long timer', () {
    final clock = _Clock()..type();
    final long = clock.running[SaveTimer.long]!;
    clock.fire(SaveTimer.pause);
    expect(clock.clock.fired(long).save, isNull);
  });

  test('text waiting 2 min for the folder goes there at the next pause', () {
    final clock = _Clock()
      ..type()
      ..fire(SaveTimer.stale)
      ..fire(SaveTimer.pause);
    expect(clock.saves, [Save.folder]);
    clock.type();
    expect(clock.clock.stale, isFalse);
    expect(clock.running.containsKey(SaveTimer.stale), isTrue);
  });

  test('leaving stops every timer', () {
    final clock = _Clock()..type();
    final left = clock.clock.left;
    for (final id in clock.running.values) {
      expect(left.fired(id).save, isNull);
    }
  });
}

import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// Random accesses, settles and results (late, stale, in any order) on
/// the reach machine; its rules hold after every step, and every settle
/// is answered once no check is under way.
void main() {
  test('random events keep the reach rules', () {
    for (var seed = 0; seed < 200; seed++) {
      final random = Random(seed);
      final run = MachineRun.of(reachMachine(retries: 2));
      final asked = <Ticket>{};
      final underWay = <ReachEffect>[];
      for (var step = 0; step < 60; step++) {
        final message = switch (random.nextInt(5)) {
          0 => Accessed(Access.values[random.nextInt(Access.values.length)]),
          1 => Settle(Ticket()),
          _ when underWay.isEmpty => const Accessed(Access.mayBeGone),
          2 => switch (underWay.removeAt(random.nextInt(underWay.length))) {
            CheckFolder(:final id) => FolderChecked(id, ok: random.nextBool()),
            WaitToRetry(:final done) => done,
          },
          // A stale result: ignored.
          _ => FolderChecked(EffectId(random.nextInt(9)), ok: true),
        };
        if (message case Settle(:final ticket)) asked.add(ticket);
        for (final output in run.send(message)) {
          switch (output) {
            case final ReachEffect effect:
              underWay.add(effect);
            case Settled(:final ticket):
              expect(asked.remove(ticket), isTrue, reason: 'seed $seed');
          }
        }
        expect(run.violations, isEmpty, reason: 'seed $seed, after $message');
      }
    }
  });
}

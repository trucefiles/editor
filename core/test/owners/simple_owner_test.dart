import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  /// Each input waits for its gate, then adds itself; logs as it goes.
  late Map<int, Completer<void>> gates;
  late List<String> log;
  late SimpleOwner<int, int, String> owner;

  setUp(() {
    gates = {};
    log = [];
    owner = SimpleOwner(0, (input, out) async {
      log.add('start $input');
      await (gates[input] ??= Completer<void>()).future;
      out
        ..state = out.state + input
        ..emit('done $input');
      log.add('end $input');
    });
  });

  test('runs one input at a time, in the order sent', () async {
    owner
      ..send(1)
      ..send(2);
    await pumpEventQueue();
    expect(log, ['start 1']);
    gates[1]!.complete();
    await pumpEventQueue();
    expect(log, ['start 1', 'end 1', 'start 2']);
    gates[2]!.complete();
    await pumpEventQueue();
    expect(owner.state, 3);
  });

  test('an input whose handler throws (a bug) stops none after it', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      owner
        ..send(1)
        ..send(2);
      gates[1]!.completeError(StateError('bug'));
      gates[2] = Completer<void>()..complete();
      await pumpEventQueue();
    }, (error, _) => errors.add(error));

    expect(errors.single, isA<StateError>());
    expect(owner.state, 2);
  });

  test('events and changes tell what the inputs led to', () async {
    final events = <String>[];
    final changes = <int>[];
    owner.events.listen(events.add);
    owner.changes.listen(changes.add);
    gates[0] = Completer()..complete();
    gates[4] = Completer()..complete();
    owner
      ..send(0)
      ..send(4);
    await pumpEventQueue();
    expect(events, ['done 0', 'done 4']);
    expect(changes, [4], reason: 'adding 0 changes nothing');
  });

  test('close lets the inputs sent finish, then ends', () async {
    gates[5] = Completer();
    owner.send(5);
    final closed = owner.close();
    owner.send(6);
    gates[5]!.complete();
    await closed;
    expect(owner.state, 5);
    expect(log, ['start 5', 'end 5']);
  });
}

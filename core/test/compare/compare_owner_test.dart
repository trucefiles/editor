import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// A source whose keeps end when a test says.
final class _Source implements CompareSource<String, String> {
  final keeps = <Completer<Result<void, ResolveError>>>[];
  int rescans = 0;

  @override
  Future<Result<String, StoreError>> load(String target) async =>
      Ok('sides of $target');

  @override
  Future<Result<void, ResolveError>> keep(
    String target,
    String sides,
    Resolution choice,
  ) {
    final keep = Completer<Result<void, ResolveError>>();
    keeps.add(keep);
    return keep.future;
  }

  @override
  Future<void> rescan() async => rescans++;
}

void main() {
  test('a keep is answered once a later scan saw it', () async {
    final source = _Source();
    final owner = compareOwner('a', source, goesOn: true);
    await pumpEventQueue();

    final answer = ask<CompareInput<String, String>, KeepAnswer>(
      owner.send,
      owner.events,
      (ticket) => Keep(ticket, const KeepOther()),
    );
    source.keeps.single.complete(const Ok(null));
    await pumpEventQueue();
    expect(source.rescans, 1);
    owner.send(ScanSeen(null, startedAt: Moment.now()));

    expect((await answer)?.done, isTrue);
  });

  test('closed mid-keep, the keep still ends and rescans', () async {
    final source = _Source();
    final owner = compareOwner('a', source, goesOn: true);
    await pumpEventQueue();
    owner.send(Keep(Ticket(), const KeepOther()));

    final closed = owner.close();
    source.keeps.single.complete(const Ok(null));
    await closed;

    expect(source.rescans, 1);
  });
}

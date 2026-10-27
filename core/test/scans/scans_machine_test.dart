import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

typedef _Run = MachineRun<ScansMessage<String, int>, int?, Fresh, Object?>;

/// A scans machine over folders named by strings, each scan a number.
_Run _run() => MachineRun.of(scansMachine<String, int>());

extension on _Run {
  List<ScanAll<String, int>> get scans => all<ScanAll<String, int>>();

  /// The scan last started ends, finding [scan].
  void scanned(int scan) => send(Scanned(scans.last.id, scan));

  Ticket refresh() {
    final ticket = Ticket();
    send(Refresh(ticket));
    return ticket;
  }

  List<Ticket> get fresh => [for (final fresh in all<Fresh>()) fresh.ticket];

  /// The wait of [delay] last started is over.
  void waited(Duration delay) => send(
    all<WaitForChanges<String, int>>()
        .lastWhere((wait) => wait.delay == delay)
        .done,
  );
}

const _settle = Duration(milliseconds: 500);
const _longest = Duration(seconds: 3);

void main() {
  test('scans nothing before the folders are known', () {
    final run = _run();
    final ticket = run.refresh();
    expect(run.scans, isEmpty);

    run.send(FoldersChanged(['a']));
    expect(run.scans.single.folders, ['a']);
    run.scanned(1);
    expect(run.state, 1);
    expect(run.fresh, [ticket]);
  });

  test('a refresh during a scan waits for one more, shared', () {
    final run = _run()..send(FoldersChanged(['a']));
    final first = run.refresh();
    final second = run.refresh();
    expect(run.scans, hasLength(1));

    run.scanned(1);
    expect(run.fresh, isEmpty, reason: 'that scan began before them');
    expect(run.scans, hasLength(2));
    run.scanned(2);
    expect(run.fresh, [first, second]);
    expect(run.state, 2);
  });

  test('a scan uses the folders it was asked with', () {
    final run = _run()
      ..send(FoldersChanged(['a']))
      ..send(FoldersChanged(['a', 'b']));
    expect(run.scans.single.folders, ['a']);
    run.scanned(1);
    expect(run.scans.last.folders, ['a', 'b']);
  });

  test('changes close together lead to one scan once they pause', () {
    final run = _run()..send(FoldersChanged(['a']));
    run.scanned(1);
    run
      ..send(const FilesChanged())
      ..send(const FilesChanged());
    final settles = run
        .all<WaitForChanges<String, int>>()
        .where((wait) => wait.delay == _settle)
        .toList();
    run.send(settles.first.done);
    expect(run.scans, hasLength(1), reason: 'a later change restarted it');
    run.waited(_settle);
    expect(run.scans, hasLength(2));
  });

  test('changes that keep coming scan at the latest after a while', () {
    final run = _run()..send(FoldersChanged(['a']));
    run.scanned(1);
    for (var i = 0; i < 5; i++) {
      run.send(const FilesChanged());
    }
    run.waited(_longest);
    expect(run.scans, hasLength(2));
    // The settle waits left over end without a scan.
    for (final wait in run.all<WaitForChanges<String, int>>()) {
      run.send(wait.done);
    }
    expect(run.scans, hasLength(2));
  });

  test('changes while not in use start nothing', () {
    final run = _run()
      ..send(FoldersChanged(['a']))
      ..scanned(1)
      ..send(const FilesChanged())
      ..send(const Active(active: false));
    for (final wait in run.all<WaitForChanges<String, int>>()) {
      run.send(wait.done);
    }
    run.send(const FilesChanged());
    expect(run.scans, hasLength(1));
    expect(run.all<WaitForChanges<String, int>>(), hasLength(2));
  });

  test('a refresh scans even while not in use', () {
    final run = _run()
      ..send(FoldersChanged(['a']))
      ..scanned(1)
      ..send(const Active(active: false))
      ..refresh();
    expect(run.scans, hasLength(2));
  });

  test('a setting change scans once', () {
    final run = _run()
      ..send(FoldersChanged(['a']))
      ..scanned(1)
      ..send(const SettingChanged());
    expect(run.scans, hasLength(2));
  });

  test('random events keep the rules; every refresh is answered', () {
    for (var seed = 0; seed < 200; seed++) {
      final random = Random(seed);
      final run = _run();
      final asked = <Ticket, int>{};
      final underWay = <Object?>[];
      var scansStarted = 0;
      for (var step = 0; step < 80; step++) {
        final message = switch (random.nextInt(7)) {
          0 => Refresh<String, int>(Ticket()),
          1 => const FilesChanged<String, int>(),
          2 => FoldersChanged<String, int>(['a', if (random.nextBool()) 'b']),
          3 => Active<String, int>(active: random.nextBool()),
          4 => const SettingChanged<String, int>(),
          _ when underWay.isEmpty => const FilesChanged<String, int>(),
          _ => switch (underWay.removeAt(random.nextInt(underWay.length))) {
            ScanAll<String, int>(:final id) => Scanned<String, int>(id, step),
            WaitForChanges<String, int>(:final done) => done,
            _ => throw StateError('unknown effect'),
          },
        };
        if (message case Refresh(:final ticket)) asked[ticket] = scansStarted;
        for (final output in run.send(message)) {
          switch (output) {
            case ScanAll<String, int>():
              expect(
                underWay.whereType<ScanAll<String, int>>(),
                isEmpty,
                reason: 'never two scans at once, seed $seed',
              );
              scansStarted++;
              underWay.add(output);
            case WaitForChanges<String, int>():
              underWay.add(output);
            case Fresh(:final ticket):
              expect(
                scansStarted,
                greaterThan(asked.remove(ticket)!),
                reason: 'answered by a later scan, seed $seed',
              );
          }
        }
        expect(run.violations, isEmpty, reason: 'seed $seed, $message');
      }
    }
  });
}

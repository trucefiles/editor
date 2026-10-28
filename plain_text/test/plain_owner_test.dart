import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_plain_text/truce_plain_text.dart';
import 'package:truce_test_support/truce_test_support.dart';

const _v1 = Version(1);
const _v2 = Version(2);

/// A plain editor machine, with what it led to so far.
final class _Run {
  _Run(String text) : machine = MachineRun.of(plainMachine(text, version: _v1));

  final MachineRun<PlainMessage, PlainState, PlainNotice, PlainSaveTimer>
  machine;

  PlainState get state => machine.state;

  List<EditorNotice> get notices => [
    for (final event in machine.events) event.notice,
  ];

  List<Edited> get edits => [
    for (final notice in notices)
      if (notice case ToFile(input: final Edited edited)) edited,
  ];

  void edit(String text) =>
      machine.send(TextEdited(text, revision: state.revision));

  void request(EditorRequest request) => machine.send(PlainRequest(request));

  /// The save timer [timer] last started fires.
  void fire(SaveTimer timer) => machine.send(
    PlainTimerFired(
      machine.effects.lastWhere((start) => start.delay == timer.delay).id,
    ),
  );
}

void main() {
  group('editing', () {
    test('shows the text at once, and sends it at a pause', () {
      final run = _Run('a')..edit('ab');
      expect(run.state.text, 'ab');
      expect(run.state.status.unsent, isTrue);
      expect(run.edits, isEmpty);
      run.fire(SaveTimer.pause);
      expect(
        (run.edits.single.text, run.edits.single.rev, run.edits.single.lineage),
        ('ab', 1, _v1),
      );
      expect(run.state.status.unsent, isFalse);
    });

    test('a text edited on what no longer shows is dropped', () {
      final run = _Run('a');
      final seen = run.state.revision;
      run
        ..edit('ab')
        ..machine.send(TextEdited('ax', revision: seen));
      expect(run.state.text, 'ab');
    });

    test('writes into the folder 30 s after a pause', () {
      final run = _Run('a')
        ..edit('ab')
        ..fire(SaveTimer.pause)
        ..fire(SaveTimer.folder);
      expect(run.notices.last, isA<ToFile>());
      expect((run.notices.last as ToFile).input, isA<SaveNow>());
    });

    test('securing sends the text first, then asks to keep it', () {
      final ticket = Ticket();
      final run = _Run('a')
        ..edit('ab')
        ..request(SecureEditor(ticket, SecureReason.close));
      expect(run.edits.single.text, 'ab');
      expect(
        (run.notices.last as ToFile).input,
        isA<Secure>().having((secure) => secure.ticket, 'ticket', ticket),
      );
    });
  });

  group('undo', () {
    test('takes back one word at a time, the caret where it changed', () {
      final run = _Run('')
        ..edit('one')
        ..edit('one ')
        ..edit('one two')
        ..request(const Undo());
      expect(run.state.text, 'one ');
      expect(run.state.caret, 4);
      run.request(const Undo());
      expect(run.state.text, '');
      expect(run.state.status.canUndo, isFalse);
      expect(run.notices.last, isA<HistoryEnd>());
      run.request(const Redo());
      expect(run.state.text, 'one ');
    });

    test('a new line is a step of its own', () {
      final run = _Run('')
        ..edit('a')
        ..edit('a\n')
        ..edit('a\nb')
        ..request(const Undo());
      expect(run.state.text, 'a\n');
    });

    test('a restored backup is one step, offered for undo', () {
      final run = _Run('mine')..request(const ReplaceAll('backup'));
      expect(run.state.text, 'backup');
      expect(run.state.caret, 0);
      final offered = run.notices.whereType<UndoOffered>().single;
      expect(offered.what, OfferedUndo.restore);
      run.request(UndoStep(offered.id));
      expect(run.state.text, 'mine');
    });

    test('an offered step no longer the latest is refused', () {
      final run = _Run('mine')..request(const ReplaceAll('backup'));
      final offered = run.notices.whereType<UndoOffered>().single;
      run
        ..edit('backup!')
        ..request(UndoStep(offered.id));
      expect(run.notices.last, isA<UndoRefused>());
      expect(run.state.text, 'backup!');
    });
  });

  group('from the file owner', () {
    test('a change elsewhere on the text sent shows, and starts the history '
        'anew', () {
      final run = _Run('a')
        ..edit('ab')
        ..fire(SaveTimer.pause)
        ..request(const FromFile(Replaced('abc', version: _v2, ackRev: 1)));
      expect(run.state.text, 'abc');
      expect(run.state.status.canUndo, isFalse);
      run
        ..edit('abcd')
        ..fire(SaveTimer.pause);
      expect(run.edits.last.lineage, _v2);
    });

    test('a change elsewhere on an older text is not shown', () {
      final run = _Run('a')
        ..edit('ab')
        ..request(const FromFile(Replaced('z', version: _v2, ackRev: 0)));
      expect(run.state.text, 'ab');
    });

    test('a pick shows its text and goes on from its rev', () {
      final run = _Run('a')
        ..edit('ab')
        ..request(const FromFile(Picked('theirs', version: _v2, rev: 5)));
      expect(run.state.text, 'theirs');
      expect(run.state.status.unsent, isFalse);
      run
        ..edit('theirs!')
        ..fire(SaveTimer.pause);
      expect(
        (run.edits.last.rev, run.edits.last.picks, run.edits.last.lineage),
        (6, 1, _v2),
      );
    });
  });
}

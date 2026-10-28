import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// The smallest document type's editor: it shows one text, edited as a
/// whole, and snapshots are that text. It keeps what it led to.
final class _FakeEditor with EditorSteps<String> {
  _FakeEditor(this.shown, {this.sendsAtOnce = false});

  /// The text that shows.
  String shown;

  @override
  EditorBook<String> book = EditorBook(lineage: const Version(1));

  @override
  bool sendsAtOnce;

  final notices = <EditorNotice>[];

  /// The save timers started, by id.
  final timers = <EffectId, Duration>{};

  @override
  void notify(EditorNotice notice) => notices.add(notice);

  @override
  void startTimer(EffectId id, Duration delay) => timers[id] = delay;

  @override
  String snapshot() => shown;

  @override
  void restore(String back) => shown = back;

  @override
  void reload(String text) => shown = text;

  @override
  void replaceText(String text) => shown = text;

  @override
  String get text => shown;

  /// The user changed the text to [text], as the type's own step does.
  void edit(String text) {
    final before = shown;
    shown = text;
    textChanged();
    record(before, typingIn(null, before, text));
  }

  /// Types each of [texts] in turn, each the whole text after a key.
  void type(List<String> texts) => texts.forEach(edit);

  /// The texts sent to the file owner.
  List<String> get sent => [
    for (final notice in notices)
      if (notice case ToFile(input: Edited(:final text))) text,
  ];

  /// The latest save timer started with [delay] fires.
  void fire(Duration delay) =>
      fired(timers.entries.lastWhere((timer) => timer.value == delay).key);
}

void main() {
  group('undo', () {
    test('takes back one word at a time', () {
      final editor = _FakeEditor('')..type(['a', 'ab', 'ab ', 'ab c', 'ab cd']);

      editor.handleRequest(const Undo());
      expect(editor.shown, 'ab ');
      editor.handleRequest(const Undo());
      expect(editor.shown, '');
    });

    test('a new line is a step of its own', () {
      final editor = _FakeEditor('a')..type(['ab', 'ab\n', 'ab\nc']);

      editor.handleRequest(const Undo());
      expect(editor.shown, 'ab\n');
      editor.handleRequest(const Undo());
      expect(editor.shown, 'ab');
    });

    test('a typing run that ended starts a new step', () {
      final editor = _FakeEditor('')..edit('a');
      editor
        ..endTypingRun()
        ..edit('ab')
        ..handleRequest(const Undo());

      expect(editor.shown, 'a');
    });

    test('at the start tells why the history starts there', () {
      final editor = _FakeEditor('a')
        ..edit('ab')
        ..handleRequest(const Undo());

      expect(editor.notices.last, isA<HistoryEnd>());
      expect((editor.notices.last as HistoryEnd).start, HistoryStart.opened);
    });

    test('keeps the latest steps only', () {
      final editor = _FakeEditor('');
      for (var step = 0; step <= EditHistory.limit; step++) {
        editor
          ..endTypingRun()
          ..edit('$step');
      }

      for (var step = 0; step < EditHistory.limit; step++) {
        editor.handleRequest(const Undo());
      }

      expect(editor.shown, '0');
      expect(editor.book.status.canUndo, isFalse);
      expect((editor.notices.last as HistoryEnd).start, HistoryStart.limit);
    });

    test('is a text change, saved as typing is', () {
      final editor = _FakeEditor('a')..edit('ab');
      final rev = editor.book.rev;

      editor.handleRequest(const Undo());

      expect(editor.book.rev, rev + 1);
      expect(editor.book.status.unsent, isTrue);
      expect(editor.sent, isEmpty);
    });

    test('sends at once where changes are', () {
      final editor = _FakeEditor('a', sendsAtOnce: true)
        ..edit('ab')
        ..handleRequest(const Undo());

      expect(editor.sent, ['a']);
    });
  });

  group('redo', () {
    test('goes forward again', () {
      final editor = _FakeEditor('a')
        ..edit('ab')
        ..handleRequest(const Undo())
        ..handleRequest(const Redo());

      expect(editor.shown, 'ab');
      expect(editor.book.status.canRedo, isFalse);
    });

    test('a new edit drops what redo had', () {
      final editor = _FakeEditor('a')
        ..edit('ab')
        ..handleRequest(const Undo())
        ..edit('ax');

      expect(editor.book.status.canRedo, isFalse);
      editor.handleRequest(const Redo());
      expect(editor.shown, 'ax');
    });
  });

  group('an offered undo', () {
    test('takes back the latest step', () {
      final editor = _FakeEditor('a')..edit('ab');

      editor.handleRequest(UndoStep(editor.book.history.latestId!));

      expect(editor.shown, 'a');
    });

    test('is refused once another step came after it', () {
      final editor = _FakeEditor('a')..edit('ab');
      final offered = editor.book.history.latestId!;
      editor
        ..endTypingRun()
        ..edit('ab\nc')
        ..handleRequest(UndoStep(offered));

      expect(editor.shown, 'ab\nc');
      expect(editor.notices.last, isA<UndoRefused>());
    });
  });

  test('a backup restored is one step, offered for undo', () {
    final editor = _FakeEditor('mine')
      ..handleRequest(const ReplaceAll('backup'));

    expect(editor.shown, 'backup');
    final offered = editor.notices.last as UndoOffered;
    expect(offered.what, OfferedUndo.restore);

    editor.handleRequest(UndoStep(offered.id));
    expect(editor.shown, 'mine');
  });

  group('news from the file owner', () {
    test('a change elsewhere on the edits sent shows and ends the history', () {
      final editor = _FakeEditor('a')
        ..edit('ab')
        ..send()
        ..handleRequest(
          const FromFile(Replaced('theirs', version: Version(2), ackRev: 1)),
        );

      expect(editor.shown, 'theirs');
      expect(editor.book.lineage, const Version(2));
      expect(editor.book.status.canUndo, isFalse);
      expect(editor.book.history.start, HistoryStart.changedElsewhere);
    });

    test('a change elsewhere before any edit keeps the history start', () {
      final editor = _FakeEditor('a')
        ..handleRequest(
          const FromFile(Replaced('newer', version: Version(2), ackRev: 0)),
        );

      expect(editor.shown, 'newer');
      expect(editor.book.history.start, HistoryStart.opened);
    });

    test('a change elsewhere on older edits is left for news to come', () {
      final editor = _FakeEditor('a')
        ..edit('ab')
        ..handleRequest(
          const FromFile(Replaced('theirs', version: Version(2), ackRev: 0)),
        );

      expect(editor.shown, 'ab');
      expect(editor.book.lineage, const Version(1));
    });

    test('a version picked shows and goes on from its rev', () {
      final editor = _FakeEditor('a')
        ..edit('ab')
        ..handleRequest(
          const FromFile(Picked('picked', version: Version(3), rev: 7)),
        );

      expect(editor.shown, 'picked');
      expect(editor.book.rev, 7);
      expect(editor.book.status.unsent, isFalse);
      expect(editor.book.picks, 1);
      expect(editor.book.history.start, HistoryStart.replacedHere);
    });
  });

  test('securing sends the text, then asks the file owner to keep it', () {
    final ticket = Ticket();
    final editor = _FakeEditor('a')
      ..edit('ab')
      ..handleRequest(SecureEditor(ticket, SecureReason.close));

    expect(editor.notices.whereType<ToFile>().map((notice) => notice.input), [
      isA<Edited>()
          .having((edited) => edited.text, 'text', 'ab')
          .having((edited) => edited.rev, 'rev', 1)
          .having((edited) => edited.lineage, 'lineage', const Version(1)),
      isA<Secure>().having((secure) => secure.ticket, 'ticket', ticket),
    ]);
    expect(editor.book.status.unsent, isFalse);
  });

  group('save timing', () {
    test('typing starts the timers; the pause sends the text as a draft', () {
      final editor = _FakeEditor('a')..edit('ab');
      expect(editor.timers.values, contains(SaveTimer.pause.delay));
      expect(editor.sent, isEmpty);

      editor.fire(SaveTimer.pause.delay);

      expect(editor.sent, ['ab']);
      expect(editor.notices.whereType<ToFile>().last.input, isA<Edited>());
    });

    test('the folder timer sends the text into the folder', () {
      final editor = _FakeEditor('a')
        ..edit('ab')
        ..fire(SaveTimer.pause.delay)
        ..fire(SaveTimer.folder.delay);

      expect(editor.notices.last, isA<ToFile>());
      expect((editor.notices.last as ToFile).input, isA<SaveNow>());
    });

    test('nothing is sent twice', () {
      final editor = _FakeEditor('a')
        ..edit('ab')
        ..send()
        ..send();

      expect(editor.sent, ['ab']);
    });
  });
}

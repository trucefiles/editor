import 'dart:collection';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// A folder, a device and an editor around one file owner, driven by
/// random events: typing, changes elsewhere, scans, effects finishing,
/// picks and secures. A [delayed] editor gets the owner's
/// messages some steps later, typing on in between.
final class _World {
  _World(
    this.random, {
    required this.isNew,
    required this.elsewhere,
    this.delayed = false,
  }) {
    if (!isNew) file = Seen('a', _version());
    owner = _Owner(switch (file) {
      final opened? => openedFile(opened),
      null => newFile(),
    }, _output);
    text = owner.state.text;
    lineage = file?.version;
    taken.add(text);
  }

  final Random random;
  final bool isNew;

  /// Whether the file may change elsewhere.
  final bool elsewhere;

  final bool delayed;

  /// Messages for the editor not yet delivered.
  final toEditor = <FileEvent>[];

  /// Texts a draft's base may be: those the editor took, and those the
  /// owner wrote, which the edits after them build on.
  final taken = <String>{};

  late final _Owner owner;
  Seen? _file;

  /// Every text the file had: a change elsewhere may replace one the
  /// owner wrote or showed after it was kept.
  final fileTexts = <String>{};
  Seen? get file => _file;
  set file(Seen? seen) {
    _file = seen;
    if (seen != null) {
      fileTexts.add(seen.text);
      versionTexts[seen.version] = seen.text;
    }
  }

  /// The text of each version the file had.
  final versionTexts = <Version, String>{};

  String? draft;

  /// The text the device last could not keep.
  String? refused;

  /// How many [Secure]s were sent.
  var secures = 0;

  /// How many [Move]s were sent, and answered.
  var moves = 0;
  var moveAnswers = 0;
  String? deletedText;
  final conflicts = <String>[];
  final effects = <FileEffect>[];
  final scans = <(Moment, Observation)>[];
  final answers = <Answer>[];
  var restoreAsked = false;
  var changedElsewhere = false;
  var writeFailed = false;
  var _versions = 0;

  // The editor.
  late String text;
  var rev = 0;
  var picks = 0;
  Version? lineage;

  Version _version() => Version(++_versions);

  void _output(Object? output) {
    switch (output) {
      case final ToEditor message when delayed:
        toEditor.add(message);
      case final ToEditor message:
        _toEditor(message);
      case DropDraft():
        draft = null;
      case final FileEffect effect:
        expect(
          switch (effect) {
            KeepDraft(:final base?) => taken.contains(base),
            _ => true,
          },
          isTrue,
          reason: 'a draft\'s base is a text its edits build on',
        );
        expect(
          switch (effect) {
            Write(:final over) => versionTexts[over.version] == over.text,
            _ => true,
          },
          isTrue,
          reason: 'writes only over a version the file had',
        );
        expect(
          effect is! Write ||
              switch (owner.state.status) {
                ChangedElsewhere() || DeletedElsewhere() => false,
                _ => true,
              },
          isTrue,
          reason: 'no write while a change elsewhere waits for a pick',
        );
        expect(effects, isEmpty, reason: 'one I/O at a time');
        expect(
          switch (effect) {
            Write(:final text) ||
            Create(:final text) => text == draft || text == refused,
            _ => true,
          },
          isTrue,
          reason: 'writes from the draft kept',
        );
        expect(
          switch (effect) {
            Write(:final text, :final over) => text != over.text,
            _ => true,
          },
          isTrue,
          reason: 'no write the file holds already',
        );
        expect(
          effect is! Create || isNew,
          isTrue,
          reason: 'creates only a new document',
        );
        expect(
          effect is! Restore || restoreAsked,
          isTrue,
          reason: 'restores only when asked',
        );
        expect(
          effect is! KeepAsConflict || changedElsewhere || writeFailed,
          isTrue,
          reason: 'no conflict copy without a reason',
        );
        effects.add(effect);
      case final Answer answer:
        answers.add(answer);
      case MoveAnswer():
        moveAnswers++;
      case PickNotKept():
        break;
    }
  }

  /// The editor takes a change from the owner: a change elsewhere only
  /// if it has no edits the owner had not seen.
  void _toEditor(FileEvent output) {
    switch (output) {
      case Replaced(:final text, :final version, :final ackRev)
          when ackRev == rev:
        this.text = text;
        lineage = version;
        taken.add(text);
      case Picked(:final text, :final version, rev: final picked):
        this.text = text;
        lineage = version;
        rev = picked;
        picks++;
        // Picked edits build on the version picked.
        taken.addAll([text, ?versionTexts[version]]);
      case _:
        break;
    }
  }

  void step() {
    if (toEditor.isNotEmpty && random.nextInt(3) == 0) {
      return _toEditor(toEditor.removeAt(0));
    }
    switch (random.nextInt(14)) {
      case 0 || 1 || 2 when !_readOnly:
        text = '$text${String.fromCharCode(98 + random.nextInt(3))}';
        rev++;
        final edited = Edited(text, rev: rev, lineage: lineage, picks: picks);
        // As the session sends it: with its name while there is no file.
        owner.send(
          owner.state.file == null
              ? NewEdited(edited, name: _nameOf(text))
              : edited,
        );
      case 3 when elsewhere && file != null && random.nextInt(3) == 0:
        file = Seen('${file!.text}!', _version());
        changedElsewhere = true;
      case 4 when elsewhere && file != null && random.nextInt(4) == 0:
        deletedText = file!.text;
        file = null;
        changedElsewhere = true;
      case 5:
        scans.add((
          Moment.now(),
          file == null ? const Gone() : Found(file!.version),
        ));
      case 6 when scans.isNotEmpty:
        final (startedAt, observation) = scans.removeAt(0);
        owner.send(Observed(observation, startedAt: startedAt));
      case 7 || 8 when effects.isNotEmpty:
        _finish(effects.removeAt(0));
      case 9 when !_readOnly:
        owner.send(const SaveNow());
      case 10:
        switch (owner.state.status) {
          case ChangedElsewhere(:final theirs):
            final choice = PickChoice.values[random.nextInt(2)];
            // Edits picked over their version build on it.
            if (choice == PickChoice.mine) taken.add(theirs.text);
            owner.send(Pick(choice, seen: theirs.version, rev: rev));
          case DeletedElsewhere():
            restoreAsked = true;
            owner.send(const RestoreMine());
          case _:
            owner.send(const SaveNow());
        }
      case 11:
        secures++;
        owner.send(
          Secure(
            Ticket(),
            SecureReason.values[random.nextInt(SecureReason.values.length)],
          ),
        );
      case 12
          when switch (owner.state.status) {
            SaveFailed() || ChangedElsewhere() || DeletedElsewhere() => true,
            _ => false,
          }:
        owner.send(const Discard());
      case 13:
        moves++;
        owner.send(Move(Ticket()));
      case _:
        break;
    }
  }

  /// The editor shows the document read-only once its edits are kept as
  /// a conflict copy.
  bool get _readOnly => switch (owner.state.status) {
    KeptAsConflict() || Closed() => true,
    _ => false,
  };

  void _finish(FileEffect effect) {
    final endedAt = Moment.now();
    switch (effect) {
      case KeepDraft(:final id, :final text, :final file, :final name):
        expect(name, file == null ? _nameOf(text) : null, reason: 'its name');
        final kept = random.nextInt(6) > 0;
        if (kept) {
          draft = text;
        } else {
          refused = text;
        }
        owner.send(DraftKept(id, kept: kept));
      case Write(:final id, :final text, :final over):
        final WriteOutcome<Version> outcome = switch (file) {
          null => const WriteGone(),
          final now when now.version != over.version => Changed(now),
          _ when random.nextInt(8) == 0 => _failed(),
          _ => Written(file = Seen(text, _version())),
        };
        if (outcome is Written) taken.add(text);
        owner.send(Wrote(id, outcome, endedAt: endedAt));
      case Create(:final id, :final text, :final name):
        expect(name, _nameOf(text), reason: 'named from its own text');
        taken.add(text);
        owner.send(
          Wrote(id, Written(file = Seen(text, _version())), endedAt: endedAt),
        );
      case Restore(:final id, :final text):
        final outcome = switch (file) {
          final there? => Taken(there),
          null => Written(file = Seen(text, _version())),
        };
        if (outcome is Written) taken.add(text);
        owner.send(Wrote(id, outcome, endedAt: endedAt));
      case BackUpBoth(:final id):
        owner.send(BackedUp(id, ok: random.nextInt(5) > 0));
      case KeepAsConflict(:final id, :final text):
        final ok = random.nextInt(5) > 0;
        if (ok) conflicts.add(text);
        owner.send(ConflictKept(id, ok: ok));
      case ReadLatest(:final id):
        owner.send(LatestRead(id, file));
      case MoveFile(:final id, :final from):
        // Moves only the file as it was; scans follow it to its new place.
        final moved = file?.version == from.version;
        if (moved) {
          file = Seen(file!.text, _version());
          scans.clear();
        }
        owner.send(MovedTo(id, moved ? file : null, endedAt: endedAt));
      case DropDraft():
        break;
    }
  }

  WriteOutcome _failed() {
    writeFailed = true;
    return const WriteFailed();
  }

  String describe() =>
      'editor: $text\nfile: ${file?.text}\ndraft: $draft\n'
      'conflicts: $conflicts\nstatus: ${owner.state.status}\n'
      'owner text: ${owner.state.text}\nanswers: '
      '${answers.map((answer) => answer.kept)}';

  /// Leaves the document: secures it and lets every effect finish, the
  /// editor getting what is on its way before and after.
  void close() {
    _deliver();
    secures++;
    owner.send(Secure(Ticket(), SecureReason.close));
    while (effects.isNotEmpty) {
      _finish(effects.removeAt(0));
    }
    _deliver();
  }

  void _deliver() {
    while (toEditor.isNotEmpty) {
      _toEditor(toEditor.removeAt(0));
    }
  }
}

void main() {
  for (final (isNew, elsewhere, delayed) in [
    for (final isNew in [false, true])
      for (final elsewhere in [false, true]) (isNew, elsewhere, false),
    (false, true, true),
    // A new document, created, then changed elsewhere before the editor
    // took the change.
    (true, true, true),
  ]) {
    {
      test('random events never lose an edit '
          '(${isNew ? 'new' : 'opened'}, '
          '${elsewhere ? 'with' : 'without'} changes elsewhere'
          '${delayed ? ', editor delayed' : ''})', () {
        for (var seed = 0; seed < 300; seed++) {
          final world = _World(
            Random(seed),
            isNew: isNew,
            elsewhere: elsewhere,
            delayed: delayed,
          );
          for (var step = 0; step < 80; step++) {
            world.step();
            if (world.toEditor.isNotEmpty) continue;
            expect(
              world.owner.state.text,
              world.text,
              reason: 'the owner holds what the editor shows, seed $seed',
            );
            if (!elsewhere) {
              expect(
                world.owner.state.status,
                isNot(anyOf(isA<ChangedElsewhere>(), isA<DeletedElsewhere>())),
                reason: 'no false conflict, seed $seed step $step',
              );
            }
          }
          world.close();
          expect(
            world.answers,
            hasLength(world.secures),
            reason: 'every secure is answered, seed $seed',
          );
          expect(
            world.moveAnswers,
            world.moves,
            reason: 'every move is answered, seed $seed',
          );
          final answer = world.answers.last;
          final kept = {
            ...world.fileTexts,
            ...world.conflicts,
            ?world.draft,
            ?world.deletedText,
            if (isNew) '',
          };
          expect(
            kept.contains(world.text) ||
                (isNew && world.text.trim().isEmpty) ||
                // Kept nowhere lasting: still held, the answer says so.
                (!answer.kept && world.owner.state.text == world.text),
            isTrue,
            reason:
                'the edits are kept somewhere, seed $seed\n${world.describe()}',
          );
          if (answer.kept && world.owner.state.status is Closed) {
            expect(
              {
                    ...world.fileTexts,
                    ...world.conflicts,
                    ?world.deletedText,
                  }.contains(world.text) ||
                  (isNew && world.text.trim().isEmpty),
              isTrue,
              reason: 'kept means lasting, seed $seed',
            );
          }
        }
      });
    }
  }
}

/// A file machine stepped as its owner steps it: a message sent while one
/// is handled waits for it; each step's outputs go to [_output].
final class _Owner {
  _Owner(FileMachine machine, this._output) : _run = MachineRun.of(machine);

  final MachineRun<FileMessage, FileState, FileEvent, FileEffect> _run;
  final void Function(Object? output) _output;
  final _messages = Queue<FileMessage>();
  bool _handling = false;

  FileState get state => _run.state;

  void send(FileMessage message) {
    _messages.add(message);
    if (_handling) return;
    _handling = true;
    try {
      while (_messages.isNotEmpty) {
        _run.send(_messages.removeFirst()).forEach(_output);
      }
    } finally {
      _handling = false;
    }
  }
}

/// The name a new document's file gets from [text], in these tests.
String _nameOf(String text) => 'named $text';

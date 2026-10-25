import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

const _timing = FileTiming();

/// A folder, a device and an editor around one file owner, driven by
/// random events: typing, changes elsewhere, scans, effects finishing,
/// timers, picks and secures.
final class _World {
  _World(this.random, {required this.isNew, required this.elsewhere}) {
    owner = isNew
        ? newFileOwner(timing: _timing)
        : openedFileOwner(Seen('a', _version()), timing: _timing);
    if (!isNew) file = owner.state.work.expected;
    text = owner.state.text;
    lineage = file?.version;
    owner.outputs.listen(_output);
  }

  final Random random;
  final bool isNew;

  /// Whether the file may change elsewhere.
  final bool elsewhere;

  late final FileOwner owner;
  Seen? file;
  String? draft;
  String? deletedText;
  final conflicts = <String>[];
  final effects = <FileEffect>[];
  final timers = <EffectId>[];
  final scans = <(Moment, Observation)>[];
  final answers = <Answer>[];
  var restoreAsked = false;
  var changedElsewhere = false;
  var writeFailed = false;
  var _versions = 0;

  // The editor.
  late String text;
  var rev = 0;
  Version? lineage;

  Version _version() => Version(++_versions);

  void _output(FileOutput output) {
    switch (output) {
      case Replaced(:final text, :final version, :final ackRev)
          when ackRev == rev:
        this.text = text;
        lineage = version;
      case Replaced():
        break;
      case Picked(:final text, :final version):
        this.text = text;
        lineage = version;
      case StartTimer(:final id):
        timers.add(id);
      case DropDraft():
        draft = null;
      case final FileEffect effect:
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
      case PickNotKept():
        break;
    }
  }

  void step() {
    switch (random.nextInt(12)) {
      case 0 || 1 || 2 when !_readOnly:
        text = '$text${String.fromCharCode(98 + random.nextInt(3))}';
        rev++;
        owner.send(Edited(text, rev: rev, lineage: lineage));
      case 3 when elsewhere && file != null && random.nextInt(3) == 0:
        file = Seen('${file!.text}!', _version());
        changedElsewhere = true;
      case 4 when elsewhere && file != null && random.nextInt(4) == 0:
        deletedText = file!.text;
        file = null;
        changedElsewhere = true;
      case 5:
        scans.add((Moment.now(), file == null ? const Gone() : Found(file!)));
      case 6 when scans.isNotEmpty:
        final (startedAt, observation) = scans.removeAt(0);
        owner.send(Observed(observation, startedAt: startedAt));
      case 7 || 8 when effects.isNotEmpty:
        _finish(effects.removeAt(0));
      case 9 when timers.isNotEmpty:
        owner.send(TimerFired(timers.removeAt(random.nextInt(timers.length))));
      case 10:
        switch (owner.state.status) {
          case ChangedElsewhere(:final theirs):
            owner.send(
              Pick(
                PickChoice.values[random.nextInt(2)],
                seen: theirs.version,
                rev: rev,
              ),
            );
          case DeletedElsewhere():
            restoreAsked = true;
            owner.send(const RestoreMine());
          case _:
            owner.send(const SaveNow());
        }
      case 11:
        owner.send(
          Secure(random.nextBool() ? SecureReason.hide : SecureReason.exit),
        );
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
      case KeepDraft(:final id, :final text):
        final kept = random.nextInt(6) > 0;
        if (kept) draft = text;
        owner.send(DraftKept(id, kept: kept));
      case Write(:final id, :final text, :final over):
        final outcome = switch (file) {
          null => const WriteGone(),
          final now when now.version != over.version => Changed(now),
          _ when random.nextInt(8) == 0 => _failed(),
          _ => Written(file = Seen(text, _version())),
        };
        owner.send(Wrote(id, outcome, endedAt: endedAt));
      case Create(:final id, :final text):
        owner.send(
          Wrote(id, Written(file = Seen(text, _version())), endedAt: endedAt),
        );
      case Restore(:final id, :final text):
        final outcome = switch (file) {
          final there? => Taken(there),
          null => Written(file = Seen(text, _version())),
        };
        owner.send(Wrote(id, outcome, endedAt: endedAt));
      case BackUpBoth(:final id):
        owner.send(BackedUp(id, ok: random.nextInt(5) > 0));
      case KeepAsConflict(:final id, :final text):
        final ok = random.nextInt(5) > 0;
        if (ok) conflicts.add(text);
        owner.send(ConflictKept(id, ok: ok));
      case DropDraft() || StartTimer():
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

  /// Leaves the document: secures it and lets every effect finish.
  void close() {
    owner.send(const Secure(SecureReason.close));
    while (effects.isNotEmpty) {
      _finish(effects.removeAt(0));
    }
  }
}

void main() {
  for (final isNew in [false, true]) {
    for (final elsewhere in [false, true]) {
      test('random events never lose an edit '
          '(${isNew ? 'new' : 'opened'}, '
          '${elsewhere ? 'with' : 'without'} changes elsewhere)', () {
        for (var seed = 0; seed < 300; seed++) {
          final world = _World(
            Random(seed),
            isNew: isNew,
            elsewhere: elsewhere,
          );
          for (var step = 0; step < 80; step++) {
            world.step();
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
          final answer = world.answers.last;
          final kept = {
            ?world.file?.text,
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
                    ?world.file?.text,
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

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/file_page/changed_elsewhere_controller.dart';
import 'package:truce_editor/file_page/file_controller.dart';
import 'package:truce_files/truce_files.dart';

import '../support.dart';
import 'file_fixture.dart';

void main() {
  late FileFixture fixture;
  late FileSession session;

  /// The choice of a file changed elsewhere while its edits wait on the
  /// device, of a type that merges as [merge] does.
  Future<ChangedElsewhereController> choice({TextMerge? merge}) async {
    fixture = await FileFixture.create();
    session = fixture.session(null, merge)..type('mine ');
    await fixture.editElsewhere('theirs\n');
    await session.secure(.hide);
    expect(session.status, isA<ChangedElsewhere>());
    final file = FileController(
      session,
      reach: () => Reach.reachable,
      reachSettled: () async => Reach.reachable,
      backUp: (_) async => const Ok(null),
      delete: (_, _) async => const Err(DeleteNotDone(StoreError.notFound)),
      settingsOf: (_) => FileSettings.defaults,
      editSettings: (_, _) async {},
      endWait: const Duration(seconds: 1),
    );
    addTearDown(file.dispose);
    final choice = ChangedElsewhereController(file);
    addTearDown(choice.dispose);
    return choice;
  }

  test(
    'shows both and offers no merge for a type that does not merge',
    () async {
      final shown = await choice();
      await pumpEventQueue();

      expect(shown.theirs?.text, 'theirs\n');
      expect(shown.mine, contains('mine'));
      expect(shown.merges, isFalse);
      expect(shown.canPick, isTrue);
    },
  );

  test('offers the merge once the file owner said the two merge', () async {
    final shown = await choice(merge: const _BothMerge());
    expect(shown.merges, isFalse, reason: 'not answered yet');

    await eventually(() => shown.merges);
  });

  test(
    'a pick under way takes no other; once kept, the choice is settled',
    () async {
      final shown = await choice();
      shown.pick(PickChoice.mine, shown.theirs!);

      expect(shown.canPick, isFalse);
      await eventually(() => shown.theirs == null);
    },
  );

  /// The file changes elsewhere again, to [text], and the session hears
  /// of it.
  Future<void> changedAgain(String text) async {
    final latest = await fixture.editElsewhere(text);
    session.observe(contentsFinding([latest.listed]));
    await eventually(
      () => switch (session.status) {
        ChangedElsewhere(:final theirs) => theirs.text == text,
        _ => false,
      },
    );
  }

  test('asks again for a newer version from elsewhere', () async {
    final shown = await choice(merge: const _BothMerge());
    await eventually(() => shown.merges);
    final first = shown.theirs!;

    await changedAgain('theirs, newer\n');

    expect(shown.theirs!.version, isNot(first.version));
    await eventually(() => shown.merges);
  });

  test('a pick not kept frees the choice and says so', () async {
    final shown = await choice();
    final old = shown.theirs!;
    await changedAgain('theirs, newer\n');
    var told = 0;
    shown.notKept.listen((_) => told++);

    shown.pick(PickChoice.mine, old);

    await eventually(() => told == 1);
    expect(shown.canPick, isTrue);
    expect(shown.theirs?.text, 'theirs, newer\n');
  });
}

/// Merges by keeping both texts.
final class _BothMerge implements TextMerge {
  const _BothMerge();

  @override
  MergeResult merge(String main, String other, {String? base}) =>
      MergedText('$main$other');
}

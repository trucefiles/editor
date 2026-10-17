import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_drafts.dart';
import 'package:truce_editor/notes/note_staging.dart';

import '../support.dart';

void main() {
  late NoteDrafts drafts;
  late int due;
  final later = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    drafts = tempDrafts();
    due = 0;
  });

  NoteStaging staging(Duration delay) {
    final staging = NoteStaging(
      drafts,
      publishDelay: delay,
      onDue: () => due++,
    );
    addTearDown(staging.dispose);
    return staging;
  }

  Future<List<String>> texts() async => [
    for (final draft in await drafts.all(before: later)) draft.text,
  ];

  test('keeps the latest text as one draft', () async {
    final staged = staging(const Duration(hours: 1));

    await staged.keep(path('a.md'), base: 'b', text: 'one');
    await staged.keep(path('a.md'), base: 'b', text: 'two');

    expect(await texts(), ['two']);
  });

  test('is due once, a delay after the first keep', () async {
    // Longer than a draft write takes on a busy machine: a keep after
    // the delay is rightly due again.
    final staged = staging(const Duration(milliseconds: 500));

    await staged.keep(path('a.md'), base: 'b', text: 'one');
    await staged.keep(path('a.md'), base: 'b', text: 'two');
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(due, 1);
  });

  test('drop removes the draft and is not due', () async {
    final staged = staging(const Duration(milliseconds: 20));
    final keeping = staged.keep(path('a.md'), base: 'b', text: 'one');

    staged.drop();
    await keeping;
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(await texts(), isEmpty);
    expect(due, 0);
  });
}

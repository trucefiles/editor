import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../support/document_corpus.dart';
import 'editor_run.dart';

/// The summary the editor owner tells with its status: of the text as the
/// file owner has it, from the tree that printed it.
void main() {
  TextSummary<Object?> summaryOf(EditorRun run) => run.state.status.summary;

  test('is of the start text', () {
    expect(summaryOf(EditorRun('# Plan\ntext')).title, 'Plan');
  });

  test('follows a save, not the typing before it', () {
    final run = EditorRun('one')
      ..caret(0, 3)
      ..type(' two');
    expect(summaryOf(run).firstLine, 'one');

    run.pause();
    expect(summaryOf(run).firstLine, 'one two');
  });

  // Title and first line are all an open document asks of it.
  test('of a printed tree is what reading its text gives', () {
    for (final text in documentCorpus) {
      final run = EditorRun('x')
        ..request(ReplaceAll(text))
        ..pause();
      final read = DocumentSummary.of(run.sent);
      final summary = summaryOf(run);
      expect(summary.title, read.title, reason: text);
      expect(summary.firstLine, read.firstLine, reason: text);
    }
  });

  test('is of the raw block as typed when it is open at a save', () {
    final run = EditorRun('a\n\n<div>\nx\n</div>\n\nb');
    run.owner.send(
      OpenRawBlock(run.leaf(1), atEnd: false, revision: run.revision),
    );
    run.owner.send(EditRaw('# T', base: 3, extent: 3, revision: run.revision));
    run.pause();

    expect(run.shown.raw, isNotNull);
    expect(summaryOf(run).title, 'T');
  });

  test('in Markdown edit, is of the text sent', () {
    final run = EditorRun('one', mode: EditMode.markdown)
      ..send(const EditText('# Two\none', revision: 0));
    expect(summaryOf(run).title, isNull);

    run.pause();
    expect(summaryOf(run).title, 'Two');
  });

  test('follows a change elsewhere', () {
    final run = EditorRun('one')
      ..request(
        const FromFile(Replaced('# Theirs', version: Version(2), ackRev: 0)),
      );
    expect(summaryOf(run).title, 'Theirs');
  });

  test('in Markdown edit, follows a change elsewhere', () {
    final run = EditorRun('one', mode: EditMode.markdown)
      ..request(
        const FromFile(Replaced('# Theirs', version: Version(2), ackRev: 0)),
      );
    expect(summaryOf(run).title, 'Theirs');
  });
}

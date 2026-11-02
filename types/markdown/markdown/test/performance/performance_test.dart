import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/doc/doc_tree.dart';
import 'package:truce_markdown/src/doc/load.dart';
import 'package:truce_markdown/src/edit/clipboard_lines.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/print/printer.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/formatting.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

/// Budgets for a 2000-item list, on the JIT that tests run on: a few
/// times the compiled app's budgets (print 10 ms, keystroke 4 ms), so a
/// slow machine passes and an accidental rescan fails.
const _printBudget = Duration(milliseconds: 40);
const _keystrokeBudget = Duration(milliseconds: 16);

void main() {
  for (final loose in [false, true]) {
    group('with 2000 ${loose ? 'loose' : 'tight'} items', () {
      final loaded = loadMarkdown(
        [
          for (var item = 0; item < 2000; item++)
            '- [${item.isEven ? ' ' : 'x'}] item number $item with some words',
        ].join(loose ? '\n\n' : '\n'),
      );
      final middle = nodesIn(loaded.doc.root)
          .whereType<ParagraphNode>()
          .elementAt(1000)
          .id;

      DocTree typed(DocTree doc) {
        final paragraph = doc.nodeOf(middle) as ParagraphNode;
        return doc.withNode(
          paragraph.withText(
            paragraph.text.replaced(3, 3, VisibleText([TextPiece('x')])),
          ),
        );
      }

      test('a save prints within budget', () {
        var doc = loaded.doc;
        final times = [
          for (var round = 0; round < 21; round++)
            _timed(() {
              doc = typed(doc);
              printMarkdown(doc, loaded.origin);
            }),
        ];
        expect(_median(times), lessThan(_printBudget));
      });

      test('a typed character runs within budget', () {
        var view = ViewRows(loaded.doc);
        final times = [
          for (var round = 0; round < 21; round++)
            _timed(() {
              final edited = run(
                view,
                InsertText(Place(middle, 3), 'x', Formatting.plain),
              );
              view = ViewRows(edited.doc);
              view.rowOf(middle);
            }),
        ];
        expect(_median(times), lessThan(_keystrokeBudget));
      });

      test('Move to end and a 600-line paste run within budget', () {
        final view = ViewRows(loaded.doc);
        final caret = TextSelection.caret(Place(middle, 3));
        final lines = plainLines(
          [for (var line = 0; line < 600; line++) 'pasted line $line']
              .join('\n'),
          Formatting.plain,
        );
        for (final command in [MoveToEnd(caret), Paste(caret, lines)]) {
          final times = [
            for (var round = 0; round < 5; round++)
              _timed(() => ViewRows(run(view, command).doc).rows),
          ];
          expect(_median(times), lessThan(_printBudget), reason: '$command');
        }
      });

      test('a keystroke derives the rows within budget', () {
        var doc = loaded.doc;
        ViewRows(doc);
        final times = [
          for (var round = 0; round < 21; round++)
            _timed(() {
              doc = typed(doc);
              ViewRows(doc).rowOf(middle);
            }),
        ];
        expect(_median(times), lessThan(_keystrokeBudget));
      });
    });
  }
}

Duration _timed(void Function() run) {
  final watch = Stopwatch()..start();
  run();
  return watch.elapsed;
}

Duration _median(List<Duration> times) =>
    (List.of(times)..sort())[times.length ~/ 2];

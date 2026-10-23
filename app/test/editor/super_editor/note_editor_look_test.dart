import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/editor/note_mode.dart';

import '../editor_support.dart';
import 'editor_robot.dart';

/// How a note looks in the editor: theme colors, marks on the edited line,
/// quotes, compact lists and gaps.
void main() {
  bool shows(String text) =>
      find.text(text, findRichText: true).evaluate().isNotEmpty;

  group('marks of the edited block', () {
    const note = '**bold** one\n\nplain *it*';

    testWidgets('show in the block tapped, hidden in the others', (
      tester,
    ) async {
      await pumpNoteEditor(tester, FakeNoteText(note));

      await tester.caretIn(paragraphNodeOf(index: 2), 2);
      expect(shows('plain *it*'), isTrue);
      expect(shows('bold one'), isTrue);

      await tester.caretIn(paragraphNodeOf(), 2);
      expect(shows('**bold** one'), isTrue);
      expect(shows('plain it'), isTrue);
    });

    testWidgets('show on every line of the block, one row each', (
      tester,
    ) async {
      await pumpNoteEditor(tester, FakeNoteText('**a** one\n*b* two\n\nc'));

      await tester.caretIn(paragraphNodeOf(), 2);

      expect(shows('**a** one\n*b* two'), isTrue);
    });

    testWidgets('follow the caret moved by arrow keys', (tester) async {
      await pumpNoteEditor(tester, FakeNoteText(note));
      await tester.caretIn(paragraphNodeOf(), 2);

      await tester.pressDownArrow();
      await tester.pressDownArrow();
      await tester.pumpAndSettle();

      expect(shows('plain *it*'), isTrue);
      expect(shows('bold one'), isTrue);
    });

    testWidgets('still follow the caret after the theme changes', (
      tester,
    ) async {
      final text = FakeNoteText(note);
      final document = await pumpNoteEditor(tester, text);
      // A new look rebuilds the editor's layout, phases and all.
      await showNoteEditor(tester, document, theme: ThemeData.dark());
      await tester.pumpAndSettle();

      await tester.caretIn(paragraphNodeOf(index: 2), 2);

      expect(shows('plain *it*'), isTrue);
    });

    group('stay on the block edited last while the caret is on a blank', () {
      Future<void> pressShiftEnter(WidgetTester tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pressEnter();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
      }

      testWidgets('line, made by a line break at its end', (tester) async {
        final text = FakeNoteText('**a** one');
        await pumpNoteEditor(tester, text);
        await tester.caretIn(paragraphNodeOf(), 9);

        await pressShiftEnter(tester);

        expect(text.text, '**a** one\n');
        expect(shows('**a** one'), isTrue);
      });

      testWidgets('line, made by Enter at its end', (tester) async {
        final text = FakeNoteText('**a** one');
        await pumpNoteEditor(tester, text);
        await tester.caretIn(paragraphNodeOf(), 9);

        await tester.pressEnter();
        await tester.pumpAndSettle();

        expect(text.text, '**a** one\n');
        expect(shows('**a** one'), isTrue);
      });

      testWidgets('line, then typing on it, still in the block', (
        tester,
      ) async {
        final text = FakeNoteText('**a** one');
        await pumpNoteEditor(tester, text);
        await tester.caretIn(paragraphNodeOf(), 9);

        await pressShiftEnter(tester);
        await tester.typeImeText('x');

        expect(text.text, '**a** one\nx');
        expect(shows('**a** one\nx'), isTrue);
      });

      testWidgets('line, tapped', (tester) async {
        await pumpNoteEditor(tester, FakeNoteText(note));
        await tester.caretIn(paragraphNodeOf(), 2);

        await tester.caretIn(paragraphNodeOf(index: 1), 0);

        expect(shows('**bold** one'), isTrue);
        expect(shows('plain it'), isTrue);
      });

      testWidgets('until the caret goes into another block', (tester) async {
        await pumpNoteEditor(tester, FakeNoteText(note));
        await tester.caretIn(paragraphNodeOf(), 2);
        await tester.caretIn(paragraphNodeOf(index: 1), 0);

        await tester.caretIn(paragraphNodeOf(index: 2), 2);

        expect(shows('bold one'), isTrue);
        expect(shows('plain *it*'), isTrue);
      });

      testWidgets('line, reached by the arrow keys', (tester) async {
        await pumpNoteEditor(tester, FakeNoteText(note));
        await tester.caretIn(paragraphNodeOf(), 2);

        await tester.pressDownArrow();
        await tester.pumpAndSettle();

        expect(shows('**bold** one'), isTrue);
      });

      testWidgets('line, one of several', (tester) async {
        await pumpNoteEditor(tester, FakeNoteText('**a** x\n\n\n\nc'));
        await tester.caretIn(paragraphNodeOf(), 2);

        await tester.caretIn(paragraphNodeOf(index: 2), 0);

        expect(shows('**a** x'), isTrue);
      });

      testWidgets('line in a quote', (tester) async {
        await pumpNoteEditor(tester, FakeNoteText('> **a** x\n>\n> *b*'));
        await tester.caretIn(paragraphNodeOf(), 2);

        await tester.caretIn(paragraphNodeOf(index: 1), 0);

        expect(shows('**a** x'), isTrue);
        expect(shows('b'), isTrue);
      });

      testWidgets('line, but none before it was edited', (tester) async {
        await pumpNoteEditor(tester, FakeNoteText(note));

        await tester.caretIn(paragraphNodeOf(index: 1), 0);

        expect(shows('bold one'), isTrue);
        expect(shows('plain it'), isTrue);
      });

      testWidgets('line, with the selection going on into a block', (
        tester,
      ) async {
        await pumpNoteEditor(tester, FakeNoteText(note));
        await tester.caretIn(paragraphNodeOf(), 2);
        await tester.caretIn(paragraphNodeOf(index: 1), 0);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pressDownArrow();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        expect(shows('bold one'), isTrue);
        expect(shows('plain *it*'), isTrue);
      });

      testWidgets('line, but not a block changed on another device', (
        tester,
      ) async {
        final text = FakeNoteText(note);
        await pumpNoteEditor(tester, text);
        await tester.caretIn(paragraphNodeOf(), 2);
        await tester.caretIn(paragraphNodeOf(index: 1), 0);

        text.changeElsewhere('**bold** two\n\nplain *it*');
        await tester.pumpAndSettle();

        expect(shows('bold two'), isTrue);
        expect(shows('plain it'), isTrue);
      });

      testWidgets('line, after Enter on an empty item left the list', (
        tester,
      ) async {
        final text = FakeNoteText('- [ ] **a** x');
        await pumpNoteEditor(tester, text);
        await tester.caretIn(checkboxNodeOf(), 7);

        await tester.pressEnter();
        await tester.pressEnter();
        await tester.pumpAndSettle();

        expect(text.text, '- [ ] **a** x\n\n');
        expect(shows('a x'), isTrue);
      });

      testWidgets('but a new empty item is a block of its own', (tester) async {
        final text = FakeNoteText('- [ ] **a** x');
        await pumpNoteEditor(tester, text);
        await tester.caretIn(checkboxNodeOf(), 7);

        await tester.pressEnter();
        await tester.pumpAndSettle();

        expect(text.text, '- [ ] **a** x\n- [ ] ');
        expect(shows('a x'), isTrue);
      });
    });

    testWidgets('show in an item being edited', (tester) async {
      await pumpNoteEditor(tester, FakeNoteText('- [ ] **a** x\n- [ ] b'));

      await tester.caretIn(checkboxNodeOf(), 2);

      expect(shows('**a** x'), isTrue);
    });
  });

  testWidgets('the caret takes the theme color', (tester) async {
    final document = await pumpNoteEditor(tester, FakeNoteText('a'));

    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      await showNoteEditor(tester, document, theme: theme);
      await tester.pumpAndSettle();
      final editor = tester.widget<SuperEditor>(find.byType(SuperEditor));
      final caret = editor.documentOverlayBuilders
          .whereType<DefaultCaretOverlayBuilder>()
          .single;
      expect(caret.caretStyle.color, theme.colorScheme.primary);
    }
  });

  testWidgets(
    'the touch handles take the theme color',
    (tester) async {
      final document = await pumpNoteEditor(tester, FakeNoteText('a'));

      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await showNoteEditor(tester, document, theme: theme);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(SuperEditor));
        final color = switch (defaultTargetPlatform) {
          TargetPlatform.iOS => SuperEditorIosControlsScope.rootOf(
            context,
          ).handleColor,
          _ => SuperEditorAndroidControlsScope.rootOf(context).controlsColor,
        };
        expect(color, theme.colorScheme.primary);
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  Finder quoteBars() => find.byWidgetPredicate(
    (widget) => widget is Positioned && widget.width == 3,
  );

  testWidgets('a quote has a bar in Visual edit, not in Markdown', (
    tester,
  ) async {
    const note = '> quoted\n\n**bold**';
    for (final (mode, bars) in [(NoteMode.visual, 1), (NoteMode.markdown, 0)]) {
      // A view shows one mode for its life.
      await tester.pumpWidget(const SizedBox());
      await pumpNoteEditor(tester, FakeNoteText(note), mode: mode);
      await tester.pumpAndSettle();
      expect(quoteBars(), findsNWidgets(bars), reason: '$mode');
    }
  });

  testWidgets('a quote line without marks shows inside the quote', (
    tester,
  ) async {
    await pumpNoteEditor(tester, FakeNoteText('> quoted\nmore\n\nafter'));
    await tester.pumpAndSettle();

    expect(quoteBars(), findsOneWidget);
    expect(shows('quoted\nmore'), isTrue);
  });

  testWidgets('quotes and items nest as the file says', (tester) async {
    await pumpNoteEditor(tester, FakeNoteText('> - [ ] a\n>   > b'));
    await tester.pumpAndSettle();

    expect(quoteBars(), findsNWidgets(3));
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('numbered items count on from the first number', (tester) async {
    for (final mode in [NoteMode.visual, NoteMode.read]) {
      await tester.pumpWidget(const SizedBox());
      await pumpNoteEditor(tester, FakeNoteText('3. a\n1. b'), mode: mode);
      await tester.pumpAndSettle();
      expect(find.text('3.'), findsOneWidget, reason: '$mode');
      expect(find.text('4.'), findsOneWidget, reason: '$mode');
    }
  });

  testWidgets('a tap in a quote places the caret there', (tester) async {
    await pumpNoteEditor(tester, FakeNoteText('# T\n> said\nplain'));

    await tester.caretIn(paragraphNodeOf(index: 1), 4);

    expect(
      SuperEditorInspector.findDocumentSelection()?.extent.nodeId,
      paragraphNodeOf(index: 1),
    );
  });

  /// The distance between the tops of the first two list rows, shown
  /// with [tapTargets] as the theme's tap target size.
  Future<double> rowPitch(
    WidgetTester tester,
    MaterialTapTargetSize tapTargets,
  ) async {
    final note = documentOf(FakeNoteText('- [ ] a\n- b\n1. c\nd'));
    addTearDown(note.dispose);
    await showNoteEditor(
      tester,
      note,
      theme: ThemeData(materialTapTargetSize: tapTargets),
    );
    await tester.pumpAndSettle();
    final text = tester.getSize(find.byType(TextComponent).last).height;
    for (final row in find.byType(TextComponent).evaluate().take(3)) {
      final height = tester.getSize(find.byWidget(row.widget)).height;
      expect(height, lessThanOrEqualTo(text + 1));
    }
    return tester.getTopLeft(find.byType(TextComponent).at(1)).dy -
        tester.getTopLeft(find.byType(TextComponent).at(0)).dy;
  }

  testWidgets('list rows are about a text line high', (tester) async {
    expect(
      await rowPitch(tester, MaterialTapTargetSize.shrinkWrap),
      lessThan(40),
      reason: 'rows close together',
    );
  });

  testWidgets('on touch, list rows are a touch target apart', (tester) async {
    expect(
      await rowPitch(tester, MaterialTapTargetSize.padded),
      greaterThanOrEqualTo(kMinInteractiveDimension),
    );
  });

  testWidgets("on touch, an item's menu is a touch target, as its handle", (
    tester,
  ) async {
    await pumpNoteEditor(
      tester,
      FakeNoteText('- [ ] a\n- [ ] b'),
      theme: ThemeData(materialTapTargetSize: MaterialTapTargetSize.padded),
    );
    await tester.caretIn(checkboxNodeOf(), 0);

    final menu = tester.getSize(find.byTooltip('Item actions').first);
    final handle = tester.getSize(
      find
          .ancestor(
            of: find.byIcon(Icons.drag_indicator).first,
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(menu.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(menu.height, handle.height);
  });

  testWidgets('markers sit in the middle of their line of text', (
    tester,
  ) async {
    await pumpNoteEditor(tester, FakeNoteText('- [ ] a\n- b\n\n1. c'));
    await tester.pumpAndSettle();

    for (final (marker, text) in [
      (find.byType(Checkbox), 'a'),
      (find.text('•'), 'b'),
      (find.text('1.'), 'c'),
    ]) {
      expect(
        tester.getCenter(marker).dy,
        moreOrLessEquals(
          tester.getCenter(find.text(text, findRichText: true)).dy,
          epsilon: 1,
        ),
        reason: text,
      );
    }
  });

  testWidgets('markers end the same gap before their text', (tester) async {
    await pumpNoteEditor(tester, FakeNoteText('- [ ] a\n- b\n\n9. c\n10. d'));
    await tester.pumpAndSettle();

    // The box is drawn in the middle of the checkbox's tap area.
    final checkbox = find.byType(Checkbox);
    final boxEnd =
        tester.getTopRight(checkbox).dx -
        (tester.getSize(checkbox).width - Checkbox.width) / 2;
    final ends = [
      boxEnd,
      for (final marker in [find.text('•'), find.text('9.'), find.text('10.')])
        tester.getTopRight(marker).dx,
    ];
    for (final end in ends) {
      expect(end, moreOrLessEquals(ends.first, epsilon: 1));
    }
    final text = tester.getTopLeft(find.text('a', findRichText: true)).dx;
    expect(text - ends.first, moreOrLessEquals(12, epsilon: 1));
  });

  testWidgets('the format bar keeps clear of the bottom system edge', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPadding);
    await pumpNoteEditor(tester, FakeNoteText('a'));
    await tester.pumpAndSettle();

    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final inset = 48 / tester.view.devicePixelRatio;
    expect(
      tester.getBottomLeft(find.byTooltip('Bold (Ctrl+B)')).dy,
      lessThanOrEqualTo(screen - inset),
    );
  });

  testWidgets('Read has no drag handles or menus', (tester) async {
    await pumpNoteEditor(
      tester,
      FakeNoteText('- [ ] a\n- b'),
      mode: NoteMode.read,
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byTooltip('Item actions'), findsNothing);
  });
}

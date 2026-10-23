import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/note_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';
import 'package:truce_editor/versions/ui/diff_colors.dart';
import 'package:truce_editor/versions/ui/version_pane.dart';

void main() {
  testWidgets("shows the version's text at the note text zoom, the rest at "
      "the app's", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTextZoomScope(
          zoom: TextZoom.closestTo(150),
          child: TextZoomScale(
            zoom: TextZoom.closestTo(120),
            child: Scaffold(
              body: VersionPane(
                label: 'Mine',
                modified: null,
                text: 'note text',
                compareTo: 'other',
                keepLabel: 'Keep',
                onKeep: () {},
              ),
            ),
          ),
        ),
      ),
    );
    double scaled(Finder text) =>
        MediaQuery.textScalerOf(tester.element(text)).scale(10);

    expect(scaled(find.textContaining('note text', findRichText: true)), 15);
    expect(scaled(find.text('Mine')), 12);
  });

  testWidgets('shows lines only this version has as added and lines only '
      'the other has as removed, where they were', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VersionPane(
            label: 'Mine',
            modified: null,
            text: 'a\nmine\nc',
            compareTo: 'a\ntheirs\nc',
            keepLabel: 'Keep',
            onKeep: null,
          ),
        ),
      ),
    );
    final colors = DiffColors.of(Brightness.light);
    Color? tintOf(String line) => tester
        .widget<ColoredBox>(
          find
              .ancestor(of: find.text(line), matching: find.byType(ColoredBox))
              .first,
        )
        .color;

    expect(
      [
        for (final line in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(SelectionArea),
            matching: find.byType(Text),
          ),
        ))
          (line.data, tintOf(line.data!)),
      ],
      [
        ('a', Colors.transparent),
        ('theirs', colors.removed),
        ('mine', colors.added),
        ('c', Colors.transparent),
      ],
    );
  });

  testWidgets('copies exactly this version\'s text, line by line', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VersionPane(
            label: 'Mine',
            modified: null,
            text: 'a\n\nmine\nc',
            compareTo: 'a\n\ntheirs\nc',
            keepLabel: 'Keep',
            onKeep: null,
          ),
        ),
      ),
    );
    await tester.tap(find.text('a'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(copied, 'a\n\nmine\nc');
  });
}

import 'package:flutter/material.dart';
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
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    final lines = text.textSpan!.children!.cast<TextSpan>();
    final colors = DiffColors.of(Brightness.light);

    expect(
      [for (final line in lines) (line.text, line.style?.backgroundColor)],
      [
        ('a\n', null),
        ('theirs\n', colors.removed),
        ('mine\n', colors.added),
        ('c', null),
      ],
    );
  });
}

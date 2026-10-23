import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/note_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';
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
}

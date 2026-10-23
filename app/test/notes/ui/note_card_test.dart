import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_summary.dart';
import 'package:truce_editor/notes/ui/note_card.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/note_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';

import '../../support.dart';

void main() {
  Note note(String text) => noteOf(
    folderAt(Directory.systemTemp),
    text,
    name: 'note.md',
    version: 1,
    modified: DateTime(2026, 10, 14),
  );

  Future<double> heightWith(WidgetTester tester, int lines) async {
    final text = ['# Title', for (var i = 1; i <= lines; i++) 'line $i'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 240,
              child: NoteCard(
                note(text.join('\n')),
                onTap: () {},
                onMark: () {},
              ),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(NoteCard)).height;
  }

  testWidgets('grows with the note up to the preview limit', (tester) async {
    final short = await heightWith(tester, 1);
    final full = await heightWith(tester, NoteSummary.previewLines);
    final long = await heightWith(tester, NoteSummary.previewLines * 4);

    expect(short, lessThan(full));
    expect(long, full);
  });

  testWidgets('shows only the title for a note without text', (tester) async {
    expect(await heightWith(tester, 0), lessThan(await heightWith(tester, 1)));
  });

  testWidgets('labels a note with a sync conflict', (tester) async {
    Future<void> show({required bool hasConflict}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            note('# Title'),
            hasConflict: hasConflict,
            onTap: () {},
            onMark: () {},
          ),
        ),
      ),
    );

    await show(hasConflict: false);
    expect(find.text('Conflict'), findsNothing);

    await show(hasConflict: true);
    expect(find.text('Conflict'), findsOne);
  });

  testWidgets("shows the note at the note text zoom, the rest at the app's", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTextZoomScope(
          zoom: TextZoom.closestTo(150),
          child: TextZoomScale(
            zoom: TextZoom.closestTo(120),
            child: Scaffold(
              body: NoteCard(
                note('# Title\nline'),
                onTap: () {},
                onMark: () {},
              ),
            ),
          ),
        ),
      ),
    );
    double scaled(Finder text) =>
        MediaQuery.textScalerOf(tester.element(text)).scale(10);

    expect(scaled(find.text('Title')), 15);
    expect(scaled(find.text('line')), 15);
    expect(scaled(find.textContaining('Oct 14')), 12);
  });
}

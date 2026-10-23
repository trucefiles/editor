import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/conflicts/ui/orphan_card.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/note_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';

import '../../support.dart';

void main() {
  testWidgets('shows its note at the note text zoom, like note cards', (
    tester,
  ) async {
    final conflict = FolderConflict(
      folderAt(Directory.systemTemp),
      Conflict(mainPath: path('todo.md'), main: null, copies: const []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTextZoomScope(
          zoom: TextZoom.closestTo(150),
          child: TextZoomScale(
            zoom: TextZoom.closestTo(120),
            child: Scaffold(body: OrphanCard(conflict, onTap: () {})),
          ),
        ),
      ),
    );

    expect(
      MediaQuery.textScalerOf(tester.element(find.text('todo.md'))).scale(10),
      15,
    );
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_editor/conflicts/ui/orphan_card.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/document_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';

import '../../support.dart';

void main() {
  testWidgets(
    'shows its document at the document text zoom, like document cards',
    (tester) async {
      final conflict = FolderConflict(
        folderAt(Directory.systemTemp),
        Conflict(mainPath: path('todo.md'), main: null, copies: const []),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTextZoomScope(
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
    },
  );
}

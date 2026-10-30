import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/document_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';
import 'package:truce_editor/versions/ui/diff_colors.dart';
import 'package:truce_editor/versions/ui/version_content.dart';
import 'package:truce_editor/versions/ui/version_pane.dart';

void main() {
  testWidgets("shows the version's text at the document text zoom, the rest at "
      "the app's", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentTextZoomScope(
          zoom: TextZoom.closestTo(150),
          child: TextZoomScale(
            zoom: TextZoom.closestTo(120),
            child: Scaffold(
              body: VersionPane(
                label: 'Mine',
                content: const EditorText('document text'),
                compareTo: 'other',
                ownLines: OwnLines.added,
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

    expect(
      scaled(find.textContaining('document text', findRichText: true)),
      15,
    );
    expect(scaled(find.text('Mine')), 12);
  });

  for (final (ownLines, tint) in [
    (OwnLines.added, DiffColors.of(Brightness.light).added),
    (OwnLines.removed, DiffColors.of(Brightness.light).removed),
  ]) {
    testWidgets('shows only its own lines, the ones the other version lacks '
        'as ${ownLines.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VersionPane(
              label: 'Mine',
              content: const EditorText('a\nmine\nc'),
              compareTo: 'a\ntheirs\nc',
              ownLines: ownLines,
              keepLabel: 'Keep',
              onKeep: null,
            ),
          ),
        ),
      );
      Color? tintOf(String line) => tester
          .widget<ColoredBox>(
            find
                .ancestor(
                  of: find.text(line),
                  matching: find.byType(ColoredBox),
                )
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
        [('a', Colors.transparent), ('mine', tint), ('c', Colors.transparent)],
      );
    });
  }

  testWidgets('every kind of version has a second header line, so both '
      'texts start at one height', (tester) async {
    Future<double> textTop(VersionContent content) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VersionPane(
              label: 'Mine',
              content: content,
              compareTo: '',
              ownLines: OwnLines.added,
              keepLabel: 'Keep',
              onKeep: null,
            ),
          ),
        ),
      );
      return tester.getTopLeft(find.byType(Expanded)).dy;
    }

    final saved = await textTop(SavedText('text', DateTime(2026, 1, 2, 3, 4)));
    expect(find.text('Deleted'), findsNothing);
    expect(await textTop(const EditorText('text')), saved);
    expect(find.text('In the editor now'), findsOneWidget);
    expect(await textTop(const DeletedFile()), saved);
    expect(find.text('Deleted'), findsOneWidget);
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
            content: EditorText('a\n\nmine\nc'),
            compareTo: 'a\n\ntheirs\nc',
            ownLines: OwnLines.added,
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

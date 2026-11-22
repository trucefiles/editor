import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/time_texts.dart';
import 'package:truce_editor/file_page/ui/file_info_panel.dart';
import 'package:truce_editor/platform/link_opener.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../../support.dart';

/// Notes every link asked, opening none.
final class _Links implements LinkOpener {
  final asked = <Uri>[];

  @override
  Future<bool> open(Uri link) async {
    asked.add(link);
    return false;
  }
}

void main() {
  late _Links links;

  Future<void> show(
    WidgetTester tester, {
    required FutureOr<List<FileFact>> facts,
    bool saved = true,
  }) async {
    links = _Links();
    final folder = folderAt(tempFolder());
    final file = listedFile(
      folder,
      name: 'notes/shopping.md',
      modified: DateTime(2026, 11, 22, 13, 5),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          linkOpenerProvider.overrideWithValue(links),
          timeTextsProvider.overrideWithValue(
            TimeTexts(locale: 'en_US', use24Hour: true),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FileInfoPanel((
              folder: folder,
              path: file.path,
              type: const MarkdownFileType(),
              saved: saved ? file : null,
            ), facts: facts),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('tells what every file has, then what its type tells', (
    tester,
  ) async {
    await show(tester, facts: const [TextFact('Words', '12')]);

    expect(find.text('shopping.md'), findsOne);
    expect(find.text('Markdown'), findsOne);
    expect(find.text('0 bytes'), findsOne);
    expect(find.text('Sunday, November 22, 2026, 13:05'), findsOne);
    expect(find.text('Words'), findsOne);
    expect(find.text('12'), findsOne);
  });

  testWidgets('a new file without a file yet tells no size or time', (
    tester,
  ) async {
    await show(tester, facts: const [], saved: false);

    expect(find.text('shopping.md'), findsOne);
    expect(find.text('Size'), findsNothing);
    expect(find.text('Last changed'), findsNothing);
  });

  testWidgets('facts that are read show once they are there', (tester) async {
    final read = Completer<List<FileFact>>();
    await show(tester, facts: read.future);
    expect(find.text('Camera'), findsNothing);

    read.complete(const [TextFact('Camera', 'Pixel 7')]);
    await tester.pumpAndSettle();

    expect(find.text('Pixel 7'), findsOne);
  });

  testWidgets('a time shows with its date; a point shows its coordinates '
      'and opens on a map when tapped', (tester) async {
    await show(
      tester,
      facts: [
        TimeFact('Taken', DateTime(2026, 7, 1, 9, 30)),
        const MapPointFact('Location', latitude: 48.1417, longitude: -11.5),
      ],
    );
    expect(find.text('Wednesday, July 1, 2026, 09:30'), findsOne);

    await tester.tap(find.text('48.14170, -11.50000'));
    await tester.pump();

    expect(links.asked.first, Uri.parse('geo:48.1417,-11.5'));
  });
}

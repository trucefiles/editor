import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document_card_summary.dart';
import 'package:truce_editor/documents/document_settings.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems;

import '../support.dart';

void main() {
  const shown = DocumentSettings(checkedItems: CheckedItems.inPlace);
  const hidden = DocumentSettings();

  DocumentCardSummary summaryOf(String text, String name) =>
      appDocumentTypes().of(path(name))!.cardSummary(text, path(name));

  group('Markdown', () {
    test('holds the title and the preview as the settings say', () {
      final summary = summaryOf('# Shopping\n- [x] milk\n- [ ] eggs', 'a.md');

      expect(summary.title, 'Shopping');
      expect(summary.preview(shown), '☑ milk\n☐ eggs');
      expect(summary.preview(hidden), '☐ eggs\n+ 1 done');
    });

    test('works out its previews once, holding no text', () {
      final summary = summaryOf('# A\n- [x] milk', 'a.md');

      expect(
        identical(summary.preview(hidden), summary.preview(hidden)),
        isTrue,
      );
    });

    test('takes the title from the file name without a heading', () {
      expect(summaryOf('text', 'lists/Plan.md').title, 'Plan');
    });
  });

  group('plain text', () {
    test('the first line is the title, the later lines the preview', () {
      final summary = summaryOf('Shopping\n\n- [x] milk\n  eggs  \n', 'a.txt');

      expect(summary.title, 'Shopping');
      expect(summary.preview(hidden), '- [x] milk\n  eggs');
      expect(summary.preview(shown), summary.preview(hidden));
    });

    test('takes the title from the file name without words', () {
      expect(summaryOf(' \n', 'lists/Plan.txt').title, 'Plan');
    });

    test('previews hold up to ten lines', () {
      final lines = [for (var line = 0; line < 12; line++) 'line $line'];

      expect(
        summaryOf(lines.join('\n'), 'a.txt').preview(hidden),
        lines.skip(1).take(10).join('\n'),
      );
    });
  });
}

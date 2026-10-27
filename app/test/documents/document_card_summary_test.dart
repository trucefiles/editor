import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document_card_summary.dart';

import '../support.dart';

void main() {
  const text = '# Shopping\n- [x] milk\n- [ ] eggs';

  test('holds the title and both previews of the text', () {
    final summary = DocumentCardSummary.of(text, path('a.md'));

    expect(summary.title, 'Shopping');
    expect(summary.previewOf(hideDone: false), '☑ milk\n☐ eggs');
    expect(summary.previewOf(hideDone: true), '☐ eggs\n+ 1 done');
  });

  test('takes the title from the file name without a heading', () {
    expect(DocumentCardSummary.of('text', path('lists/Plan.md')).title, 'Plan');
  });

  test('previews hold up to the given lines', () {
    final summary = DocumentCardSummary.of(
      'a\nb\nc',
      path('a.md'),
      maxLines: 2,
    );

    expect(summary.preview, 'a\nb');
  });
}

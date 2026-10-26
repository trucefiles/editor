import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';

import 'html_renderer.dart';
import 'spec_examples.dart';

/// Examples the reader reads differently on purpose, by spec file and
/// example number, with the reason.
const _deviations = <String, Map<int, String>>{
  _commonMark: {
    96: _frontMatter,
    98: _frontMatter,
    608: _extendedAutolink,
    611: _extendedAutolink,
    612: _extendedAutolink,
  },
  _gfm: {},
};

const _extendedAutolink = 'GitHub links bare urls and email addresses';
const _frontMatter =
    'a document that starts with a `---` line closed by another '
    'starts with front matter';

const _commonMark = 'commonmark-0.31.2.txt';
const _gfm = 'gfm-0.29-extensions.txt';

void main() {
  for (final spec in [_commonMark, _gfm]) {
    group(spec, () {
      for (final example in specExamples(spec)) {
        final deviation = _deviations[spec]![example.number];
        test('${example.number} ${example.section}', () {
          final html = renderHtml(
            DocumentTree.read(_withoutFinalBreak(example.markdown)).root,
            filterTags: spec == _gfm,
          );
          if (deviation == null) {
            expect(html, example.html, reason: example.markdown);
          } else {
            expect(html, isNot(example.html), reason: 'deviation: $deviation');
          }
        });
      }
    });
  }
}

/// [markdown] without the line break that ends its last line.
String _withoutFinalBreak(String markdown) =>
    markdown.replaceFirst(RegExp(r'\n$'), '');

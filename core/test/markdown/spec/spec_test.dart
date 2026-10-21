import 'package:test/test.dart';
import 'package:truce_core/src/markdown/lines/line_id.dart';
import 'package:truce_core/src/markdown/lines/markdown_line.dart';
import 'package:truce_core/src/markdown/tree/block_reader.dart';

import 'html_renderer.dart';
import 'spec_examples.dart';

/// Examples the reader deliberately reads differently, by spec file and
/// example number, with the reason.
const _deviations = <String, Map<int, String>>{
  _commonMark: {
    285: _emptyItem,
    367: _emptyItem,
    608: _extendedAutolink,
    611: _extendedAutolink,
    612: _extendedAutolink,
  },
  _gfm: {},
};

const _emptyItem = 'an empty list item interrupts a paragraph';
const _extendedAutolink = 'GitHub links bare urls and email addresses';

const _commonMark = 'commonmark-0.31.2.txt';
const _gfm = 'gfm-0.29-extensions.txt';

void main() {
  for (final spec in [_commonMark, _gfm]) {
    group(spec, () {
      for (final example in specExamples(spec)) {
        final deviation = _deviations[spec]![example.number];
        test('${example.number} ${example.section}', () {
          final html = renderHtml(
            readBlocks(_lines(example.markdown)),
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

/// The lines of [markdown], whose last line break ends its last line.
List<MarkdownLine> _lines(String markdown) => [
  for (final (index, raw)
      in markdown.replaceFirst(RegExp(r'\n$'), '').split('\n').indexed)
    MarkdownLine(LineId(index), raw),
];
